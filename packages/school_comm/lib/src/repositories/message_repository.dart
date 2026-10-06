import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../models/models.dart';
import '../services/firebase_services.dart';

/// Grup mesajlaşması.
///
/// Dinleyici sadece ekran açıkken kurulur (maliyet disiplini);
/// orderBy + limitToLast ile son mesajlar çekilir.
class MessageRepository {
  MessageRepository({required FirebaseServices services})
      : _db = services.firestore,
        _auth = services.auth;

  final FirebaseFirestore _db;
  final auth.FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _rawMessages(String groupId) =>
      _db.collection('groups').doc(groupId).collection('messages');

  CollectionReference<GroupMessage> _messages(String groupId) => _db
      .collection('groups')
      .doc(groupId)
      .collection('messages')
      .withConverter<GroupMessage>(
        fromFirestore: (snap, _) => GroupMessage.fromMap(snap.data() ?? const {}, snap.id, groupId),
        toFirestore: (message, _) => {
          'senderId': message.senderId,
          'senderName': message.senderName,
          'senderRole': message.senderRole,
          'content': message.content,
          'type': message.type.name,
          'attachments': message.attachments.map((a) => a.toMap()).toList(),
          'createdAt': Timestamp.fromDate(message.createdAt),
        },
      );

  Stream<List<GroupMessage>> watchMessages(
    String groupId, {
    int limit = 50,
  }) =>
      _messages(groupId)
          .orderBy('createdAt', descending: true)
          .limitToLast(limit)
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.data()).whereType<GroupMessage>().toList().reversed.toList());

  // Admin gruba mesaj gönderir; push'ı onGroupMessageCreated atar.
  Future<String> send({
    required String groupId,
    required String content,
    List<Attachment> attachments = const [],
    MessageType type = MessageType.text,
  }) async {
    final id = createMessageId();
    await sendWithId(
      groupId: groupId,
      messageId: id,
      content: content,
      attachments: attachments,
      type: type,
    );
    return id;
  }

  // Belge kimliğini istemci üretir: ekli mesajlarda dosya, mesaj yazılmadan
  // önce attachments/... yoluna yüklenir. doc().id sadece kimlik üretir,
  // veritabanına yazmaz.
  String createMessageId() => _db.collection('__ids__').doc().id;

  Future<void> sendWithId({
    required String groupId,
    required String messageId,
    required String content,
    List<Attachment> attachments = const [],
    MessageType type = MessageType.text,
  }) async {
    final uid = _auth.currentUser!.uid;
    final profile = await _db.collection('users').doc(uid).get();
    final displayName = [
      profile.get('name'),
      profile.get('surname'),
    ].whereType<String>().join(' ').trim();

    await _rawMessages(groupId).doc(messageId).set({
      'senderId': uid,
      'senderName': displayName,
      'senderRole': profile.get('role') ?? 'student',
      'content': content,
      'type': type.name,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gönderen kendi mesajını, admin her mesajı silebilir (kurallar kontrol eder).
  Future<void> deleteMessage(String groupId, String messageId) =>
      _db.collection('groups').doc(groupId).collection('messages').doc(messageId).delete();

  /// Son mesajın zaman damgası — grup listesi hızlı açılsın diye.
  Future<DateTime?> lastMessageAt(String groupId) async {
    final snap = await _messages(groupId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data().createdAt;
  }
}
