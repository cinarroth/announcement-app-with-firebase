import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/student_data_controller.dart';

/// Duyuru detayı. Ekran açılır açılmaz duyuru **okundu** işaretlenir.
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final Announcement announcement;

  static Future<void> open(BuildContext context, Announcement announcement) {
    // Okundu işareti ekran açıldığı anda yazılır.
    context.read<StudentDataController>().markAnnouncementRead(announcement.id);
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(announcement: announcement)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Duyuru')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (announcement.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                announcement.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            announcement.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: scheme.outline),
              const SizedBox(width: 4),
              Text(
                AppDate.dateTime(announcement.publishedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (announcement.expiresAt != null) ...[
                const SizedBox(width: 14),
                Icon(Icons.event_busy_rounded, size: 15, color: scheme.outline),
                const SizedBox(width: 4),
                Text(
                  'Son geçerlilik: ${AppDate.date(announcement.expiresAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                announcement.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
          ),
          if (announcement.attachments.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Ekler',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...announcement.attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AttachmentTile(attachment: attachment),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
