import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/admin_controller.dart';
import 'group_chat_screen.dart';

/// Grup detayı: üye listesi, üye ekleme/çıkarma, grup sohbeti.
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  static Future<void> open(BuildContext context, String groupId) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
      );

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final users = context.watch<UserRepository>();
    final groups = context.watch<GroupRepository>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grup'),
          actions: [
            IconButton(
              tooltip: 'Gruba mesaj gönder',
              onPressed: () => GroupChatScreen.open(context, groupId),
              icon: const Icon(Icons.forum_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Üyeler'),
              Tab(text: 'Öğrenciler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MembersTab(
              groupId: groupId,
              onRemove: (userId) => _removeMember(context, userId),
            ),
            _AddMembersTab(
              groupId: groupId,
              membersStream: admin.watchMembers(groupId),
              studentsStream: users.watchStudents(limit: 300),
              allGroupsStream: groups.watchAllGroups(),
              onAdd: (userId) => _addMember(context, userId),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMember(BuildContext context, String userId) async {
    try {
      await context.read<AdminController>().addMembers(groupId, [userId]);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Öğrenci gruba eklendi.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eklenemedi: $error')));
    }
  }

  Future<void> _removeMember(BuildContext context, String userId) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Gruptan çıkar',
      message: 'Öğrenci bu gruptan çıkarılacak.',
      confirmLabel: 'Çıkar',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await context.read<AdminController>().removeMembers(groupId, [userId]);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Öğrenci gruptan çıkarıldı.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Çıkarılamadı: $error')));
    }
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.groupId, required this.onRemove});

  final String groupId;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();

    return StreamBuilder<List<GroupMember>>(
      stream: admin.watchMembers(groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AppError(message: 'Üyeler alınamadı.');
        if (!snapshot.hasData) return const AppLoading();

        final members = snapshot.data ?? const <GroupMember>[];
        if (members.isEmpty) {
          return const AppEmpty(
            title: 'Bu grupta üye yok',
            description: 'Sağdaki sekmeden öğrenci ekleyin.',
            icon: Icons.person_add_alt_rounded,
          );
        }

        return ListView.separated(
          itemCount: members.length,
          separatorBuilder: (_, __) => const SoftDivider(),
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: AppAvatar(initials: _initials(member.displayName), radius: 18),
              title: Text(member.displayName.isEmpty ? 'İsimsiz üye' : member.displayName),
              subtitle: Text('Katılma: ${AppDate.date(member.joinedAt)}'),
              trailing: IconButton(
                tooltip: 'Gruptan çıkar',
                onPressed: () => onRemove(member.userId),
                icon: Icon(
                  Icons.person_remove_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class _AddMembersTab extends StatelessWidget {
  const _AddMembersTab({
    required this.groupId,
    required this.membersStream,
    required this.studentsStream,
    required this.allGroupsStream,
    required this.onAdd,
  });

  final String groupId;
  final Stream<List<GroupMember>> membersStream;
  final Stream<List<AppUser>> studentsStream;
  final Stream<List<AppGroup>> allGroupsStream;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: studentsStream,
      builder: (context, studentSnapshot) {
        if (!studentSnapshot.hasData) return const AppLoading();
        final students = studentSnapshot.data ?? const <AppUser>[];

        return StreamBuilder<List<GroupMember>>(
          stream: membersStream,
          builder: (context, memberSnapshot) {
            final memberIds =
                (memberSnapshot.data ?? const <GroupMember>[]).map((m) => m.userId).toSet();
            final candidates = students.where((s) => !memberIds.contains(s.id)).toList();

            if (candidates.isEmpty) {
              return const AppEmpty(
                title: 'Eklenecek öğrenci yok',
                description: 'Tüm öğrenciler bu grupta.',
                icon: Icons.check_circle_rounded,
              );
            }

            return ListView.separated(
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const SoftDivider(),
              itemBuilder: (context, index) {
                final student = candidates[index];
                return ListTile(
                  leading: AppAvatar(initials: student.initials, radius: 18),
                  title: Text(student.fullName.isEmpty ? student.email : student.fullName),
                  subtitle: Text(student.email),
                  trailing: IconButton.filledTonal(
                    onPressed: () => onAdd(student.id),
                    icon: const Icon(Icons.add_rounded, size: 18),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
