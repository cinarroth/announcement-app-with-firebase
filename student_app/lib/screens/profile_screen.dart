import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/session_controller.dart';
import '../state/student_data_controller.dart';

/// Profil ekranı: kişisel bilgiler, profil görseli ve çıkış.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: user == null
          ? const AppLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      AppAvatar(
                        initials: user.initials,
                        imageUrl: user.profileImage,
                        radius: 44,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          onPressed: () => _changeAvatar(context),
                          icon: const Icon(Icons.photo_camera_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(child: Text(user.fullName, style: Theme.of(context).textTheme.titleLarge)),
                const SizedBox(height: 6),
                Center(child: Text(user.email, style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(height: 6),
                Center(child: RoleBadge(role: user.role)),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.groups_rounded),
                        title: Text('${user.groupIds.length} grup'),
                        subtitle: const Text('Üyesi olduğun sınıflar'),
                      ),
                      const SoftDivider(),
                      ListTile(
                        leading: const Icon(Icons.calendar_today_rounded),
                        title: Text(AppDate.date(user.createdAt)),
                        subtitle: const Text('Kayıt tarihi'),
                      ),
                      const SoftDivider(),
                      const ListTile(
                        leading: Icon(Icons.verified_user_rounded),
                        title: Text('Hesap durumu'),
                        subtitle: Text('Aktif'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _editProfile(context, user),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Bilgileri düzenle'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: session.signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Çıkış yap'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verilerin yalnızca Firebase üzerinde, yetkili olduğun gruplar '
                  'kapsamında saklanır.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }

  Future<void> _changeAvatar(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final path = files.isEmpty ? null : files.single.path;
    if (path == null || !context.mounted) return;

    try {
      await context.read<SessionController>().uploadAvatar(File(path));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil görseli güncellendi.')),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görsel yüklenemedi: $error')),
      );
    }
  }

  Future<void> _editProfile(BuildContext context, AppUser user) async {
    final name = TextEditingController(text: user.name);
    final surname = TextEditingController(text: user.surname);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bilgileri düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad')),
            const SizedBox(height: 12),
            TextField(controller: surname, decoration: const InputDecoration(labelText: 'Soyad')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet')),
        ],
      ),
    );

    if (saved != true || !context.mounted) return;

    try {
      await context
          .read<SessionController>()
          .updateProfile(name: name.text.trim(), surname: surname.text.trim());
      if (!context.mounted) return;
      await context.read<StudentDataController>().refresh();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellenemedi: $error')),
      );
    }
  }
}
