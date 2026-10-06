import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  COLLECTIONS,
  ROLES,
  assertEmail,
  assertString,
  auth,
  clean,
  db,
  requireAdmin,
  type Role,
  type UserDoc,
} from "./lib/auth";
import { chunk } from "./lib/fcm";

// Rol + aktiflik değişimi. Claim ve doküman birlikte güncellenir.
export const setUserRole = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const data = request.data ?? {};
  const targetUid = assertString(data.uid, "uid", 128);
  const role = clean(data.role);
  const isActive = data.isActive;

  if (role !== ROLES.ADMIN && role !== ROLES.STUDENT) {
    throw new HttpsError("invalid-argument", "Geçersiz rol.");
  }
  if (typeof isActive !== "boolean") {
    throw new HttpsError("invalid-argument", "isActive alanı zorunludur.");
  }
  if (targetUid === adminUid && (role !== ROLES.ADMIN || isActive === false)) {
    throw new HttpsError("failed-precondition", "Kendi yönetici hesabınızı pasifleştiremezsiniz.");
  }

  const userRef = db().doc(`${COLLECTIONS.users}/${targetUid}`);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
  }

  await userRef.update({ role: role as Role, isActive });
  await auth().setCustomUserClaims(targetUid, {
    role,
    active: isActive,
    groupIds: snap.get("groupIds") ?? [],
  });
  return { ok: true, uid: targetUid, role, isActive };
});

// Admin'in tek çağrıda öğrenci hesabı açması.
export const createStudentAccount = onCall(async (request) => {
  await requireAdmin(request);
  const data = request.data ?? {};

  const email = assertEmail(data.email);
  const name = assertString(data.name, "name", 80);
  const surname = clean(data.surname).slice(0, 80);
  const password = assertString(data.password, "password", 128);
  if (password.length < 8) {
    throw new HttpsError("invalid-argument", "Şifre en az 8 karakter olmalıdır.");
  }

  let userRecord;
  try {
    userRecord = await auth().createUser({
      email,
      password,
      displayName: [name, surname].filter(Boolean).join(" "),
      emailVerified: false,
    });
  } catch (error) {
    if ((error as { code?: string }).code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Bu e-posta adresi zaten kayıtlı.");
    }
    throw new HttpsError("internal", "Hesap oluşturulamadı.");
  }

  await auth().setCustomUserClaims(userRecord.uid, {
    role: ROLES.STUDENT,
    active: true,
    groupIds: [],
  });

  const user: UserDoc = {
    name,
    surname,
    email,
    role: ROLES.STUDENT,
    profileImage: null,
    createdAt: Timestamp.now(),
    isActive: true,
    groupIds: [],
    unreadCount: 0,
  };
  await db().doc(`${COLLECTIONS.users}/${userRecord.uid}`).set(user);

  return { ok: true, uid: userRecord.uid, email };
});

// Silme sırası önemli: üyelikler, okundu kayıtları ve profil önce,
// Auth kaydı en son. Auth önce giderse bildirimler sessizce durur.
export const deleteUser = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const data = request.data ?? {};
  const targetUid = assertString(data.uid, "uid", 128);

  if (targetUid === adminUid) {
    throw new HttpsError("failed-precondition", "Kendi hesabınızı silemezsiniz.");
  }

  const userRef = db().doc(`${COLLECTIONS.users}/${targetUid}`);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
  }

  // 1) Grup üyelikleri + groupIds aynası.
  const groupIds = (snap.get("groupIds") as string[] | undefined) ?? [];
  for (const ids of chunk(groupIds, 400)) {
    const batch = db().batch();
    for (const groupId of ids) {
      batch.delete(db().doc(`${COLLECTIONS.groups}/${groupId}/members/${targetUid}`));
      batch.set(db().doc(`${COLLECTIONS.groups}/${groupId}`), { memberCount: FieldValue.increment(-1) }, { merge: true });
    }
    await batch.commit();
  }

  // 2) Okundu kayıtları + readCount sayaçları.
  const readSnaps = await db()
    .collectionGroup("reads")
    .where("userId", "==", targetUid)
    .get();
  for (const ids of chunk(readSnaps.docs, 400)) {
    const batch = db().batch();
    for (const readDoc of ids) {
      const announcementId = readDoc.ref.parent.parent?.id;
      batch.delete(readDoc.ref);
      if (announcementId) {
        batch.set(
          db().doc(`${COLLECTIONS.announcements}/${announcementId}`),
          { readCount: FieldValue.increment(-1) },
          { merge: true },
        );
      }
    }
    await batch.commit();
  }

  // 3) Kişisel alt-koleksiyonlar ve profil.
  await userRef.delete(); // recursive: devices, announcementReads, notifications gelir

  // 4) Auth kaydı.
  try {
    await auth().deleteUser(targetUid);
  } catch (error) {
    if ((error as { code?: string }).code !== "auth/user-not-found") {
      throw new HttpsError("internal", "Kimlik doğrulama kaydı silinemedi.");
    }
  }

  return { ok: true, uid: targetUid };
});

// Admin öğrencinin parolasını sıfırlar; Firebase kullanıcıya e-posta atar.
export const sendPasswordReset = onCall(async (request) => {
  await requireAdmin(request);
  const data = request.data ?? {};
  const targetUid = assertString(data.uid, "uid", 128);
  await auth().generatePasswordResetLink(targetUid);
  return { ok: true };
});
