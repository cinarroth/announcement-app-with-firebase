import 'package:flutter/material.dart';

import '../models/models.dart';
import 'common.dart';

/// Gruplar listesindeki kart. Öğrenci "Gruplarım" listesinde, yönetici ise
/// grup yönetimi ekranında aynı kartı kullanır.
class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.group,
    this.onTap,
    this.subtitle,
    this.trailing,
  });

  final AppGroup group;
  final VoidCallback? onTap;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AppAvatar(
                initials: group.name.isEmpty ? '?' : group.name.substring(0, 1).toUpperCase(),
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ?? '${group.memberCount} üye',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!group.isActive)
                      Text(
                        'Pasif grup',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
