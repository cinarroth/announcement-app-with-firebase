import { randomUUID } from "crypto";
import * as admin from "firebase-admin";
import { COLLECTIONS, db } from "./auth";

/** Firestore `in` sorgusu en fazla 30 değer kabul eder. */
export const CHUNK_SIZE = 30;
export const FCM_BATCH = 500;

export function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface DeviceRef {
  userId: string;
  docPath: string;
  token: string;
}

// Etkin cihaz token'larını toplar (enabled == false olanlar atlanır).
export async function collectDeviceTokens(userIds: string[]): Promise<DeviceRef[]> {
  const devices: DeviceRef[] = [];
  for (const ids of chunk(Array.from(new Set(userIds)), CHUNK_SIZE)) {
    const snap = await db()
      .collectionGroup("devices")
      .where("userId", "in", ids)
      .where("enabled", "==", true)
      .get();
    for (const doc of snap.docs) {
      const userId = doc.get("userId");
      const token = doc.get("fcmToken");
      if (typeof userId === "string" && typeof token === "string" && token.length > 10) {
        devices.push({ userId, docPath: doc.ref.path, token });
      }
    }
  }
  return devices;
}

// Push gönderir; geçersiz token'ların cihaz kayıtlarını siler.
export async function sendPushToUsers(
  userIds: string[],
  payload: PushPayload,
): Promise<{ success: number; failure: number; invalidTokensRemoved: number }> {
  const devices = await collectDeviceTokens(userIds);
  let success = 0;
  let failure = 0;
  let invalidTokensRemoved = 0;

  for (const batch of chunk(devices, FCM_BATCH)) {
    // `sendEach` (multicast değil) kullanılır: hangi token'ın başarısız
    // olduğunu belgelerle eşleştirebilmek için yanıtlar sırayla döner.
    const response = await admin.messaging().sendEach(
      batch.map((device) => ({
        token: device.token,
        data: payload.data ?? {},
        notification: { title: payload.title, body: payload.body },
        android: {
          priority: "high" as const,
          notification: { channelId: "default", sound: "default" },
        },
      })),
    );

    success += response.successCount;
    failure += response.failureCount;

    const invalidDocPaths: string[] = [];
    response.responses.forEach((res, index) => {
      if (res.success) return;
      const code = res.error?.code ?? "";
      if (
        code.includes("registration-token-not-registered") ||
        code.includes("invalid-argument") ||
        code.includes("invalid-registration-token")
      ) {
        invalidDocPaths.push(batch[index].docPath);
      }
    });

    if (invalidDocPaths.length > 0) {
      const cleanup = db().batch();
      for (const path of invalidDocPaths) {
        cleanup.delete(admin.firestore().doc(path));
      }
      await cleanup.commit();
      invalidTokensRemoved += invalidDocPaths.length;
    }
  }

  return { success, failure, invalidTokensRemoved };
}

// Bildirim kaydı yazar + unreadCount artırır. Batch limitine takılmamak
// için 200'lik dilimler.
export async function createNotificationRecords(
  userIds: string[],
  notification: {
    title: string;
    body: string;
    type: string;
    announcementId?: string;
    groupId?: string;
    messageId?: string;
  },
): Promise<void> {
  const unique = Array.from(new Set(userIds));
  const notificationId = randomUUID();

  for (const ids of chunk(unique, 200)) {
    const batch = db().batch();
    for (const userId of ids) {
      const ref = db()
        .collection(COLLECTIONS.users)
        .doc(userId)
        .collection("notifications")
        .doc(notificationId);
      batch.set(ref, {
        ...notification,
        userId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batch.set(
        db().collection(COLLECTIONS.users).doc(userId),
        { unreadCount: admin.firestore.FieldValue.increment(1) },
        { merge: true },
      );
    }
    await batch.commit();
  }
}
