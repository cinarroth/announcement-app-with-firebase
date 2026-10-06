// Firestore kuralları testleri (emülatör + @firebase/rules-unit-testing).
// Çalıştırma: npm run test:rules
//
// Her "reddedilmeli" testi bir güvenlik açığını temsil eder;
// "izin verilmeli" testleri ürünün çalışması için gereken yolları sabitler.

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  addDoc,
  serverTimestamp,
} from "firebase/firestore";
import { after, before, describe, it } from "mocha";

let testEnv;

const RULES = readFileSync("firestore.rules", "utf8");

const ADMIN_ID = "admin-1";
const STUDENT_A = "student-a";
const STUDENT_B = "student-b";
const GROUP_1 = "group-1";
const GROUP_2 = "group-2";
const ANNOUNCEMENT_1 = "announcement-1";

const adminAuth = { uid: ADMIN_ID, token: { role: "admin", groupIds: [] } };
const studentAAuth = { uid: STUDENT_A, token: { role: "student", groupIds: [GROUP_1] } };
const studentBNoGroup = { uid: STUDENT_B, token: { role: "student", groupIds: [] } };
const anonymous = null;

function firestore(auth) {
  // uid verilmediğinde gerçek anonim (unauthenticated) bağlam kullanılır.
  if (!auth) return testEnv.unauthenticatedContext().firestore();
  return testEnv.authenticatedContext(auth.uid, auth.token).firestore();
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: `school-comm-test-${Date.now()}`,
    firestore: { rules: RULES },
  });

  // Sunucunun yazdığı veriler (kurallar atlanarak).
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, "users", ADMIN_ID), {
      name: "Ada",
      surname: "Yönetici",
      email: "admin@okul.edu",
      role: "admin",
      isActive: true,
      groupIds: [],
      createdAt: new Date(),
    });

    for (const uid of [STUDENT_A, STUDENT_B]) {
      await setDoc(doc(db, "users", uid), {
        name: uid === STUDENT_A ? "Ali" : "Veli",
        surname: "Öğrenci",
        email: `${uid}@okul.edu`,
        role: "student",
        isActive: true,
        // Öğrenci A GROUP_1 üyesi (aynada da görünür), B üye değil.
        groupIds: uid === STUDENT_A ? [GROUP_1] : [],
        unreadCount: 0,
        createdAt: new Date(),
      });
    }

    for (const [groupId, name] of [
      [GROUP_1, "5-A Sınıfı"],
      [GROUP_2, "6-B Sınıfı"],
    ]) {
      await setDoc(doc(db, "groups", groupId), {
        name,
        description: "",
        createdAt: new Date(),
        createdBy: ADMIN_ID,
        isActive: true,
        memberCount: 0,
      });
    }

    await setDoc(doc(db, "groups", GROUP_1, "members", STUDENT_A), {
      memberId: STUDENT_A,
      joinedAt: new Date(),
      displayName: "Ali Öğrenci",
    });

    await setDoc(doc(db, "announcements", ANNOUNCEMENT_1), {
      title: "Sınav tarihi",
      content: "Sınav 15 gün içinde yapılacaktır.",
      createdBy: ADMIN_ID,
      createdAt: new Date(),
      publishedAt: new Date(),
      expiresAt: null,
      targetGroupIds: [GROUP_1],
      attachments: [],
      readCount: 0,
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

describe("users koleksiyonu", () => {
  it("öğrenci kendi profilini okuyabilir", async () => {
    await assertSucceeds(getDoc(doc(firestore(studentAAuth), "users", STUDENT_A)));
  });

  it("öğrenci başka öğrencinin profilini okuyamaz", async () => {
    await assertFails(getDoc(doc(firestore(studentAAuth), "users", STUDENT_B)));
  });

  it("admin herkesin profilini okuyabilir", async () => {
    await assertSucceeds(getDoc(doc(firestore(adminAuth), "users", STUDENT_B)));
  });

  it("anonim kullanıcı hiçbir şey okuyamaz", async () => {
    await assertFails(getDoc(doc(firestore(anonymous), "users", STUDENT_A)));
  });

  it("öğrenci kendi profilini oluşturamaz (yalnızca Cloud Functions)", async () => {
    await assertFails(
      setDoc(doc(firestore(studentAAuth), "users", "sahte"), {
        name: "Sahte",
        role: "admin",
        isActive: true,
      }),
    );
  });

  it("öğrenci rolünü kendi belgesinden yükseltemez", async () => {
    await assertFails(
      updateDoc(doc(firestore(studentAAuth), "users", STUDENT_A), { role: "admin" }),
    );
  });

  it("öğrenci grup üyeliğini aynaya yazamaz", async () => {
    await assertFails(
      updateDoc(doc(firestore(studentAAuth), "users", STUDENT_A), { groupIds: [GROUP_1, GROUP_2] }),
    );
  });

  it("öğrenci kendi profilinin izin verilen alanlarını güncelleyebilir", async () => {
    await assertSucceeds(
      updateDoc(doc(firestore(studentAAuth), "users", STUDENT_A), { phone: "0555 000 00 00" }),
    );
  });
});

describe("groups koleksiyonu", () => {
  it("üye grubu okuyabilir", async () => {
    await assertSucceeds(getDoc(doc(firestore(studentAAuth), "groups", GROUP_1)));
  });

  it("üye olmayan öğrenci grubu okuyamaz", async () => {
    await assertFails(getDoc(doc(firestore(studentBNoGroup), "groups", GROUP_1)));
  });

  it("üye olmayan öğrenci başka bir grubu da okuyamaz", async () => {
    await assertFails(getDoc(doc(firestore(studentBNoGroup), "groups", GROUP_2)));
  });

  it("öğrenci grup oluşturamaz", async () => {
    await assertFails(
      setDoc(doc(firestore(studentAAuth), "groups", "yeni-grup"), {
        name: "Yeni",
        createdBy: STUDENT_A,
      }),
    );
  });

  it("öğrenci grup üyeliğini doğrudan yazamaz", async () => {
    await assertFails(
      setDoc(doc(firestore(studentAAuth), "groups", GROUP_1, "members", STUDENT_B), {
        memberId: STUDENT_B,
      }),
    );
  });

  it("öğrenci başka bir üyeyi üyelikten çıkaramaz", async () => {
    await assertFails(
      // memberCount değişimi de reddedilir: üyelik kaydı CF'ye aittir.
      updateDoc(doc(firestore(studentAAuth), "groups", GROUP_1), { memberCount: 99 }),
    );
  });
});

describe("mesajlar", () => {
  it("üye mesajları okuyabilir", async () => {
    await assertSucceeds(getDoc(doc(firestore(studentAAuth), "groups", GROUP_1, "messages", "m1")));
  });

  it("üye olmayan öğrenci mesajları okuyamaz", async () => {
    await assertFails(getDoc(doc(firestore(studentBNoGroup), "groups", GROUP_1, "messages", "m1")));
  });

  it("üye kendi adına mesaj yazabilir", async () => {
    await assertSucceeds(
      setDoc(doc(firestore(studentAAuth), "groups", GROUP_1, "messages", "m-ok"), {
        senderId: STUDENT_A,
        content: "Merhaba",
        attachments: [],
        createdAt: serverTimestamp(),
      }),
    );
  });

  it("üye başkası adına mesaj yazamaz", async () => {
    await assertFails(
      setDoc(doc(firestore(studentAAuth), "groups", GROUP_1, "messages", "m-saat"), {
        senderId: STUDENT_B,
        content: "Sahte mesaj",
        attachments: [],
        createdAt: serverTimestamp(),
      }),
    );
  });

  it("üye olmayan öğrenci mesaj gönderemez", async () => {
    await assertFails(
      setDoc(doc(firestore(studentBNoGroup), "groups", GROUP_1, "messages", "m-yasak"), {
        senderId: STUDENT_B,
        content: "Merhaba",
        attachments: [],
        createdAt: serverTimestamp(),
      }),
    );
  });

  it("mesajlar değiştirilemez", async () => {
    await assertFails(
      updateDoc(doc(firestore(studentAAuth), "groups", GROUP_1, "messages", "m-ok"), {
        content: "değişti",
      }),
    );
  });

  it("üye başkasının mesajını silemez", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "groups", GROUP_1, "messages", "m-baska"), {
        senderId: STUDENT_B,
        content: "Veli'nin mesajı",
        attachments: [],
        createdAt: new Date(),
      });
    });

    await assertFails(
      deleteDoc(doc(firestore(studentAAuth), "groups", GROUP_1, "messages", "m-baska")),
    );
  });

  it("üye kendi mesajını silebilir", async () => {
    await assertSucceeds(
      deleteDoc(doc(firestore(studentAAuth), "groups", GROUP_1, "messages", "m-ok")),
    );
  });

  it("admin her mesajı silebilir", async () => {
    await assertSucceeds(
      deleteDoc(doc(firestore(adminAuth), "groups", GROUP_1, "messages", "m-baska")),
    );
  });
});

describe("duyurular", () => {
  it("hedef gruptaki öğrenci duyuruyu okuyabilir", async () => {
    await assertSucceeds(getDoc(doc(firestore(studentAAuth), "announcements", ANNOUNCEMENT_1)));
  });

  it("hedeflenmemiş öğrenci duyuruyu okuyamaz", async () => {
    await assertFails(getDoc(doc(firestore(studentBNoGroup), "announcements", ANNOUNCEMENT_1)));
  });

  it("admin her duyuruyu okuyabilir", async () => {
    await assertSucceeds(getDoc(doc(firestore(adminAuth), "announcements", ANNOUNCEMENT_1)));
  });

  it("süresi geçmiş duyuru öğrenciye açık değildir", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "announcements", "expired"), {
        title: "Eski duyuru",
        content: "Süresi doldu",
        createdBy: ADMIN_ID,
        createdAt: new Date(Date.now() - 10 * 86400000),
        publishedAt: new Date(Date.now() - 10 * 86400000),
        expiresAt: new Date(Date.now() - 86400000),
        targetGroupIds: [GROUP_1],
        attachments: [],
      });
    });

    await assertFails(getDoc(doc(firestore(studentAAuth), "announcements", "expired")));
    await assertSucceeds(getDoc(doc(firestore(adminAuth), "announcements", "expired")));
  });

  it("henüz yayınlanmamış duyuru öğrenciye açık değildir", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "announcements", "future"), {
        title: "Gelecek duyuru",
        content: "Yayınlanmadı",
        createdBy: ADMIN_ID,
        createdAt: new Date(),
        publishedAt: new Date(Date.now() + 7 * 86400000),
        expiresAt: null,
        targetGroupIds: [GROUP_1],
        attachments: [],
      });
    });

    await assertFails(getDoc(doc(firestore(studentAAuth), "announcements", "future")));
  });

  it("öğrenci duyuru oluşturamaz", async () => {
    await assertFails(
      addDoc(collection(firestore(studentAAuth), "announcements"), {
        title: "Sahte duyuru",
        content: "Sahte",
        targetGroupIds: [GROUP_1],
        createdBy: STUDENT_A,
        publishedAt: new Date(),
      }),
    );
  });

  it("öğrenci duyuruyu düzenleyemez veya silemez", async () => {
    await assertFails(
      updateDoc(doc(firestore(studentAAuth), "announcements", ANNOUNCEMENT_1), {
        title: "Değişti",
      }),
    );
    await assertFails(deleteDoc(doc(firestore(studentAAuth), "announcements", ANNOUNCEMENT_1)));
  });

  it("admin duyuru oluşturabilir", async () => {
    await assertSucceeds(
      setDoc(doc(firestore(adminAuth), "announcements", "admin-created"), {
        title: "Yeni duyuru",
        content: "İçerik",
        createdBy: ADMIN_ID,
        publishedAt: new Date(),
        expiresAt: null,
        targetGroupIds: [GROUP_2],
        attachments: [],
      }),
    );
  });

  it("öğrenci okundu kaydına başkasının adına yazamaz", async () => {
    await assertFails(
      setDoc(doc(firestore(studentAAuth), "users", STUDENT_A, "announcementReads", ANNOUNCEMENT_1), {
        announcementId: ANNOUNCEMENT_1,
        userId: STUDENT_B,
        readAt: serverTimestamp(),
      }),
    );
  });

  it("öğrenci kendi okundu kaydını oluşturabilir", async () => {
    await assertSucceeds(
      setDoc(doc(firestore(studentAAuth), "users", STUDENT_A, "announcementReads", ANNOUNCEMENT_1), {
        announcementId: ANNOUNCEMENT_1,
        userId: STUDENT_A,
        readAt: serverTimestamp(),
      }),
    );
  });

  it("öğrenci asıl okundu kaydını (admin alanı) okuyamaz", async () => {
    await assertFails(
      getDoc(doc(firestore(studentAAuth), "announcements", ANNOUNCEMENT_1, "reads", STUDENT_A)),
    );
  });

  it("admin asıl okundu kaydını okuyabilir", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "announcements", ANNOUNCEMENT_1, "reads", STUDENT_A),
        { userId: STUDENT_A, announcementId: ANNOUNCEMENT_1, readAt: new Date() },
      );
    });
    await assertSucceeds(
      getDoc(doc(firestore(adminAuth), "announcements", ANNOUNCEMENT_1, "reads", STUDENT_A)),
    );
  });

  it("öğrenci okundu kaydını değiştiremez", async () => {
    await assertFails(
      updateDoc(doc(firestore(studentAAuth), "users", STUDENT_A, "announcementReads", ANNOUNCEMENT_1), {
        userId: STUDENT_B,
      }),
    );
  });
});

describe("bildirimler ve cihazlar", () => {
  it("öğrenci kendi bildirimlerini okuyabilir", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", STUDENT_A, "notifications", "n1"), {
        title: "Yeni duyuru",
        body: "Sınav tarihi",
        isRead: false,
      });
    });
    await assertSucceeds(
      getDoc(doc(firestore(studentAAuth), "users", STUDENT_A, "notifications", "n1")),
    );
  });

  it("öğrenci bildirim oluşturamaz (yalnızca sunucu)", async () => {
    await assertFails(
      setDoc(doc(firestore(studentAAuth), "users", STUDENT_A, "notifications", "sahte"), {
        title: "Sahte",
      }),
    );
  });

  it("öğrenci kendi cihazını kaydedebilir", async () => {
    await assertSucceeds(
      setDoc(doc(firestore(studentAAuth), "users", STUDENT_A, "devices", "device-1"), {
        userId: STUDENT_A,
        fcmToken: "token-1234567890",
        enabled: true,
      }),
    );
  });

  it("öğrenci başkasının cihaz kaydını göremez", async () => {
    await assertFails(
      getDoc(doc(firestore(studentAAuth), "users", STUDENT_B, "devices", "device-1")),
    );
  });
});

describe("broadcasts", () => {
  it("aktif öğrenci sistem duyurusunu okuyabilir", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "broadcasts", "b1"), {
        title: "Sistem",
        content: "Okul yarın tatil.",
        createdBy: ADMIN_ID,
        isActive: true,
        createdAt: new Date(),
      });
    });
    await assertSucceeds(getDoc(doc(firestore(studentAAuth), "broadcasts", "b1")));
  });

  it("öğrenci sistem duyurusu oluşturamaz", async () => {
    await assertFails(
      setDoc(doc(firestore(studentAAuth), "broadcasts", "b2"), {
        title: "Sahte",
        content: "Sahte",
        createdBy: STUDENT_A,
      }),
    );
  });
});

describe("pasif hesap", () => {
  it("pasifleştirilmiş öğrenci veri okuyamaz", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "users", STUDENT_B), { isActive: false });
    });

    await assertFails(getDoc(doc(firestore(studentBNoGroup), "broadcasts", "b1")));
    await assertFails(getDoc(doc(firestore(studentBNoGroup), "groups", GROUP_2)));
  });

  it("pasif hesabı kendi bildirimlerini de okuyamaz", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", STUDENT_B, "notifications", "n1"), {
        title: "x",
      });
    });
    await assertFails(
      getDoc(doc(firestore(studentBNoGroup), "users", STUDENT_B, "notifications", "n1")),
    );
  });
});
