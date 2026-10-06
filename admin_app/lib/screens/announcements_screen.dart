import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/admin_controller.dart';
import 'announcement_form_screen.dart';
import 'announcement_reads_screen.dart';

/// Duyuru yönetimi: listeleme, oluşturma, düzenleme, silme, okuma istatistiği.
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final groups = context.watch<GroupRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyurular'),
        actions: [
          IconButton(
            tooltip: 'Yeni duyuru',
            onPressed: () => _create(context),
            icon: const Icon(Icons.campaign_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<Announcement>>(
        stream: admin.watchAnnouncements(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const AppError(message: 'Duyurular yüklenemedi.');
          if (!snapshot.hasData) return const AppLoading();

          final items = snapshot.data ?? const <Announcement>[];
          if (items.isEmpty) {
            return AppEmpty(
              title: 'Henüz duyuru yok',
              description: 'Sağ üstteki düğmeden yeni duyuru oluşturun.',
              icon: Icons.campaign_outlined,
              action: FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Duyuru oluştur'),
              ),
            );
          }

          return StreamBuilder<List<AppGroup>>(
            stream: groups.watchAllGroups(),
            builder: (context, groupSnapshot) {
              final groups = groupSnapshot.data ?? const <AppGroup>[];
              final names = {for (final group in groups) group.id: group.name};

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final announcement = items[index];
                  final targetNames = announcement.targetGroupIds
                      .map((id) => names[id] ?? '?')
                      .toList()
                    ..sort();

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  announcement.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) => _onAction(context, value, announcement),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                  PopupMenuItem(value: 'reads', child: Text('Okuyanlar')),
                                  PopupMenuItem(value: 'delete', child: Text('Sil')),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            announcement.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (targetNames.isEmpty)
                                const Chip(
                                  avatar: Icon(Icons.public_rounded, size: 16),
                                  label: Text('Tüm öğrenciler'),
                                  visualDensity: VisualDensity.compact,
                                )
                              else
                                ...targetNames.map(
                                  (name) => Chip(
                                    avatar: const Icon(Icons.groups_rounded, size: 16),
                                    label: Text(name),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppDate.dateTime(announcement.publishedAt),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.visibility_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${announcement.notifiedCount} kişilik duyuru · '
                                '${announcement.readCount} okuma',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context) => AnnouncementFormScreen.open(context);

  Future<void> _onAction(BuildContext context, String action, Announcement announcement) async {
    switch (action) {
      case 'edit':
        await AnnouncementFormScreen.open(context, announcement: announcement);
      case 'reads':
        if (!context.mounted) return;
        await AnnouncementReadsScreen.open(context, announcement);
      case 'delete':
        if (!context.mounted) return;
        final confirmed = await confirmDialog(
          context,
          title: 'Duyuruyu sil',
          message: '"${announcement.title}" duyurusu kalıcı olarak silinecek.',
          confirmLabel: 'Sil',
          destructive: true,
        );
        if (!confirmed || !context.mounted) return;
        try {
          await context.read<AnnouncementRepository>().delete(announcement.id);
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Silinemedi: $error')),
          );
        }
    }
  }
}
