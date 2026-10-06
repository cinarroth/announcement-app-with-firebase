import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Duyuru kartı — okunmamış durumunda vurgulanır.
///
/// Her iki uygulamada da kullanılır (öğrenci ve yönetici listeleri).
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.isUnread,
    this.onTap,
    this.groupName,
  });

  final Announcement announcement;
  final bool isUnread;
  final VoidCallback? onTap;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = announcement.content.replaceAll('\n', ' ').trim();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isUnread
            ? BorderSide(color: scheme.primary.withValues(alpha: 0.45))
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: announcement.imageUrl != null
                    ? Image.network(
                        announcement.imageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbFallback(scheme),
                      )
                    : _thumbFallback(scheme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            announcement.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        UnreadDot(show: isUnread),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          AppDate.relative(announcement.publishedAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (announcement.attachments.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.attach_file_rounded, size: 14, color: scheme.outline),
                        ],
                        if (announcement.expiresAt != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.schedule_rounded, size: 14, color: scheme.outline),
                        ],
                        if (groupName != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              groupName!,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback(ColorScheme scheme) => Container(
        width: 56,
        height: 56,
        color: scheme.primary.withValues(alpha: 0.08),
        child: Icon(Icons.campaign_rounded, color: scheme.primary),
      );
}
