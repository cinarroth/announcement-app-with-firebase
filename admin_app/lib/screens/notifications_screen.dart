import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

/// Sistem bildirimleri (broadcast) yönetimi.
///
/// Broadcast'lar `broadcasts` koleksiyonunda tek kopya olarak tutulur; her
/// öğrenci limit'li okur. Böylece 10.000 öğrenciye 10.000 yazma yapılmaz.
/// Push dağıtımı `dispatchBroadcastPush` ile arka planda yapılır.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<NotificationRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistem Bildirimleri'),
        actions: [
          IconButton(
            tooltip: 'Yeni sistem duyurusu',
            onPressed: () => _create(context),
            icon: const Icon(Icons.campaign_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: repository.watchBroadcasts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const AppError(message: 'Bildirimler yüklenemedi.');
          if (!snapshot.hasData) return const AppLoading();

          final items = snapshot.data ?? const <AppNotification>[];
          if (items.isEmpty) {
            return AppEmpty(
              title: 'Henüz sistem duyurusu yok',
              description: 'Tüm öğrencilere iletilecek duyurular burada listelenir.',
              icon: Icons.notifications_none_rounded,
              action: FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Duyuru oluştur'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign_rounded),
                  title: Text(item.title),
                  subtitle: Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _onAction(context, value, item),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'push', child: Text('Push gönder')),
                      PopupMenuItem(value: 'toggle', child: Text('Aktif/pasif')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final repository = context.read<NotificationRepository>();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _BroadcastDialog(),
    );
    if (result == null || !context.mounted) return;

    try {
      final id = await repository.sendBroadcast(title: result.$1, content: result.$2);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sistem duyurusu oluşturuldu.')),
      );

      final sendPush = await confirmDialog(
        context,
        title: 'Push gönderilsin mi?',
        message: 'Duyuru oluşturuldu. Cihazlara anında bildirim gönderilsin mi?',
        confirmLabel: 'Gönder',
      );
      if (!sendPush || !context.mounted) return;
      await repository.dispatchBroadcastPush(id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bildirimler gönderiliyor…')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gönderilemedi: $error')),
      );
    }
  }

  Future<void> _onAction(BuildContext context, String action, AppNotification item) async {
    final repository = context.read<NotificationRepository>();
    try {
      switch (action) {
        case 'push':
          await repository.dispatchBroadcastPush(item.id);
        case 'toggle':
          await repository.setBroadcastActive(item.id, !item.isRead);
        case 'delete':
          await repository.deleteBroadcast(item.id);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $error')),
      );
    }
  }
}

class _BroadcastDialog extends StatefulWidget {
  const _BroadcastDialog();

  @override
  State<_BroadcastDialog> createState() => _BroadcastDialogState();
}

class _BroadcastDialogState extends State<_BroadcastDialog> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Sistem duyurusu'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Başlık'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Zorunludur' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _content,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'İçerik'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Zorunludur' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(context, (_title.text.trim(), _content.text.trim()));
            },
            child: const Text('Oluştur'),
          ),
        ],
      );
}
