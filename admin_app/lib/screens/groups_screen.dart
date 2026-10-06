import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/admin_controller.dart';
import 'group_detail_screen.dart';

/// Grup / sınıf yönetimi: oluşturma, düzenleme, silme, üye yönetimi.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruplar / Sınıflar'),
        actions: [
          IconButton(
            tooltip: 'Yeni grup',
            onPressed: () => _createGroup(context),
            icon: const Icon(Icons.create_new_folder_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<AppGroup>>(
        stream: admin.watchGroups(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const AppError(message: 'Gruplar yüklenemedi.');
          if (!snapshot.hasData) return const AppLoading();

          final groups = snapshot.data ?? const <AppGroup>[];
          if (groups.isEmpty) {
            return AppEmpty(
              title: 'Henüz grup yok',
              description: 'Sağ üstteki düğmeden yeni bir sınıf oluşturun.',
              icon: Icons.groups_outlined,
              action: FilledButton.icon(
                onPressed: () => _createGroup(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Grup oluştur'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                child: ListTile(
                  onTap: () => GroupDetailScreen.open(context, group.id),
                  leading: AppAvatar(
                    initials: group.name.isEmpty ? '?' : group.name.substring(0, 1).toUpperCase(),
                  ),
                  title: Text(group.name),
                  subtitle: Text(
                    group.description.isEmpty ? '${group.memberCount} üye' : group.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!group.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Pasif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.onErrorContainer,
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Düzenle',
                        onPressed: () => _editGroup(context, group),
                        icon: const Icon(Icons.edit_rounded, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Sil',
                        onPressed: () => _deleteGroup(context, group),
                        icon: Icon(Icons.delete_outline_rounded, size: 20, color: scheme.error),
                      ),
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

  Future<void> _createGroup(BuildContext context) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _GroupFormDialog(),
    );
    if (result == null || !context.mounted) return;

    try {
      await context.read<AdminController>().createGroup(result.$1, result.$2);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${result.$1}" grubu oluşturuldu.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grup oluşturulamadı: $error')),
      );
    }
  }

  Future<void> _editGroup(BuildContext context, AppGroup group) async {
    final admin = context.read<AdminController>();
    final active = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.name),
        content: SwitchListTile(
          value: group.isActive,
          title: const Text('Grup aktif'),
          subtitle: const Text('Pasif grup yeni duyuru hedefi olamaz'),
          onChanged: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
    if (active == null || !context.mounted) return;

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _GroupFormDialog(group: group),
    );
    if (result == null || !context.mounted) return;

    try {
      await admin.updateGroup(
        groupId: group.id,
        name: result.$1,
        description: result.$2,
        isActive: active,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellenemedi: $error')),
      );
    }
  }

  Future<void> _deleteGroup(BuildContext context, AppGroup group) async {
    if (!context.mounted) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Grubu sil',
      message: '"${group.name}" grubu, üyeleri ve mesajlarıyla birlikte silinecek. '
          'Bu işlem geri alınamaz.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await context.read<AdminController>().deleteGroup(group.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grup silindi.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $error')),
      );
    }
  }
}

class _GroupFormDialog extends StatefulWidget {
  const _GroupFormDialog({this.group});

  final AppGroup? group;

  @override
  State<_GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<_GroupFormDialog> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final _description = TextEditingController(text: widget.group?.description ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.group == null ? 'Yeni grup' : 'Grubu düzenle'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Grup adı'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Açıklama'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(context, (_name.text.trim(), _description.text.trim()));
            },
            child: Text(widget.group == null ? 'Oluştur' : 'Kaydet'),
          ),
        ],
      );
}
