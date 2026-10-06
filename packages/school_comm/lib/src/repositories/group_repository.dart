import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';
import '../services/firebase_services.dart';

/// Grup yönetimi.
///
/// Üye listesi groups/{gid}/members alt-koleksiyonundan gelir; öğrenci
/// sadece aynadaki (groupIds) grupları görür.
class GroupRepository {
  GroupRepository({required FirebaseServices services})
      : _db = services.firestore,
        _auth = services.auth,
        _storage = services.storage;

  final FirebaseFirestore _db;
  final auth.FirebaseAuth _auth;
  final FirebaseStorage _storage;

  static final _functions = FirebaseFunctions.instance;

  CollectionReference<AppGroup> get _groups => _db.collection('groups').withConverter<AppGroup>(
        fromFirestore: (snap, _) => AppGroup.fromMap(snap.data() ?? const {}, snap.id),
        toFirestore: (group, _) => {
          'name': group.name,
          'description': group.description,
          'createdAt': Timestamp.fromDate(group.createdAt),
          'createdBy': group.createdBy,
          'isActive': group.isActive,
          'memberCount': group.memberCount,
        },
      );

  /// Admin: tüm gruplar (pasifler dahil), en yeni önce.
  Stream<List<AppGroup>> watchAllGroups({int limit = 200}) => _db
      .collection('groups')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).whereType<AppGroup>().toList());

  Stream<AppGroup?> watchGroup(String groupId) => _groups.doc(groupId).snapshots().map((s) => s.data());

  Future<AppGroup?> getGroup(String groupId) async => (await _groups.doc(groupId).get()).data();

  // Öğrencinin grupları: groupIds aynası dinlenir (1 okuma), üyelik
  // değişince gruplar yeniden çekilir.
  Stream<List<AppGroup>> watchMyGroups() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <AppGroup>[]);

    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .asyncExpand((snap) {
      final ids = (snap.get('groupIds') as List?)?.cast<String>() ?? const <String>[];
      return Stream<List<AppGroup>>.fromFuture(fetchGroups(ids));
    });
  }

  // in sorgusu 30 id ile sınırlı.
  Future<List<AppGroup>> fetchGroups(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final groups = <AppGroup>[];
    for (var i = 0; i < ids.length; i += 30) {
      final slice = ids.skip(i).take(30).toList();
      final snap = await _db
          .collection('groups')
          .where(FieldPath.documentId, isEqualTo: slice)
          .get();
      groups.addAll(snap.docs.map((d) => AppGroup.fromMap(d.data(), d.id)));
    }
    groups.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return groups;
  }

  Future<String> createGroup({required String name, String description = ''}) async {
    final result = await _functions.httpsCallable('createGroup').call<Map<String, dynamic>>(
      {'name': name, 'description': description},
    );
    final id = result.data['groupId'];
    if (id is! String) throw StateError('Grup oluşturulamadı.');
    return id;
  }

  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    await _functions.httpsCallable('updateGroup').call<void>({
      'groupId': groupId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isActive != null) 'isActive': isActive,
    });
  }

  /// Grup silinirken alt-koleksiyonlar ve Storage dosyaları da temizlenir.
  Future<void> deleteGroup(String groupId) async {
    await _deleteGroupFiles(groupId);
    await _functions.httpsCallable('deleteGroup').call<void>({'groupId': groupId});
  }

  Future<void> _deleteGroupFiles(String groupId) async {
    // Storage kuralları admin'e yazma izni verir; silme işlemi başarısız olursa
    // grup yine de silinir (orphan dosya temizliği sonraki bakımda yapılır).
    try {
      await _deleteRecursively(_storage.ref('groups/$groupId'), depth: 0);
    } catch (_) {
      // Dosya silinemezse sessizce geçilir.
    }
  }

  Future<void> _deleteRecursively(Reference ref, {required int depth}) async {
    if (depth > 3) return; // beklenmedik derinlikte güvenlik freni
    final list = await ref.listAll();
    for (final item in list.items) {
      await item.delete();
    }
    for (final folder in list.prefixes) {
      await _deleteRecursively(folder, depth: depth + 1);
    }
  }

  // Üyeliğin gerçek kaynağı ve ayna, sunucuda tek transaction'da.
  Future<void> addMembers(String groupId, List<String> userIds) => _membership(
        groupId: groupId,
        add: userIds,
      );

  Future<void> removeMembers(String groupId, List<String> userIds) => _membership(
        groupId: groupId,
        remove: userIds,
      );

  Future<void> _membership({
    required String groupId,
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    await _functions.httpsCallable('setGroupMembership').call<void>({
      'groupId': groupId,
      'addUserIds': add,
      'removeUserIds': remove,
    });
  }
}
