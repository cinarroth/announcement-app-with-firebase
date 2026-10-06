import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/session_controller.dart';
import '../state/student_data_controller.dart';
import 'announcement_detail_screen.dart';

/// Grup detayı: bilgi, mesajlar, duyurular ve üyeler.
///
/// Tüm sekmeler `groupId` ile çalışır; başka bir grubun kimliği elle girilse
/// bile Security Rules veriyi döndürmez.
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  static Future<void> open(BuildContext context, String groupId) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grup'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Bilgi'),
              Tab(text: 'Mesajlar'),
              Tab(text: 'Duyurular'),
              Tab(text: 'Üyeler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GroupInfoTab(groupId: groupId),
            _MessagesTab(groupId: groupId),
            _GroupAnnouncementsTab(groupId: groupId),
            _MembersTab(groupId: groupId),
          ],
        ),
      ),
    );
  }
}

class _GroupInfoTab extends StatelessWidget {
  const _GroupInfoTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupRepository>();

    return StreamBuilder<AppGroup?>(
      stream: groups.watchGroup(groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AppError(message: 'Grup bilgisi alınamadı.');
        }
        final group = snapshot.data;
        if (group == null) return const AppLoading();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      group.description.isEmpty ? 'Açıklama girilmemiş.' : group.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(icon: Icons.people_rounded, label: '${group.memberCount} üye'),
                    _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Oluşturulma: ${AppDate.date(group.createdAt)}',
                    ),
                    _InfoRow(
                      icon: group.isActive
                          ? Icons.check_circle_rounded
                          : Icons.pause_circle_rounded,
                      label: group.isActive ? 'Aktif grup' : 'Pasif grup',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final messages = context.watch<MessageRepository>();

    return Scaffold(
      body: StreamBuilder<List<GroupMessage>>(
        // Dinleyici yalnızca bu sekme açıkken kurulur; Firestore maliyeti düşük kalır.
        stream: messages.watchMessages(groupId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AppError(message: 'Mesajlar yüklenemedi.');
          }
          if (!snapshot.hasData) {
            return const AppLoading(label: 'Mesajlar yükleniyor…');
          }
          final items = snapshot.data ?? const <GroupMessage>[];
          if (items.isEmpty) {
            return const AppEmpty(
              title: 'Henüz mesaj yok',
              description: 'İlk mesajı siz gönderin.',
              icon: Icons.chat_bubble_outline_rounded,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final message = items[index];
              final isMine = message.isFrom(session.session.uid);
              return MessageBubble(
                message: message,
                isMine: isMine,
                onDelete: isMine ? () => _deleteMessage(context, message) : null,
              );
            },
          );
        },
      ),
      bottomNavigationBar: MessageComposer(
        groupId: groupId,
        services: context.read<FirebaseServices>(),
      ),
    );
  }

  Future<void> _deleteMessage(BuildContext context, GroupMessage message) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Mesajı sil',
      message: 'Bu mesaj kalıcı olarak silinecek.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await context.read<MessageRepository>().deleteMessage(groupId, message.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj silinemedi: $error')),
      );
    }
  }
}

class _GroupAnnouncementsTab extends StatelessWidget {
  const _GroupAnnouncementsTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentDataController>();
    final announcements = context.watch<AnnouncementRepository>();

    return StreamBuilder<List<Announcement>>(
      stream: announcements.watchGroupAnnouncements(groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AppError(message: 'Duyurular yüklenemedi.');
        if (!snapshot.hasData) return const AppLoading();

        final items = snapshot.data ?? const <Announcement>[];
        if (items.isEmpty) {
          return const AppEmpty(title: 'Bu gruba ait duyuru yok', icon: Icons.campaign_outlined);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final announcement = items[index];
            return AnnouncementCard(
              announcement: announcement,
              isUnread: !data.readAnnouncementIds.contains(announcement.id),
              onTap: () => AnnouncementDetailScreen.open(context, announcement),
            );
          },
        );
      },
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserRepository>();

    return StreamBuilder<List<GroupMember>>(
      stream: users.watchGroupMembers(groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AppError(message: 'Üye listesi alınamadı.');
        if (!snapshot.hasData) return const AppLoading();

        final members = snapshot.data ?? const <GroupMember>[];
        if (members.isEmpty) {
          return const AppEmpty(title: 'Bu grupta üye yok', icon: Icons.person_off_rounded);
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SoftDivider(),
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: AppAvatar(initials: _initials(member.displayName), radius: 18),
              title: Text(member.displayName.isEmpty ? 'İsimsiz üye' : member.displayName),
              subtitle: Text('Katılma: ${AppDate.date(member.joinedAt)}'),
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
