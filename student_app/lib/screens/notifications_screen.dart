import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/student_data_controller.dart';
import 'announcement_detail_screen.dart';
import 'group_detail_screen.dart';

/// Bildirim sekmesi: kişisel bildirimler + sistem duyuruları bir arada.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentDataController>();
    final repository = context.watch<NotificationRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          TextButton(
            onPressed: () => repository.markAllAsRead(),
            child: const Text('Tümünü okundu işaretle'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: data.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AppError(message: 'Bildirimler yüklenemedi.');
          }
          if (!snapshot.hasData) return const AppLoading();

          final items = snapshot.data ?? const <AppNotification>[];
          if (items.isEmpty) {
            return const AppEmpty(
              title: 'Bildirim yok',
              description: 'Yeni duyuru ve mesajlar burada görünecek.',
              icon: Icons.notifications_none_rounded,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SoftDivider(),
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: ValueKey(item.id),
                direction: item.isBroadcast ? DismissDirection.none : DismissDirection.endToStart,
                onDismissed: (_) => data.markNotificationRead(item.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.isRead
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                    child: Icon(
                      _iconFor(item.type),
                      color: item.isRead
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    AppDate.relative(item.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  onTap: () => _open(context, item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'announcement' => Icons.campaign_rounded,
        'message' => Icons.chat_bubble_rounded,
        'broadcast' => Icons.campaign_rounded,
        _ => Icons.notifications_rounded,
      };

  Future<void> _open(BuildContext context, AppNotification item) async {
    await context.read<StudentDataController>().markNotificationRead(item.id);
    if (!context.mounted) return;

    if (item.groupId != null) {
      await GroupDetailScreen.open(context, item.groupId!);
      return;
    }
    if (item.announcementId != null) {
      final repository = context.read<AnnouncementRepository>();
      final announcement = await repository.getAnnouncement(item.announcementId!);
      if (!context.mounted) return;
      if (announcement == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu duyuru artık erişilebilir değil.')),
        );
        return;
      }
      await AnnouncementDetailScreen.open(context, announcement);
    }
  }
}
