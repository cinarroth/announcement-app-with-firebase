import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { COLLECTIONS, db } from "./lib/auth";
import { createNotificationRecords, sendPushToUsers } from "./lib/fcm";
import { collectMembers } from "./announcements";

// Yeni grup mesajında üyelere push + bildirim kaydı; gönderen hariç.
// notificationDispatched yine retry koruması.
export const onGroupMessageCreated = onDocumentCreated(
  "groups/{groupId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const groupId = event.params["groupId"];
    const messageId = event.params["messageId"];
    const data = snapshot.data();
    if (!data || data.notificationDispatched === true) return;

    const senderId = String(data.senderId ?? "");
    const isAdminMessage = data.senderRole === "admin";

    const memberIds = await collectMembers([groupId]);
    const recipients = memberIds.filter((uid) => uid !== senderId);
    if (recipients.length === 0) {
      await snapshot.ref.set({ notificationDispatched: true }, { merge: true });
      return;
    }

    const groupSnap = await db().doc(`${COLLECTIONS.groups}/${groupId}`).get();
    const groupName = String(groupSnap.get("name") ?? "Grup");
    const body = String(data.content ?? "").slice(0, 180);
    const hasAttachment = Array.isArray(data.attachments) && data.attachments.length > 0;
    const preview = body || (hasAttachment ? "Bir dosya gönderildi" : "Yeni mesaj");

    const push = await sendPushToUsers(recipients, {
      title: isAdminMessage ? `${groupName} · Duyuru` : `${groupName} · Yeni mesaj`,
      body: preview,
      data: {
        type: "message",
        groupId,
        messageId,
        route: "/groups/$groupId/messages",
      },
    });

    await createNotificationRecords(recipients, {
      title: `${groupName} · ${isAdminMessage ? "Duyuru" : "Yeni mesaj"}`,
      body: preview,
      type: "message",
      groupId,
      messageId,
    });

    await snapshot.ref.set(
      {
        notificationDispatched: true,
        notifiedCount: recipients.length,
        pushSuccessCount: push.success,
      },
      { merge: true },
    );

    logger.info("Grup mesajı bildirimi gönderildi.", {
      groupId,
      messageId,
      recipients: recipients.length,
      pushSuccess: push.success,
    });
  },
);
