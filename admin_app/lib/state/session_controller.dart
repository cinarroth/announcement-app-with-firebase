import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:school_comm/school_comm.dart';

/// Yönetici oturumu. Yalnızca `role == admin` claim'ine sahip hesaplar
/// panele geçebilir; diğer hesaplar "yetkisiz" ekranıyla karşılaşır.
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    required UploadRepository uploadRepository,
  })  : _auth = authRepository,
        _users = userRepository,
        _uploads = uploadRepository {
    _subscription = _auth.authStateChanges().listen(_onAuthChanged);
  }

  final AuthRepository _auth;
  final UserRepository _users;
  final UploadRepository _uploads;

  StreamSubscription<User?>? _subscription;

  Session _session = Session.empty;
  AppUser? _user;
  bool _loading = true;
  String? _error;

  Session get session => _session;
  AppUser? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isSignedIn => _session.uid.isNotEmpty;
  bool get isAdmin => _session.isAdmin && (_user?.role == UserRole.admin);
  bool get isActive => _user?.isActive ?? false;

  Future<void> _onAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _session = Session.empty;
      _user = null;
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    _session = await _auth.refreshSession();
    _user = await _users.getUser(firebaseUser.uid);
    if (_user?.isActive == true) {
      try {
        await _auth.registerCurrentDevice(uid: _session.uid);
      } catch (_) {
        // Bildirim izni yoksa panelsiz çalışmaya devam eder.
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      await _auth.signIn(email: email, password: password);
      _loading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (error) {
      _error = friendlyAuthError(error);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Profil görselini Storage'a yükleyip kullanıcı dokümanını günceller.
  Future<void> uploadAvatar(File file) async {
    final url = await _uploads.uploadProfileImage(uid: _session.uid, file: file);
    await _users.updateProfile(_session.uid, profileImageUrl: url);
    _user = await _users.getUser(_session.uid);
    notifyListeners();
  }

  Future<void> reload() async {
    final uid = _session.uid;
    if (uid.isEmpty) return;
    _session = await _auth.refreshSession();
    _user = await _users.getUser(uid);
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  static String friendlyAuthError(FirebaseAuthException error) => switch (error.code) {
        'invalid-email' => 'E-posta adresi geçersiz.',
        'user-disabled' => 'Bu hesap pasifleştirilmiş.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'E-posta veya şifre hatalı.',
        'too-many-requests' => 'Çok fazla deneme yapıldı. Biraz sonra tekrar deneyin.',
        'network-request-failed' => 'Bağlantı hatası. İnternet bağlantınızı kontrol edin.',
        _ => 'Giriş başarısız: ${error.message ?? error.code}',
      };

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
