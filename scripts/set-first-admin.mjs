#!/usr/bin/env node
// İlk (veya mevcut) yöneticiyi atar. Rol istemciden atanamadığı için bu
// betik Admin SDK kullanır; hem dokümanı hem claim'i günceller.
//
// Kullanım:
//   export GOOGLE_APPLICATION_CREDENTIALS=./service-account.json
//   node scripts/set-first-admin.mjs <PROJECT_ID> <EMAIL>

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const [projectId, email] = process.argv.slice(2);

if (!projectId || !email) {
  console.error("Kullanım: node scripts/set-first-admin.mjs <PROJECT_ID> <EMAIL>");
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId });

const auth = getAuth();
const db = getFirestore();

async function main() {
  const user = await auth.getUserByEmail(email);
  const role = "admin";

  await auth.setCustomUserClaims(user.uid, { role, groupIds: [] });

  const ref = db.doc(`users/${user.uid}`);
  const snap = await ref.get();
  await ref.set(
    {
      name: snap.get("name") ?? (user.displayName ?? email.split("@")[0]),
      surname: snap.get("surname") ?? "",
      email,
      role,
      isActive: true,
      groupIds: snap.get("groupIds") ?? [],
      unreadCount: snap.get("unreadCount") ?? 0,
      createdAt: snap.get("createdAt") ?? Timestamp.now(),
    },
    { merge: true },
  );

  console.log(`Yönetici atandı: ${email} (uid=${user.uid})`);
  console.log("Kullanıcının çıkış yapıp yeniden giriş yapması gerekir (claim token'a yazılır).");
}

main().catch((error) => {
  console.error("Hata:", error.message);
  process.exit(1);
});
