/// Uygulamanın tüm veri modelleri.
///
/// Modeller yalnızca düz (immutable) Dart sınıflarıdır; Firestore'a bağımlılık
/// yoktur, böylece saf Dart testlerinde kullanılabilirler.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcının rolü. Kaynak: custom claim + `users/{uid}.role`.
enum UserRole {
  admin('admin'),
  student('student');

  const UserRole(this.value);
  final String value;

  static UserRole fromValue(Object? value) =>
      value == 'admin' ? UserRole.admin : UserRole.student;
}

enum MessageType { text, file, system }

MessageType messageTypeFromValue(Object? value) => switch (value) {
      'file' => MessageType.file,
      'system' => MessageType.system,
      _ => MessageType.text,
    };

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.profileImage,
    this.groupIds = const [],
    this.unreadCount = 0,
  });

  final String id;
  final String name;
  final String surname;
  final String email;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final String? profileImage;

  /// Security Rules'ın kullandığı grup üyeliği aynası (sunucu tarafında yazılır).
  final List<String> groupIds;
  final int unreadCount;

  bool get isAdmin => role == UserRole.admin;
  String get fullName => [name, surname].where((p) => p.isNotEmpty).join(' ');
  String get initials {
    final parts = [name, surname].where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.map((p) => p.substring(0, 1).toUpperCase()).take(2).join();
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String id) => AppUser(
        id: id,
        name: map['name'] as String? ?? '',
        surname: map['surname'] as String? ?? '',
        email: map['email'] as String? ?? '',
        role: UserRole.fromValue(map['role']),
        isActive: map['isActive'] as bool? ?? false,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        profileImage: map['profileImage'] as String?,
        groupIds: (map['groupIds'] as List?)?.cast<String>() ?? const [],
        unreadCount: map['unreadCount'] as int? ?? 0,
      );
}

class AppGroup {
  const AppGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.createdBy,
    required this.isActive,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;
  final int memberCount;

  factory AppGroup.fromMap(Map<String, dynamic> map, String id) => AppGroup(
        id: id,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        createdBy: map['createdBy'] as String? ?? '',
        isActive: map['isActive'] as bool? ?? true,
        memberCount: map['memberCount'] as int? ?? 0,
      );
}

/// `groups/{gid}/members/{uid}` — üyeliğin gerçek kaynağı.
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.joinedAt,
  });

  final String userId;
  final String displayName;
  final DateTime joinedAt;

  factory GroupMember.fromMap(Map<String, dynamic> map, String userId) => GroupMember(
        userId: userId,
        displayName: map['displayName'] as String? ?? '',
        joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class Attachment {
  const Attachment({
    required this.url,
    required this.name,
    required this.mimeType,
    required this.size,
  });

  final String url;
  final String name;
  final String mimeType;
  final int size;

  bool get isImage => mimeType.startsWith('image/');

  factory Attachment.fromMap(Map<String, dynamic> map) => Attachment(
        url: map['url'] as String? ?? '',
        name: map['name'] as String? ?? 'dosya',
        mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
        size: map['size'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'url': url,
        'name': name,
        'mimeType': mimeType,
        'size': size,
      };
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdBy,
    required this.createdAt,
    required this.publishedAt,
    required this.targetGroupIds,
    this.expiresAt,
    this.imageUrl,
    this.attachments = const [],
    this.readCount = 0,
    this.notifiedCount = 0,
  });

  final String id;
  final String title;
  final String content;
  final String createdBy;
  final DateTime createdAt;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final List<String> targetGroupIds;
  final String? imageUrl;
  final List<Attachment> attachments;
  final int readCount;
  final int notifiedCount;

  bool isExpiredAt(DateTime now) => expiresAt != null && expiresAt!.isBefore(now);
  bool isPublishedAt(DateTime now) => !publishedAt.isAfter(now);

  factory Announcement.fromMap(Map<String, dynamic> map, String id) => Announcement(
        id: id,
        title: map['title'] as String? ?? '',
        content: map['content'] as String? ?? '',
        createdBy: map['createdBy'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        publishedAt: (map['publishedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
        targetGroupIds: (map['targetGroupIds'] as List?)?.cast<String>() ?? const [],
        imageUrl: map['imageUrl'] as String?,
        attachments: (map['attachments'] as List?)
                ?.whereType<Map>()
                .map((e) => Attachment.fromMap(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        readCount: map['readCount'] as int? ?? 0,
        notifiedCount: map['notifiedCount'] as int? ?? 0,
      );
}

class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.createdAt,
    this.attachments = const [],
    this.senderRole = 'student',
  });

  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final List<Attachment> attachments;
  final String senderRole;

  bool isFrom(String userId) => senderId == userId;

  factory GroupMessage.fromMap(Map<String, dynamic> map, String id, String groupId) =>
      GroupMessage(
        id: id,
        groupId: groupId,
        senderId: map['senderId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? '',
        content: map['content'] as String? ?? '',
        type: messageTypeFromValue(map['type']),
        senderRole: map['senderRole'] as String? ?? 'student',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        attachments: (map['attachments'] as List?)
                ?.whereType<Map>()
                .map((e) => Attachment.fromMap(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.announcementId,
    this.groupId,
    this.messageId,
    this.isBroadcast = false,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? announcementId;
  final String? groupId;
  final String? messageId;
  final bool isBroadcast;

  factory AppNotification.fromMap(Map<String, dynamic> map, String id, {bool isBroadcast = false}) =>
      AppNotification(
        id: id,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        type: map['type'] as String? ?? 'system',
        // Sistem duyurularında `isRead` alanı yoktur; okunmuş kabul edilir.
        isRead: map['isRead'] as bool? ?? isBroadcast,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        announcementId: map['announcementId'] as String?,
        groupId: map['groupId'] as String?,
        messageId: map['messageId'] as String?,
        isBroadcast: isBroadcast,
      );
}

/// `users/{uid}/announcementReads/{aid}` — öğrenci tarafı okundu aynası.
class AnnouncementRead {
  const AnnouncementRead({
    required this.announcementId,
    required this.readAt,
  });

  final String announcementId;
  final DateTime readAt;
}
