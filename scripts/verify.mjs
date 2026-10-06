#!/usr/bin/env node
// Doğrulama zinciri: tsc → güvenlik kuralı testleri → flutter analyze/test.
// Çalıştır: node scripts/verify.mjs (veya npm run build:all)
// Komutlar kabuk üzerinden çalıştırılır ki Windows'ta tırnaklı argümanlar
// bölünmesin; ilk hatalı adımda durur.

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function run(label, command, cwd = root) {
  return new Promise((resolve) => {
    process.stdout.write(`\n▶ ${label}\n`);
    const child = spawn(command, {
      cwd,
      shell: true,
      stdio: "inherit",
      env: process.env,
    });
    child.on("error", (error) => {
      console.error(`✖ ${label}: ${error.message}`);
      resolve(1);
    });
    child.on("close", (code) => resolve(code ?? 1));
  });
}

function hasCommand(command) {
  const probe = process.platform === "win32" ? "where" : "which";
  return new Promise((resolve) => {
    const child = spawn(`${probe} ${command}`, { shell: true, stdio: "ignore" });
    child.on("close", (code) => resolve(code === 0));
    child.on("error", () => resolve(false));
  });
}

if (!(await hasCommand("node"))) {
  console.error("✖ Node.js bulunamadı. Node 20/22 kurun.");
  process.exit(1);
}

if (!existsSync(join(root, "node_modules"))) {
  console.error("✖ node_modules yok. Önce `npm install` çalıştırın.");
  process.exit(1);
}

const hasFlutter = await hasCommand("flutter");
if (!hasFlutter) {
  console.warn("⚠ Flutter bulunamadı — Dart tarafı doğrulamaları atlandı.");
}

const steps = [
  ["Cloud Functions tip denetimi", "npx tsc --noEmit", join(root, "functions")],
  [
    "Firestore güvenlik kuralları",
    'npx firebase emulators:exec --only firestore "npm run test:rules:run"',
    root,
  ],
  [
    "Storage güvenlik kuralları",
    'npx firebase emulators:exec --only storage "npm run test:storage:run"',
    root,
  ],
];

if (hasFlutter) {
  steps.push(
    ["Ortak paket analizi", "flutter analyze", join(root, "packages/school_comm")],
    ["Ortak paket testleri", "flutter test", join(root, "packages/school_comm")],
    ["Yönetici uygulaması analizi", "flutter analyze", join(root, "admin_app")],
    ["Öğrenci uygulaması analizi", "flutter analyze", join(root, "student_app")],
  );
}

let failed = 0;
for (const [label, command, cwd] of steps) {
  const code = await run(label, command, cwd);
  if (code !== 0) {
    console.error(`\n✖ BAŞARISIZ: ${label} (çıkış kodu ${code})`);
    failed = code;
    break;
  }
}

if (failed === 0) {
  console.log("\n✔ Tüm doğrulamalar geçti.");
} else {
  console.log("\n✖ Doğrulama başarısız. Yukarıdaki çıktıya bakın.");
}
process.exit(failed);
