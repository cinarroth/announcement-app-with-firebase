import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/session_controller.dart';

/// Yönetici grup sohbeti: gruba mesaj gönderir (push bildirimi tetikleyicisi
/// tarafından üyelere iletilir).
class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key, required this.groupId, this.groupName});

  final String groupId;
  final String? groupName;

  static Future<void> open(BuildContext context, String groupId, {String? groupName}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(groupId: groupId, groupName: groupName),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<MessageRepository>();
    final session = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(title: Text(groupName ?? 'Grup mesajları')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<GroupMessage>>(
              stream: messages.watchMessages(groupId, limit: 100),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const AppError(message: 'Mesajlar yüklenemedi.');
                }
                if (!snapshot.hasData) return const AppLoading();
                final items = snapshot.data ?? const <GroupMessage>[];
                if (items.isEmpty) {
                  return const AppEmpty(
                    title: 'Henüz mesaj yok',
                    description: 'Gruba ilk duyuruyu gönderin.',
                    icon: Icons.forum_outlined,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final message = items[index];
                    return MessageBubble(
                      message: message,
                      isMine: message.isFrom(session.session.uid),
                    );
                  },
                );
              },
            ),
          ),
          MessageComposer(
            groupId: groupId,
            services: context.read<FirebaseServices>(),
            hint: 'Gruba duyuru gönderin…',
          ),
        ],
      ),
    );
  }
}
