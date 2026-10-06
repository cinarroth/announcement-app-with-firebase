import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:school_comm/school_comm.dart';

/// Oturum: giriş/çıkış, profil ve cihaz kaydı. Rol claim'i sadece arayüz
/// gösterimi için; gerçek yetki kontrolü kurallarda ve sunucudadır.
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
  String? _deviceId;

  Session get session => _session;
  AppUser? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isSignedIn => _session.uid.isNotEmpty;
  bool get isActive => _user?.isActive ?? false;
  int get unreadCount => _user?.unreadCount ?? 0;
  List<String> get groupIds => _session.groupIds;

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

    // Rol/üyelik değişmiş olabilir; token tazelenir.
    _session = await _auth.refreshSession();
    _user = await _users.getUser(firebaseUser.uid);
    await _registerCurrentDevice();
    _loading = false;
    notifyListeners();
  }

  /// Pasif hesaplar bildirim almaz; token yalnızca aktif hesaplarda yazılır.
  Future<void> _registerCurrentDevice() async {
    if (_user == null || !_user!.isActive) return;
    try {
      _deviceId = await _auth.registerCurrentDevice(
        uid: _session.uid,
        model: Platform.operatingSystem,
      );
    } catch (_) {
      // Bildirim izni verilmemiş olabilir; giriş akışını bozmaz.
    }
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

  Future<bool> register({required String email, required String password, String? name}) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      await _auth.register(email: email, password: password, displayName: name);
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

  Future<void> signOut() async {
    final uid = _session.uid;
    final deviceId = _deviceId;
    if (uid.isNotEmpty && deviceId != null) {
      await _auth.unregisterDevice(uid: uid, deviceId: deviceId);
    }
    await _auth.signOut();
  }

  Future<void> updateProfile({String? name, String? surname, String? phone}) =>
      _users.updateProfile(_session.uid, name: name, surname: surname, phone: phone);

  /// Profil görselini Storage'a yükleyip kullanıcı dokümanını günceller.
  Future<void> uploadAvatar(File file) async {
    final url = await _uploads.uploadProfileImage(uid: _session.uid, file: file);
    await _users.updateProfile(_session.uid, profileImageUrl: url);
    _user = await _users.getUser(_session.uid);
    notifyListeners();
  }

  /// Profil değişikliğini ve üyelik güncellemelerini tazeler.
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
        'user-disabled' => 'Bu hesap pasifleştirilmiş. Lütfen yöneticinize başvurun.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'E-posta veya şifre hatalı.',
        'email-already-in-use' => 'Bu e-posta adresi zaten kayıtlı.',
        'weak-password' => 'Şifre en az 6 karakter olmalıdır.',
        'too-many-requests' => 'Çok fazla deneme yapıldı. Biraz sonra tekrar deneyin.',
        'network-request-failed' => 'Bağlantı hatası. İnternet bağlantınızı kontrol edin.',
        _ => 'İşlem tamamlanamadı: ${error.message ?? error.code}',
      };

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
