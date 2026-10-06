import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { COLLECTIONS, db } from "./lib/auth";
import { createNotificationRecords, sendPushToUsers } from "./lib/fcm";

// Duyuru oluşunca hedef grupların üyelerine push + notifications kaydı.
// Listener en az bir kez çalışabildiği için notificationDispatched alanı
// retry durumunda mükerrer gönderimi engelliyor.
export const onAnnouncementCreated = onDocumentCreated(
  "announcements/{announcementId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const announcementId = snapshot.id;
    const data = snapshot.data();
    if (!data) return;

    if (data.notificationDispatched === true) {
      logger.debug("Duyuru için bildirim zaten gönderilmiş.", { announcementId });
      return;
    }

    const targetGroupIds: string[] = Array.isArray(data.targetGroupIds) ? data.targetGroupIds : [];
    const publishedAt = data.publishedAt as Timestamp | undefined;
    const expiresAt = data.expiresAt as Timestamp | undefined | null;

    if (publishedAt && publishedAt.toMillis() > Date.now()) {
      // İleri tarihli: yayın zamanı gelmeden buraya düşerse bildirim yok.
      logger.debug("Duyuru henüz yayınlanmadı, bildirim ertelendi.", { announcementId });
      return;
    }
    if (expiresAt && expiresAt.toMillis() <= Date.now()) {
      logger.debug("Duyurunun süresi geçmiş, bildirim gönderilmedi.", { announcementId });
      return;
    }

    // Hedef grup yoksa tüm aktif öğrencilere gider.
    let recipientIds: string[];
    if (targetGroupIds.length === 0) {
      const snap = await db()
        .collection(COLLECTIONS.users)
        .where("role", "==", "student")
        .where("isActive", "==", true)
        .select()
        .get();
      recipientIds = snap.docs.map((doc) => doc.id);
    } else {
      recipientIds = await collectMembers(targetGroupIds);
    }

    if (recipientIds.length === 0) {
      await snapshot.ref.set({ notificationDispatched: true }, { merge: true });
      return;
    }

    const title = String(data.title ?? "Yeni duyuru");
    const body = String(data.content ?? "").slice(0, 180);

    const push = await sendPushToUsers(recipientIds, {
      title,
      body,
      data: { type: "announcement", announcementId, route: "/announcements/$announcementId" },
    });

    await createNotificationRecords(recipientIds, {
      title,
      body,
      type: "announcement",
      announcementId,
    });

    await snapshot.ref.set(
      {
        notificationDispatched: true,
        notifiedCount: recipientIds.length,
        pushSuccessCount: push.success,
      },
      { merge: true },
    );

    logger.info("Duyuru bildirimi gönderildi.", {
      announcementId,
      recipients: recipientIds.length,
      pushSuccess: push.success,
      invalidTokensRemoved: push.invalidTokensRemoved,
    });
  },
);

// Öğrenci duyuruyu açınca ayna kaydına yazar; trigger asıl reads dokümanını
// oluşturup readCount'u artırır. Sayaç böylece sadece sunucuda değişir.
export const onAnnouncementReadCreated = onDocumentCreated(
  "users/{userId}/announcementReads/{announcementId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const userId = event.params["userId"];
    const announcementId = event.params["announcementId"];
    const readAt = snapshot.get("readAt") as Timestamp | undefined;

    const readRef = db()
      .doc(`${COLLECTIONS.announcements}/${announcementId}/reads/${userId}`);
    const announcementRef = db().doc(`${COLLECTIONS.announcements}/${announcementId}`);

    await db().runTransaction(async (tx) => {
      const [readSnap, announcementSnap] = await Promise.all([
        tx.get(readRef),
        tx.get(announcementRef),
      ]);
      if (readSnap.exists || !announcementSnap.exists) return;
      tx.set(readRef, {
        userId,
        announcementId,
        readAt: readAt ?? Timestamp.now(),
      });
      tx.update(announcementRef, { readCount: FieldValue.increment(1) });
    });
  },
);

// Grup(lar)ın tüm üye id'leri.
export async function collectMembers(groupIds: string[]): Promise<string[]> {
  const members = new Set<string>();
  for (const groupId of groupIds) {
    const snap = await db().collection(`${COLLECTIONS.groups}/${groupId}/members`).get();
    snap.docs.forEach((doc) => members.add(doc.id));
  }
  return Array.from(members);
}
