import { defineString } from "firebase-functions/params";
import { beforeUserCreated, HttpsError } from "firebase-functions/v2/identity";
import { COLLECTIONS, db, ROLES, Timestamp, UserDoc, clean } from "./lib/auth";

// Tanımlıysa sadece bu domainden e-posta ile kayıt olur.
const ALLOWED_EMAIL_DOMAIN = defineString("ALLOWED_STUDENT_EMAIL_DOMAIN", {
  default: "",
});

// Geliştirme için: ilk kayıt olan admin olur. Üretimde false kalsın,
// admin'i scripts/set-first-admin.mjs ile atayın.
const BOOTSTRAP_FIRST_USER_AS_ADMIN = defineString("BOOTSTRAP_FIRST_USER_AS_ADMIN", {
  default: "false",
});

function splitName(displayName: string, email: string): { name: string; surname: string } {
  const parts = clean(displayName).split(/\s+/).filter(Boolean);
  if (parts.length >= 2) {
    return { name: parts[0], surname: parts.slice(1).join(" ") };
  }
  if (parts.length === 1) {
    return { name: parts[0], surname: "" };
  }
  const localPart = email.split("@")[0] ?? "";
  return { name: localPart.replace(/[._-]+/g, " "), surname: "" };
}

// Kayıttan hemen önce çalışır ve işlemi bloklar: users/{uid} dokümanı
// yazılır, role/groupIds/active claim'leri atanır. Böylece claim'siz hesap
// dönemi olmaz (rules istemciden users oluşturmayı zaten reddediyor).
export const beforeUserCreatedHandler = beforeUserCreated(async (event) => {
  const data = event.data;
  if (!data) {
    throw new HttpsError("internal", "Kullanıcı verisi okunamadı.");
  }

  const uid = data.uid;
  const email = (data.email ?? "").trim().toLowerCase();
  const domain = ALLOWED_EMAIL_DOMAIN.value().trim().toLowerCase();

  if (domain && !email.endsWith(`@${domain}`)) {
    throw new HttpsError(
      "invalid-argument",
      `Kayıt yalnızca @${domain} uzantılı kurum e-postası ile yapılabilir.`,
    );
  }

  const { name, surname } = splitName(data.displayName ?? "", email);

  const isFirstUser = (await db().collection(COLLECTIONS.users).where("role", "==", ROLES.ADMIN).limit(1).get()).empty;
  const role = isFirstUser && BOOTSTRAP_FIRST_USER_AS_ADMIN.value() === "true"
    ? ROLES.ADMIN
    : ROLES.STUDENT;

  const user: UserDoc = {
    name,
    surname,
    email,
    role,
    profileImage: data.photoURL ?? null,
    createdAt: Timestamp.now(),
    isActive: true,
    groupIds: [],
    unreadCount: 0,
  };

  await db()
    .doc(`${COLLECTIONS.users}/${uid}`)
    .set(user, { merge: true });

  return { customClaims: { role, groupIds: [], active: true } };
});
