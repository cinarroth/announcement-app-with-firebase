import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../models/models.dart';
import '../services/firebase_services.dart';

/// Duyurular.
///
/// array-contains-any sorgusu en fazla 10 değer kabul ettiği için grup
/// kimlikleri 10'lu parçalara bölünür, akışlar birleştirilir; aynı duyuru
/// iki grupta da olsa tek kez döner.
class AnnouncementRepository {
  AnnouncementRepository({required FirebaseServices services})
      : _db = services.firestore,
        _auth = services.auth;

  static const _disjunctLimit = 10;

  final FirebaseFirestore _db;
  final auth.FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _raw => _db.collection('announcements');

  CollectionReference<Announcement> get _announcements =>
      _db.collection('announcements').withConverter<Announcement>(
        fromFirestore: (snap, _) => Announcement.fromMap(snap.data() ?? const {}, snap.id),
        toFirestore: (announcement, _) => {
          'title': announcement.title,
          'content': announcement.content,
          'createdBy': announcement.createdBy,
          'createdAt': Timestamp.fromDate(announcement.createdAt),
          'publishedAt': Timestamp.fromDate(announcement.publishedAt),
          'expiresAt': announcement.expiresAt == null
              ? null
              : Timestamp.fromDate(announcement.expiresAt!),
          'targetGroupIds': announcement.targetGroupIds,
          'imageUrl': announcement.imageUrl,
          'attachments': announcement.attachments.map((a) => a.toMap()).toList(),
          'readCount': announcement.readCount,
        },
      );

  Stream<List<Announcement>> watchAll({int limit = 100}) => _announcements
      .orderBy('publishedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).whereType<Announcement>().toList());

  Stream<List<Announcement>> watchGroupAnnouncements(
    String groupId, {
    int limit = 50,
  }) =>
      _announcements
          .where('targetGroupIds', arrayContains: groupId)
          .orderBy('publishedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.data()).whereType<Announcement>().toList());

  Future<Announcement?> getAnnouncement(String id) async =>
      (await _announcements.doc(id).get()).data();

  // Dokümanı admin yazar; push'ı onAnnouncementCreated trigger'ı atar.
  Future<String> create({
    required String title,
    required String content,
    required List<String> targetGroupIds,
    DateTime? publishedAt,
    DateTime? expiresAt,
    String? imageUrl,
    List<Attachment> attachments = const [],
  }) async {
    final ref = _raw.doc();
    await ref.set({
      'title': title,
      'content': content,
      'createdBy': _auth.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'publishedAt': publishedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(publishedAt),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'targetGroupIds': targetGroupIds,
      'imageUrl': imageUrl,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'readCount': 0,
    });
    return ref.id;
  }

  Future<void> update({
    required String id,
    required String title,
    required String content,
    required List<String> targetGroupIds,
    DateTime? expiresAt,
    String? imageUrl,
    List<Attachment> attachments = const [],
  }) async {
    await _raw.doc(id).update({
      'title': title,
      'content': content,
      'targetGroupIds': targetGroupIds,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'imageUrl': imageUrl,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _raw.doc(id).delete();

  /// Öğrencinin görebileceği duyurular.
  ///
  /// Grup listesi boşsa sadece sistem geneli duyurular çekilir.
  /// isEqualTo: [] filtresi şart; Firestore, sorgunun kural tarafından
  /// süzülebileceğinden emin olmadan tüm sorguyu reddediyor.
  /// Süresi geçenler istemcide de elenir, asıl sınır kuralda.
  Stream<List<Announcement>> watchMyAnnouncements({
    required List<String> groupIds,
    int limit = 30,
  }) async* {
    if (groupIds.isEmpty) {
      yield* _announcements
          .where('targetGroupIds', isEqualTo: const <String>[])
          .orderBy('publishedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => _publishable(snap.docs.map((d) => d.data()).whereType<Announcement>()));
      return;
    }

    final streams = <Stream<List<Announcement>>>[];
    for (final slice in _chunks(groupIds, _disjunctLimit)) {
      streams.add(
        _announcements
            .where('targetGroupIds', arrayContainsAny: slice)
            .orderBy('publishedAt', descending: true)
            .limit(limit)
            .snapshots()
            .map((snap) => _publishable(snap.docs.map((d) => d.data()).whereType<Announcement>())),
      );
    }
    yield* _merge(streams, limit);
  }

  List<Announcement> _publishable(Iterable<Announcement> items) {
    final now = DateTime.now();
    return items.where((a) => !a.isExpiredAt(now)).toList();
  }

  /// Aynı id bir kez tutulur, sıralı döner; iptalde tüm alt akışlar kapanır.
  Stream<List<Announcement>> _merge(
    List<Stream<List<Announcement>>> streams,
    int limit,
  ) {
    return Stream<List<Announcement>>.multi((controller) {
      final latest = <String, Announcement>{};
      final subscriptions = <StreamSubscription<List<Announcement>>>[];

      for (final stream in streams) {
        subscriptions.add(
          stream.listen(
            (items) {
              for (final item in items) {
                latest[item.id] = item;
              }
              final sorted = latest.values.toList()
                ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
              controller.add(sorted.take(limit).toList());
            },
            onError: controller.addError,
          ),
        );
      }

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  Iterable<List<String>> _chunks(List<String> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      yield items.sublist(i, (i + size).clamp(0, items.length));
    }
  }

  // Duyuruyu okundu işaretler; yazma ayna koleksiyonuna gider, asıl kayıt
  // ve readCount Cloud Functions'ta oluşur.
  Future<void> markAsRead(String announcementId) async {
    await _db
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('announcementReads')
        .doc(announcementId)
        .set({
      'announcementId': announcementId,
      'userId': _auth.currentUser!.uid,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  // Öğrencinin okuduğu duyuru id'leri.
  Future<Set<String>> myReadAnnouncementIds({int limit = 200}) async {
    final snap = await _db
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('announcementReads')
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  Stream<Set<String>> watchMyReadAnnouncementIds({int limit = 200}) => _db
      .collection('users')
      .doc(_auth.currentUser!.uid)
      .collection('announcementReads')
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toSet());

  // count() agregasyonu: 1 okuma.
  Future<int> readCount(String announcementId) async {
    final snap = await _db
        .collection('announcements')
        .doc(announcementId)
        .collection('reads')
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// "Kimler okudu?" → sayfalı liste.
  Future<List<Map<String, dynamic>>> readUsers(
    String announcementId, {
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('announcements')
        .doc(announcementId)
        .collection('reads')
        .orderBy('readAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => <String, dynamic>{'userId': d.id, ...d.data()})
        .toList();
  }

  // Okuyanların profil bilgisi (istatistik ekranı için).
  Future<List<AppUser>> readerProfiles(String announcementId, {int limit = 50}) async {
    final reads = await readUsers(announcementId, limit: limit);
    final ids = reads.map((r) => r['userId'] as String).toList();
    if (ids.isEmpty) return const [];
    final snap = await _db
        .collection('users')
        .where(FieldPath.documentId, isEqualTo: ids)
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.data(), d.id)).toList();
  }
}
