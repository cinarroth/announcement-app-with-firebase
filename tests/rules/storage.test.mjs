// Storage kuralları testleri. Çalıştırma: npm run test:storage
//
// Kurallar yetkiyi token claim'lerinden okur: role, active, groupIds
// (storage.rules'a bakın).
//
// Bilinen sınır: emülatör, rules-unit-testing yüklemelerinde request.resource
// metadatasını doldurmaz; boyut/içerik-tipi kontrolleri burada test
// edilemez. O yüzden strateji: dosyalar kurallar atlanarak oluşturulur,
// okuma yetkileri (üyelik/claim denetimi, güvenliğin kritik kısmı) tamamen
// burada doğrulanır, yetkisiz yazma denemelerinin reddi test edilir.
// Boyut/tip kuralları gerçek projede ayrıca denenmeli.

import { assertFails, assertSucceeds, initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { ref, getBytes, uploadBytes, deleteObject } from "firebase/storage";
import { before, after, describe, it } from "mocha";

let testEnv;

const RULES = readFileSync("storage.rules", "utf8");

const ADMIN_ID = "admin-1";
const STUDENT_A = "student-a";
const STUDENT_B = "student-b";
const GROUP_1 = "group-1";
const GROUP_2 = "group-2";

const adminAuth = { uid: ADMIN_ID, token: { role: "admin", active: true, groupIds: [] } };
const memberAuth = { uid: STUDENT_A, token: { role: "student", active: true, groupIds: [GROUP_1] } };
const outsiderAuth = { uid: STUDENT_B, token: { role: "student", active: true, groupIds: [] } };
const inactiveAuth = { uid: STUDENT_B, token: { role: "student", active: false, groupIds: [GROUP_1] } };

function storage(auth) {
  if (!auth) return testEnv.unauthenticatedContext().storage();
  return testEnv.authenticatedContext(auth.uid, auth.token).storage();
}

const png = () => ({ contentType: "image/png", data: new Uint8Array([0x89, 0x50, 0x4e, 0x47]) });
const exe = () => ({ contentType: "application/x-msdownload", data: new Uint8Array([0x4d, 0x5a]) });
const pdf = (bytes = 64) => ({ contentType: "application/pdf", data: new Uint8Array(bytes) });

const PATHS = {
  avatar: `users/${STUDENT_A}/profile/avatar.png`,
  announcementImage: `announcements/ann-1/image.png`,
  groupMessageFile: `groups/${GROUP_1}/messages/m-1/attachments/rapor.pdf`,
  groupAnnouncementFile: `groups/${GROUP_1}/announcements/ders.pdf`,
  otherGroupFile: `groups/${GROUP_2}/announcements/arsiv.pdf`,
};

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: `school-comm-storage-test-${Date.now()}`,
    storage: { rules: RULES },
  });

  // Kurallar atlanarak (Admin SDK benzeri) dosyalar oluşturulur.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const admin = context.storage();
    await uploadBytes(ref(admin, PATHS.avatar), png());
    await uploadBytes(ref(admin, PATHS.announcementImage), png());
    await uploadBytes(ref(admin, PATHS.groupMessageFile), pdf());
    await uploadBytes(ref(admin, PATHS.groupAnnouncementFile), pdf());
    await uploadBytes(ref(admin, PATHS.otherGroupFile), pdf());
  });
});

after(async () => {
  await testEnv.cleanup();
});

describe("profil görselleri", () => {
  it("öğrenci kendi profil görselini indirebilir", async () => {
    await assertSucceeds(getBytes(ref(storage(memberAuth), PATHS.avatar)));
  });

  it("öğrenci başkasının profil görselini indiremez", async () => {
    await assertFails(getBytes(ref(storage(outsiderAuth), PATHS.avatar)));
  });

  it("anonim kullanıcı indiremez", async () => {
    await assertFails(getBytes(ref(storage(null), PATHS.avatar)));
  });

  it("pasif hesap indiremez", async () => {
    await assertFails(getBytes(ref(storage(inactiveAuth), PATHS.avatar)));
  });

  it("admin her profil görselini indirebilir", async () => {
    await assertSucceeds(getBytes(ref(storage(adminAuth), PATHS.avatar)));
  });

  it("öğrenci başkasının profil klasörüne yazamaz", async () => {
    await assertFails(uploadBytes(ref(storage(outsiderAuth), PATHS.avatar), png()));
  });

  it("anonim kullanıcı yazamaz", async () => {
    await assertFails(uploadBytes(ref(storage(null), PATHS.avatar), png()));
  });
});

describe("duyuru dosyaları", () => {
  it("admin duyuru görselini okuyabilir", async () => {
    await assertSucceeds(getBytes(ref(storage(adminAuth), PATHS.announcementImage)));
  });

  it("öğrenci duyuru klasörüne yazamaz", async () => {
    await assertFails(uploadBytes(ref(storage(memberAuth), PATHS.announcementImage), png()));
  });
});

describe("grup dosyaları — okuma (üyelik denetimi)", () => {
  it("üye kendi grubunun mesaj ekini indirebilir", async () => {
    await assertSucceeds(getBytes(ref(storage(memberAuth), PATHS.groupMessageFile)));
  });

  it("üye kendi grubunun duyuru ekini indirebilir", async () => {
    await assertSucceeds(getBytes(ref(storage(memberAuth), PATHS.groupAnnouncementFile)));
  });

  it("üye olmayan öğrenci grup dosyasını indiremez", async () => {
    await assertFails(getBytes(ref(storage(outsiderAuth), PATHS.groupMessageFile)));
    await assertFails(getBytes(ref(storage(outsiderAuth), PATHS.groupAnnouncementFile)));
  });

  it("claim'de olmayan grup için erişim reddedilir", async () => {
    await assertFails(getBytes(ref(storage(outsiderAuth), PATHS.otherGroupFile)));
  });

  it("anonim kullanıcı grup ekini indiremez", async () => {
    await assertFails(getBytes(ref(storage(null), PATHS.groupMessageFile)));
  });

  it("pasif hesap grup ekini indiremez", async () => {
    await assertFails(getBytes(ref(storage(inactiveAuth), PATHS.groupMessageFile)));
  });

  it("admin her grup dosyasını indirebilir", async () => {
    await assertSucceeds(getBytes(ref(storage(adminAuth), PATHS.otherGroupFile)));
  });
});

describe("grup dosyaları — yazma yetkileri", () => {
  it("üye olmayan öğrenci grup mesajına ek yükleyemez", async () => {
    await assertFails(
      uploadBytes(ref(storage(outsiderAuth), `groups/${GROUP_1}/messages/m-2/attachments/a.pdf`), pdf()),
    );
  });

  it("üye olmayan öğrenci claim'de olmayan gruba yükleyemez", async () => {
    await assertFails(
      uploadBytes(ref(storage(outsiderAuth), `groups/${GROUP_2}/messages/m-3/attachments/a.pdf`), pdf()),
    );
  });

  it("pasif hesap yükleyemez", async () => {
    await assertFails(
      uploadBytes(ref(storage(inactiveAuth), `groups/${GROUP_1}/messages/m-4/attachments/a.pdf`), pdf()),
    );
  });

  it("öğrenci grup duyurusu eki yazamaz (sadece admin)", async () => {
    await assertFails(
      uploadBytes(ref(storage(memberAuth), `groups/${GROUP_1}/announcements/yeni.pdf`), pdf()),
    );
  });

  it("anonim kullanıcı yükleyemez", async () => {
    await assertFails(
      uploadBytes(ref(storage(null), `groups/${GROUP_1}/messages/m-5/attachments/a.pdf`), pdf()),
    );
  });

  // Aşağıdaki "izin verilmeli" yazmalar, emülatör `request.resource`
  // metadatasını doldurmadığı için burada doğrulanamaz (dosya başındaki not).
  // Gerçek projede doğrulama:
  //   firebase emulators:start --only storage   →  Emulator UI → Storage
  //   veya storage.rules'ı gerçek projede yayınlayıp uygulamadan yükleme yapmak.

  it("admin mesaj eki silebilir", async () => {
    await assertSucceeds(deleteObject(ref(storage(adminAuth), PATHS.otherGroupFile)));
  });
});
