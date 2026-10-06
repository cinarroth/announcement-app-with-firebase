import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../services/firebase_services.dart';

/// Oturum durumu; rol token claim'inden gelir, istemci atayamaz.
class Session {
  const Session({required this.uid, required this.isAdmin, required this.groupIds});

  final String uid;
  final bool isAdmin;
  final List<String> groupIds;

  static const empty = Session(uid: '', isAdmin: false, groupIds: []);
}

class AuthRepository {
  AuthRepository({required FirebaseServices services})
      : _auth = services.auth,
        _db = services.firestore,
        _messaging = services.messaging;

  final auth.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;

  auth.User? get currentUser => _auth.currentUser;

  Stream<auth.User?> authStateChanges() => _auth.userChanges();

  /// Giriş sonrası rol ve grup listesi token'dan okunur.
  Future<Session> currentSession({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return Session.empty;
    final token = await user.getIdTokenResult(forceRefresh);
    return _sessionFrom(token, user.uid);
  }

  // Rol/üyelik değişince token tazelenmeli; eski claim ~1 saat önbellekte kalır.
  Future<Session> refreshSession() => currentSession(forceRefresh: true);

  Session _sessionFrom(auth.IdTokenResult token, String uid) {
    final claims = token.claims ?? const {};
    return Session(
      uid: uid,
      isAdmin: claims['role'] == 'admin',
      groupIds: (claims['groupIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  Future<auth.UserCredential> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<auth.UserCredential> register({
    required String email,
    required String password,
    String? displayName,
  }) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      return _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).then((credential) async {
        await credential.user!.updateDisplayName(displayName.trim());
        return credential;
      });
    }
    return _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  // FCM token'ını users/{uid}/devices altına yazar; token yenilenince aynı
  // kayıt güncellenir, birden fazla cihaz desteklenir.
  Future<void> registerDevice({
    required String uid,
    required String deviceId,
    required String token,
    String? model,
  }) async {
    await _db.collection('users').doc(uid).collection('devices').doc(deviceId).set({
      'userId': uid,
      'deviceId': deviceId,
      'fcmToken': token,
      'platform': defaultTargetPlatform.name,
      'model': model ?? '',
      'enabled': true,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unregisterDevice({required String uid, required String deviceId}) async {
    await _db.collection('users').doc(uid).collection('devices').doc(deviceId).delete();
  }

  // Token değişmişse kaydı günceller.
  Future<void> syncDeviceToken({
    required String uid,
    required String deviceId,
    String? previousToken,
  }) async {
    final token = await _messaging.getToken();
    if (token == null || token == previousToken) return;
    await registerDevice(uid: uid, deviceId: deviceId, token: token);
  }

  // Cihaz kimliği token'ın son 24 karakterinden türetilir; her cihazın
  // token'ı farklı olduğu için kullanıcı birden çok cihazdan girebilir
  // ve token yenilenince aynı belge güncellenir.
  Future<String?> registerCurrentDevice({required String uid, String? model}) async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return null;
    final deviceId = deviceIdForToken(token);
    await registerDevice(uid: uid, deviceId: deviceId, token: token, model: model);
    return deviceId;
  }

  /// Token'dan kararlı cihaz kimliği türetir.
  static String deviceIdForToken(String token) {
    final suffix = token.length <= 24 ? token : token.substring(token.length - 24);
    return '${defaultTargetPlatform.name}-$suffix';
  }
}
