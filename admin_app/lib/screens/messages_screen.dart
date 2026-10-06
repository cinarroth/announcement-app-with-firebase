import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import 'group_chat_screen.dart';

/// Yönetici mesajlaşma ekranı: grup seçilir, grup sohbeti açılır.
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mesajlar')),
      body: StreamBuilder<List<AppGroup>>(
        stream: groups.watchAllGroups(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const AppError(message: 'Gruplar yüklenemedi.');
          if (!snapshot.hasData) return const AppLoading();

          final items = snapshot.data ?? const <AppGroup>[];
          if (items.isEmpty) {
            return const AppEmpty(
              title: 'Mesajlaşılacak grup yok',
              description: 'Önce bir grup oluşturun.',
              icon: Icons.forum_outlined,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final group = items[index];
              return Card(
                child: ListTile(
                  leading: AppAvatar(
                    initials: group.name.isEmpty ? '?' : group.name.substring(0, 1).toUpperCase(),
                  ),
                  title: Text(group.name),
                  subtitle: Text('${group.memberCount} üye'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => GroupChatScreen.open(context, group.id, groupName: group.name),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
