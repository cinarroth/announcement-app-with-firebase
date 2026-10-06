import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import {
  COLLECTIONS,
  ROLES,
  assertString,
  auth,
  clean,
  db,
  requireAdmin,
  type GroupDoc,
} from "./lib/auth";
import { chunk } from "./lib/fcm";

// 500 op transaction limitine takılmamak için.
const TX_CHUNK = 100;
const WRITE_CHUNK = 400;

// memberCount ve isActive sunucuda sabitlenir.
export const createGroup = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const data = request.data ?? {};

  const name = assertString(data.name, "name", 120);
  const description = clean(data.description).slice(0, 1000);

  const group: GroupDoc = {
    name,
    description,
    createdAt: Timestamp.now(),
    createdBy: adminUid,
    isActive: true,
    memberCount: 0,
  };

  const ref = db().collection(COLLECTIONS.groups).doc();
  await ref.set(group);
  return { ok: true, groupId: ref.id };
});

// createdBy değiştirilemez.
export const updateGroup = onCall(async (request) => {
  await requireAdmin(request);
  const data = request.data ?? {};

  const groupId = assertString(data.groupId, "groupId", 128);
  const groupRef = db().doc(`${COLLECTIONS.groups}/${groupId}`);
  const snap = await groupRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Grup bulunamadı.");
  }

  const update: Record<string, unknown> = {};
  if (data.name !== undefined) update.name = assertString(data.name, "name", 120);
  if (data.description !== undefined) update.description = clean(data.description).slice(0, 1000);
  if (data.isActive !== undefined) {
    if (typeof data.isActive !== "boolean") {
      throw new HttpsError("invalid-argument", "isActive alanı zorunludur.");
    }
    update.isActive = data.isActive;
  }
  if (Object.keys(update).length === 0) {
    throw new HttpsError("invalid-argument", "Güncellenecek alan yok.");
  }

  await groupRef.update(update);
  return { ok: true, groupId };
});

// Üyelerin groupIds aynaları arrayRemove ile temizlenir (doküman okumaya
// gerek yok), sonra alt-koleksiyonlar. Storage dosyalarını istemci temizler.
export const deleteGroup = onCall(async (request) => {
  await requireAdmin(request);
  const data = request.data ?? {};

  const groupId = assertString(data.groupId, "groupId", 128);
  const groupRef = db().doc(`${COLLECTIONS.groups}/${groupId}`);
  const snap = await groupRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Grup bulunamadı.");
  }

  const groupIds = (snap.get("groupIds") as string[] | undefined) ?? [];

  for (let i = 0; i < groupIds.length; i += WRITE_CHUNK) {
    const batch = db().batch();
    for (const userId of groupIds.slice(i, i + WRITE_CHUNK)) {
      batch.set(
        db().doc(`${COLLECTIONS.users}/${userId}`),
        { groupIds: FieldValue.arrayRemove(groupId) },
        { merge: true },
      );
    }
    await batch.commit();
  }

  const [members, messages] = await Promise.all([
    db().collection(`${COLLECTIONS.groups}/${groupId}/members`).get(),
    db().collection(`${COLLECTIONS.groups}/${groupId}/messages`).limit(WRITE_CHUNK).get(),
  ]);

  const docs = [...members.docs, ...messages.docs];
  for (let i = 0; i < docs.length; i += WRITE_CHUNK) {
    const batch = db().batch();
    for (const doc of docs.slice(i, i + WRITE_CHUNK)) batch.delete(doc.ref);
    await batch.commit();
  }

  await groupRef.delete();
  await refreshMembershipClaims(groupIds);
  return { ok: true, groupId, removedMembers: members.size };
});

// Üyelik kaydı ile groupIds aynası aynı transaction'da yazılır; ikisi
// asla ayrışmaz. Ayna arrayUnion/arrayRemove ile güncellendiği için
// dokümanı baştan okumak gerekmez.
export const setGroupMembership = onCall(async (request) => {
  await requireAdmin(request);
  const data = request.data ?? {};

  const groupId = assertString(data.groupId, "groupId", 128);
  const addUserIds = toIdArray(data.addUserIds, "addUserIds");
  const removeUserIds = toIdArray(data.removeUserIds, "removeUserIds");

  if (addUserIds.length + removeUserIds.length > 400) {
    throw new HttpsError("invalid-argument", "Tek seferde en fazla 400 üyelik değişikliği yapılabilir.");
  }

  const groupRef = db().doc(`${COLLECTIONS.groups}/${groupId}`);
  if (!(await groupRef.get()).exists) {
    throw new HttpsError("not-found", "Grup bulunamadı.");
  }

  const userIds = Array.from(new Set([...addUserIds, ...removeUserIds]));
  const added: string[] = [];
  const removed: string[] = [];

  // Transaction kuralları: tüm okumalar tüm yazmalardan önce yapılır.
  for (let i = 0; i < userIds.length; i += TX_CHUNK) {
    const slice = userIds.slice(i, i + TX_CHUNK);
    const userRefs = slice.map((uid) => db().doc(`${COLLECTIONS.users}/${uid}`));
    const memberRefs = slice.map((uid) =>
      db().doc(`${COLLECTIONS.groups}/${groupId}/members/${uid}`),
    );

    await db().runTransaction(async (tx) => {
      const [userSnaps, memberSnaps] = await Promise.all([
        tx.getAll(...userRefs),
        tx.getAll(...memberRefs),
      ]);

      let delta = 0;

      userSnaps.forEach((userSnap, index) => {
        const uid = slice[index];
        const userRef = userRefs[index];
        const memberSnap = memberSnaps[index];

        if (!userSnap.exists) {
          throw new HttpsError("not-found", `Kullanıcı bulunamadı: ${uid}`);
        }

        if (addUserIds.includes(uid)) {
          if (!memberSnap.exists) {
            tx.set(memberSnap.ref, {
              memberId: uid,
              joinedAt: Timestamp.now(),
              displayName: `${userSnap.get("name") ?? ""} ${userSnap.get("surname") ?? ""}`.trim(),
            });
            delta += 1;
          }
          added.push(uid);
          tx.update(userRef, { groupIds: FieldValue.arrayUnion(groupId) });
        }

        if (removeUserIds.includes(uid)) {
          if (memberSnap.exists) {
            tx.delete(memberSnap.ref);
            delta -= 1;
          }
          removed.push(uid);
          tx.update(userRef, { groupIds: FieldValue.arrayRemove(groupId) });
        }
      });

      if (delta !== 0) {
        tx.update(groupRef, { memberCount: FieldValue.increment(delta) });
      }
    });
  }

  await refreshMembershipClaims([...added, ...removed]);
  return { ok: true, groupId, added, removed };
});

// Üyelik değişince claim'leri tazeler; storage.rules yetkiyi claim'den
// okuduğu için güncellenmezse eklenen öğrenci dosya indiremez, çıkarılan
// ise token tazelene kadar (≈1 saat) erişmeye devam eder. Claim yazımı
// patlarsa hata loglanır, veri zaten yazılmıştı — sonraki çağrıda denenir.
async function refreshMembershipClaims(userIds: string[]): Promise<void> {
  for (const ids of chunk(Array.from(new Set(userIds)), 100)) {
    const snaps = await db().getAll(...ids.map((uid) => db().doc(`${COLLECTIONS.users}/${uid}`)));
    await Promise.all(
      snaps
        .filter((snap) => snap.exists)
        .map(async (snap) => {
          try {
            await auth().setCustomUserClaims(snap.id, {
              role: snap.get("role") ?? ROLES.STUDENT,
              active: snap.get("isActive") === true,
              groupIds: snap.get("groupIds") ?? [],
            });
          } catch (error) {
            logger.error("Claim güncellenemedi", { uid: snap.id, error });
          }
        }),
    );
  }
}

function toIdArray(value: unknown, field: string): string[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${field} dizi olmalıdır.`);
  }
  return value.map((item) => assertString(item, field, 128));
}
