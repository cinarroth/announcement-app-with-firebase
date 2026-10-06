import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../models/models.dart';
import '../services/firebase_services.dart';

/// Kullanıcı profili ve öğrenci yönetimi.
///
/// Rol/aktiflik/üyelik yazımları sunucuya gider; istemci bu alanlara
/// dokunamaz (kurallar da reddeder).
class UserRepository {
  UserRepository({required FirebaseServices services})
      : _db = services.firestore,
        _auth = services.auth;

  final FirebaseFirestore _db;
  final auth.FirebaseAuth _auth;

  static final _functions = FirebaseFunctions.instance;

  CollectionReference<AppUser> get _users => _db.collection('users').withConverter<AppUser>(
        fromFirestore: (snap, _) => AppUser.fromMap(snap.data() ?? const {}, snap.id),
        toFirestore: (user, _) => {
          'name': user.name,
          'surname': user.surname,
          'email': user.email,
          'role': user.role.value,
          'profileImage': user.profileImage,
          'createdAt': Timestamp.fromDate(user.createdAt),
          'isActive': user.isActive,
          'groupIds': user.groupIds,
          'unreadCount': user.unreadCount,
        },
      );

  DocumentReference<AppUser> userRef(String uid) => _users.doc(uid);

  Future<AppUser?> getUser(String uid) async => (await userRef(uid).get()).data();

  Stream<AppUser?> watchUser(String uid) => userRef(uid).snapshots().map((s) => s.data());

  /// Öğrencinin yalnızca sınırlı alanlarını günceller (kurallar da izin verir).
  Future<void> updateProfile(
    String uid, {
    String? name,
    String? surname,
    String? phone,
    String? profileImageUrl,
  }) async {
    final update = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name != null) update['name'] = name;
    if (surname != null) update['surname'] = surname;
    if (phone != null) update['phone'] = phone;
    if (profileImageUrl != null) update['profileImage'] = profileImageUrl;
    await userRef(uid).update(update);
  }

  // Öğrenci listesi; bileşik indeks firestore.indexes.json'da.
  Stream<List<AppUser>> watchStudents({int limit = 100}) => _users
      .where('role', isEqualTo: 'student')
      .orderBy('surname')
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).whereType<AppUser>().toList());

  // Firestore tam metin arama sunmaz; alan filtresi + istemci tarafı
  // eşleştirme. Ölçek büyürse Algolia/Typesense ya da bir searchKeywords
  // alanı düşünün.
  Stream<List<AppUser>> searchStudents(String term) {
    final query = term.trim().toLowerCase();
    if (query.isEmpty) return watchStudents();
    return _users
        .where('role', isEqualTo: 'student')
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => d.data())
            .whereType<AppUser>()
            .where((u) =>
                u.name.toLowerCase().contains(query) ||
                u.surname.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query))
            .toList());
  }

  // 1 okuma: aynadan grup kimlikleri.
  Future<List<String>> myGroupIds() async {
    final snap = await userRef(_auth.currentUser!.uid).get();
    return snap.data()?.groupIds ?? const <String>[];
  }

  Stream<List<GroupMember>> watchGroupMembers(String groupId) => _db
      .collection('groups')
      .doc(groupId)
      .collection('members')
      .snapshots()
      .map((snap) {
    final members = snap.docs.map((d) => GroupMember.fromMap(d.data(), d.id)).toList();
    members.sort((a, b) => a.displayName.compareTo(b.displayName));
    return members;
  });

  // Auth işlemleri istemciden yapılamaz, callable'a gider.
  Future<String> createStudent({
    required String name,
    required String surname,
    required String email,
    required String password,
  }) async {
    final result = await _functions.httpsCallable('createStudentAccount').call<Map<String, dynamic>>(
      {'name': name, 'surname': surname, 'email': email, 'password': password},
    );
    final uid = result.data['uid'];
    if (uid is! String) throw StateError('Sunucu yanıtı beklenmedik: $result');
    return uid;
  }

  Future<void> setUserRole({
    required String uid,
    required UserRole role,
    required bool isActive,
  }) async {
    await _functions.httpsCallable('setUserRole').call<void>({
      'uid': uid,
      'role': role.value,
      'isActive': isActive,
    });
  }

  /// Auth + Firestore tutarlılığını Cloud Functions sağlar.
  Future<void> deleteUser(String uid) async {
    await _functions.httpsCallable('deleteUser').call<void>({'uid': uid});
  }

  // Ayna aynı transaction'da güncellenir.
  Future<void> updateGroupMembership({
    required String groupId,
    List<String> addUserIds = const [],
    List<String> removeUserIds = const [],
  }) async {
    await _functions.httpsCallable('setGroupMembership').call<void>({
      'groupId': groupId,
      'addUserIds': addUserIds,
      'removeUserIds': removeUserIds,
    });
  }

  // Her sayaç count() agregasyonu: 1 okuma, belge okunmaz.
  Future<DashboardStats> dashboardStats() async {
    final results = await Future.wait([
      _users.where('role', isEqualTo: 'student').count().get(),
      _users
          .where('role', isEqualTo: 'student')
          .where('isActive', isEqualTo: true)
          .count()
          .get(),
      _db.collection('groups').where('isActive', isEqualTo: true).count().get(),
      _db.collection('groups').count().get(),
      _db.collection('announcements').count().get(),
    ]);
    return DashboardStats(
      totalStudents: results[0].count ?? 0,
      activeStudents: results[1].count ?? 0,
      activeGroups: results[2].count ?? 0,
      totalGroups: results[3].count ?? 0,
      totalAnnouncements: results[4].count ?? 0,
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.totalStudents,
    required this.activeStudents,
    required this.activeGroups,
    required this.totalGroups,
    required this.totalAnnouncements,
  });

  final int totalStudents;
  final int activeStudents;
  final int activeGroups;
  final int totalGroups;
  final int totalAnnouncements;
}
