import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:school_comm/school_comm.dart';

import 'session_controller.dart';

/// Yönetim paneli verisi. Dashboard sayaçları tek seferlik count()
/// agregasyonları, listeler canlı akışlar.
class AdminController extends ChangeNotifier {
  AdminController({required FirebaseServices services, required SessionController session})
      : _session = session,
        _users = UserRepository(services: services),
        _groups = GroupRepository(services: services),
        _announcements = AnnouncementRepository(services: services) {
    _session.addListener(_onSessionChanged);
  }

  final SessionController _session;
  final UserRepository _users;
  final GroupRepository _groups;
  final AnnouncementRepository _announcements;

  DashboardStats? _stats;
  bool _loadingStats = false;
  String? _error;
  String _searchTerm = '';

  DashboardStats? get stats => _stats;
  bool get loadingStats => _loadingStats;
  String? get error => _error;
  String get searchTerm => _searchTerm;

  Stream<List<AppUser>> watchStudents() =>
      _searchTerm.isEmpty ? _users.watchStudents() : _users.searchStudents(_searchTerm);

  Stream<List<AppGroup>> watchGroups() => _groups.watchAllGroups();

  Stream<List<Announcement>> watchAnnouncements() => _announcements.watchAll();

  void setSearchTerm(String value) {
    if (_searchTerm == value) return;
    _searchTerm = value;
    notifyListeners();
  }

  Future<void> refreshStats() async {
    if (!_session.isSignedIn) return;
    _loadingStats = true;
    notifyListeners();
    try {
      _stats = await _users.dashboardStats();
      _error = null;
    } catch (error) {
      _error = 'İstatistikler alınamadı: $error';
    } finally {
      _loadingStats = false;
      notifyListeners();
    }
  }

  Future<void> createStudent({
    required String name,
    required String surname,
    required String email,
    required String password,
  }) =>
      _users.createStudent(name: name, surname: surname, email: email, password: password);

  // Öğrencinin rolünü/aktifliğini değiştirir; mevcut değerler korunur.
  Future<void> updateUser(AppUser user, {UserRole? role, bool? isActive}) => _users
      .setUserRole(uid: user.id, role: role ?? user.role, isActive: isActive ?? user.isActive);

  Future<void> deleteUser(String uid) => _users.deleteUser(uid);

  Future<String> createGroup(String name, String description) =>
      _groups.createGroup(name: name, description: description);

  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool? isActive,
  }) =>
      _groups.updateGroup(groupId: groupId, name: name, description: description, isActive: isActive);

  Future<void> deleteGroup(String groupId) => _groups.deleteGroup(groupId);

  Future<void> addMembers(String groupId, List<String> userIds) =>
      _groups.addMembers(groupId, userIds);

  Future<void> removeMembers(String groupId, List<String> userIds) =>
      _groups.removeMembers(groupId, userIds);

  Stream<List<GroupMember>> watchMembers(String groupId) =>
      _users.watchGroupMembers(groupId);

  Future<void> _onSessionChanged() async {
    if (!_session.isSignedIn) {
      _stats = null;
      return;
    }
    await refreshStats();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
