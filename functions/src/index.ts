import { initializeApp } from "firebase-admin/app";

initializeApp();

export { beforeUserCreatedHandler } from "./auth";
export {
  createStudentAccount,
  deleteUser,
  sendPasswordReset,
  setUserRole,
} from "./users";
export { createGroup, deleteGroup, setGroupMembership, updateGroup } from "./groups";
export { onAnnouncementCreated, onAnnouncementReadCreated } from "./announcements";
export { onGroupMessageCreated } from "./messages";
export { dispatchBroadcastPush, pruneInvalidDevices, sendBroadcast } from "./broadcasts";
