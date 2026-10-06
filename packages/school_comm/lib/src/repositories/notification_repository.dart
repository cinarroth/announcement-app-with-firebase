import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../models/models.dart';
import '../services/firebase_services.dart';

/// Bildirim gelen kutusu.
///
/// Kişisel bildirimler users/{uid}/notifications altında, sistem geneli
/// duyurular broadcasts'ta (fan-out yok).
class NotificationRepository {
  NotificationRepository({required FirebaseServices services})
      : _db = services.firestore,
        _auth = services.auth;

  final FirebaseFirestore _db;
  final auth.FirebaseAuth _auth;

  static final _functions = FirebaseFunctions.instance;

  /// Kişisel bildirimler + sistem duyuruları birleşik akış.
  Stream<List<AppNotification>> watchMyNotifications({int limit = 50}) {
    final personal = _db
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _toModel(d.id, d.data())).toList());

    final broadcasts = _db
        .collection('broadcasts')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _toModel(d.id, d.data(), isBroadcast: true)).toList());

    return Stream<List<AppNotification>>.multi((controller) {
      final subscriptions = <StreamSubscription<List<AppNotification>>>[];

      for (final stream in [personal, broadcasts]) {
        subscriptions.add(
          stream.listen(
            (items) {
              controller.add(items);
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

  AppNotification _toModel(String id, Map<String, dynamic> data, {bool isBroadcast = false}) =>
      AppNotification.fromMap(data, id, isBroadcast: isBroadcast);

  Future<void> markAsRead(String notificationId) async {
    await _db
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Tek bildirimi okundu işaretler (arayüz başka isim çağırıyor).
  Future<void> markAllAsReadOrOne(String notificationId) => markAsRead(notificationId);

  Future<void> markAllAsRead() async {
    final unread = await _db
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .limit(400)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Sistem geneli duyuru; push dağıtımı sunucuda.
  Future<String> sendBroadcast({required String title, required String content}) async {
    final result = await _functions.httpsCallable('sendBroadcast').call<Map<String, dynamic>>(
      {'title': title, 'content': content},
    );
    final id = result.data['broadcastId'];
    if (id is! String) throw StateError('Duyuru gönderilemedi.');
    return id;
  }

  Future<void> dispatchBroadcastPush(String broadcastId) async {
    await _functions
        .httpsCallable('dispatchBroadcastPush')
        .call<void>({'broadcastId': broadcastId});
  }

  Stream<List<AppNotification>> watchBroadcasts({int limit = 100}) => _db
      .collection('broadcasts')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => _toModel(d.id, d.data(), isBroadcast: true))
          .toList());

  Future<void> setBroadcastActive(String id, bool isActive) =>
      _db.collection('broadcasts').doc(id).update({'isActive': isActive});

  Future<void> deleteBroadcast(String id) => _db.collection('broadcasts').doc(id).delete();
}
