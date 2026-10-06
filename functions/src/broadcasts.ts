import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { COLLECTIONS, assertString, clean, db, requireAdmin } from "./lib/auth";
import { sendPushToUsers } from "./lib/fcm";

// Fan-out yok: her istemci broadcasts'u limit ile okur, kullanıcı başına
// 1 okuma. Push yine de cihaz bazında gider.
export const sendBroadcast = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const data = request.data ?? {};

  const title = assertString(data.title, "title", 120);
  const body = clean(data.content).slice(0, 1000);
  if (!body) {
    throw new HttpsError("invalid-argument", "İçerik zorunludur.");
  }

  const ref = db().collection(COLLECTIONS.broadcasts).doc();
  await ref.set({
    title,
    content: body,
    createdBy: adminUid,
    createdAt: Timestamp.now(),
    isActive: true,
    pushDispatched: false,
  });

  return { ok: true, broadcastId: ref.id };
});

// Push dağıtımı ayrı çağrıda: duyuru kaydı anında oluşur, push arkada döner.
export const dispatchBroadcastPush = onCall(async (request) => {
  await requireAdmin(request);
  const data = request.data ?? {};
  const broadcastId = assertString(data.broadcastId, "broadcastId", 128);

  const ref = db().doc(`${COLLECTIONS.broadcasts}/${broadcastId}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Duyuru bulunamadı.");
  if (snap.get("pushDispatched") === true) return { ok: true, skipped: true };

  const { title, content } = snap.data() ?? {};

  let total = 0;
  let success = 0;
  let page = db()
    .collection(COLLECTIONS.users)
    .where("role", "==", "student")
    .where("isActive", "==", true)
    .select();

  // 500'lik sayfalarla tüm aktif öğrenciler.
  while (true) {
    const batch = await page.limit(500).get();
    if (batch.empty) break;
    const ids = batch.docs.map((doc) => doc.id);
    const result = await sendPushToUsers(ids, {
      title: String(title ?? "Sistem duyurusu"),
      body: String(content ?? "").slice(0, 180),
      data: { type: "broadcast", broadcastId, route: "/notifications" },
    });
    total += ids.length;
    success += result.success;
    if (batch.size < 500) break;
    page = page.startAfter(batch.docs[batch.docs.length - 1]);
  }

  await ref.set({ pushDispatched: true, pushRecipients: total, pushSuccess: success }, { merge: true });
  logger.info("Sistem duyurusu dağıtıldı.", { broadcastId, total, success });
  return { ok: true, total, success };
});

// 90 günden eski cihaz kayıtlarını temizler. Kayıt tarafında arrayUnion
// kullanıldığı için çift kayıt zaten oluşmaz.
export const pruneInvalidDevices = onSchedule(
  { schedule: "every 24 hours", timeZone: "Europe/Istanbul" },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - 90 * 24 * 60 * 60 * 1000);
    const stale = await db()
      .collectionGroup("devices")
      .where("lastSeenAt", "<", cutoff)
      .limit(1000)
      .get();

    if (stale.empty) return;

    const orphanUserIds = new Set<string>();
    for (let i = 0; i < stale.docs.length; i += 400) {
      const batch = db().batch();
      for (const doc of stale.docs.slice(i, i + 400)) {
        batch.delete(doc.ref);
        const userId = doc.get("userId");
        if (typeof userId === "string") orphanUserIds.add(userId);
      }
      await batch.commit();
    }

    for (const userId of orphanUserIds) {
      await db()
        .doc(`${COLLECTIONS.users}/${userId}`)
        .set({ deviceCount: FieldValue.increment(-1) }, { merge: true });
    }

    logger.info("Eski cihaz kayıtları temizlendi.", { removed: stale.size });
  },
);
