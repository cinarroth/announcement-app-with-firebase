import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:school_comm/school_comm.dart';

import 'session_controller.dart';

/// Öğrencinin kişisel veri akışları. Dinleyiciler sadece giriş yapıldığında
/// kurulur, reset()/dispose ile kapanır — Firestore okuma maliyeti burada
/// kontrol edilir.
class StudentDataController extends ChangeNotifier {
  StudentDataController({
    required FirebaseServices services,
    required SessionController session,
  })  : _session = session,
        _groups = GroupRepository(services: services),
        _announcements = AnnouncementRepository(services: services),
        _notifications = NotificationRepository(services: services) {
    _session.addListener(_onSessionChanged);
  }

  final SessionController _session;
  final GroupRepository _groups;
  final AnnouncementRepository _announcements;
  final NotificationRepository _notifications;

  StreamSubscription<List<AppGroup>>? _groupSubscription;
  List<AppGroup> _myGroups = const [];
  Set<String> _readAnnouncementIds = const {};
  bool _loading = true;
  String? _error;

  List<AppGroup> get myGroups => _myGroups;
  Set<String> get readAnnouncementIds => _readAnnouncementIds;
  bool get loading => _loading;
  String? get error => _error;

  /// Duyuru açıldığında okundu işaretlenir; sayaç anında güncellenir.
  Future<void> markAnnouncementRead(String announcementId) async {
    if (_readAnnouncementIds.contains(announcementId)) return;
    _readAnnouncementIds = {..._readAnnouncementIds, announcementId};
    notifyListeners();
    try {
      await _announcements.markAsRead(announcementId);
    } catch (_) {
      // Okundu işareti kritik değil; sessizce geçilir (sunucu sayacı zaten
      // yalnızca başarılı yazma üzerine artar).
    }
  }

  // Grup kimlikleri token claim'inden değil, otoriter aynadan (_myGroups)
  // gelir; claim bayatsa bile duyuru görünürlüğü değişmez.
  Stream<List<Announcement>> watchAnnouncements({int limit = 30}) =>
      _announcements.watchMyAnnouncements(
        groupIds: _myGroups.map((group) => group.id).toList(),
        limit: limit,
      );

  /// Bildirim gelen kutusu (kişisel bildirimler + sistem duyuruları).
  Stream<List<AppNotification>> watchNotifications() => _notifications.watchMyNotifications();

  Future<void> markNotificationRead(String id) => _notifications.markAllAsReadOrOne(id);

  Future<void> markAllNotificationsRead() => _notifications.markAllAsRead();

  /// Çıkışta tüm akışları kapatır.
  void reset() {
    _groupSubscription?.cancel();
    _groupSubscription = null;
    _myGroups = const [];
    _readAnnouncementIds = const {};
    _loading = true;
    notifyListeners();
  }

  /// Elle yenileme (pull-to-refresh): akışları yeniden kurar.
  Future<void> refresh() => _startStreams();

  Future<void> _onSessionChanged() async {
    if (!_session.isSignedIn) {
      reset();
      return;
    }
    await _startStreams();
  }

  Future<void> _startStreams() async {
    _loading = true;
    _error = null;
    notifyListeners();

    _groupSubscription?.cancel();
    _groupSubscription = _groups.watchMyGroups().listen(
      (groups) {
        _myGroups = groups;
        _loading = false;
        notifyListeners();
      },
      onError: (Object error) {
        _error = 'Gruplar yüklenemedi: $error';
        _loading = false;
        notifyListeners();
      },
    );

    try {
      _readAnnouncementIds = await _announcements.myReadAnnouncementIds();
      notifyListeners();
    } catch (_) {
      // Okundu listesi yüklenemezse duyurular yine de listelenir.
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _groupSubscription?.cancel();
    super.dispose();
  }
}
