import * as admin from "firebase-admin";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";

export const COLLECTIONS = {
  users: "users",
  groups: "groups",
  announcements: "announcements",
  broadcasts: "broadcasts",
} as const;

export const ROLES = { ADMIN: "admin", STUDENT: "student" } as const;
export type Role = (typeof ROLES)[keyof typeof ROLES];

export const USER_FIELDS = [
  "name",
  "surname",
  "email",
  "role",
  "profileImage",
  "createdAt",
  "isActive",
  "groupIds",
  "unreadCount",
] as const;

export const db = () => admin.firestore();
export const auth = () => admin.auth();
export const FieldValue = admin.firestore.FieldValue;
export const Timestamp = admin.firestore.Timestamp;

export interface UserDoc {
  name: string;
  surname: string;
  email: string;
  role: Role;
  profileImage: string | null;
  createdAt: admin.firestore.Timestamp;
  isActive: boolean;
  // Rules'ın okuduğu üyelik aynası; sadece sunucu yazar.
  groupIds: string[];
  unreadCount: number;
}

export interface GroupDoc {
  name: string;
  description: string;
  createdAt: admin.firestore.Timestamp;
  createdBy: string;
  isActive: boolean;
  memberCount: number;
}

export function clean(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** Callable isteğinin giriş yapmış olmasını zorunlu kılar. */
export function requireAuth<T>(request: CallableRequest<T>): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Oturum açmanız gerekiyor.");
  }
  return uid;
}

// Claim'e tek başına güvenilmez; dokümanla birlikte bakılır.
export async function requireAdmin<T>(request: CallableRequest<T>): Promise<string> {
  const uid = requireAuth(request);
  if (request.auth?.token.role !== ROLES.ADMIN) {
    throw new HttpsError("permission-denied", "Bu işlem için yönetici yetkisi gerekli.");
  }
  const snap = await db().doc(`${COLLECTIONS.users}/${uid}`).get();
  const data = snap.data();
  if (!snap.exists || data?.role !== ROLES.ADMIN || data?.isActive !== true) {
    throw new HttpsError("permission-denied", "Yönetici hesabı pasif veya bulunamadı.");
  }
  return uid;
}

export function assertString(value: unknown, field: string, max = 500): string {
  const text = clean(value);
  if (text.length === 0) {
    throw new HttpsError("invalid-argument", `"${field}" alanı zorunludur.`);
  }
  if (text.length > max) {
    throw new HttpsError("invalid-argument", `"${field}" en fazla ${max} karakter olabilir.`);
  }
  return text;
}

export function assertEmail(value: unknown): string {
  const email = clean(value).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Geçerli bir e-posta adresi giriniz.");
  }
  return email;
}

export function parseAttachmentList(value: unknown): Attachment[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is Attachment => {
      const a = item as Partial<Attachment> | null;
      return (
        !!a &&
        typeof a.url === "string" &&
        typeof a.name === "string" &&
        typeof a.mimeType === "string" &&
        typeof a.size === "number" &&
        a.size > 0 &&
        a.size <= 10 * 1024 * 1024
      );
    })
    .slice(0, 5)
    .map((item) => ({
      url: item.url,
      name: item.name.slice(0, 200),
      mimeType: item.mimeType.slice(0, 100),
      size: item.size,
    }));
}

export interface Attachment {
  url: string;
  name: string;
  mimeType: string;
  size: number;
}
