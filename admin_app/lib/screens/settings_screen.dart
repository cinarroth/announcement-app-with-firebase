import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/session_controller.dart';

/// Ayarlar: hesap bilgileri, profil görseli, cihaz listesi, çıkış.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: user == null
          ? const AppLoading()
          : ListView(
              children: [
                const SectionHeader(title: 'Hesap'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: AppAvatar(
                          initials: user.initials,
                          imageUrl: user.profileImage,
                          radius: 22,
                        ),
                        title: Text(user.fullName.isEmpty ? user.email : user.fullName),
                        subtitle: Text(user.email),
                      ),
                      const SoftDivider(),
                      const ListTile(
                        leading: Icon(Icons.badge_rounded),
                        title: Text('Rol'),
                        subtitle: Text('Yönetici (custom claim)'),
                      ),
                      const SoftDivider(),
                      const ListTile(
                        leading: Icon(Icons.calendar_today_rounded),
                        title: Text('Kayıt tarihi'),
                        subtitle: Text('Hesabınız sunucu tarafından açıldı'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Profil'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _changeAvatar(context),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Profil görselini değiştir'),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Güvenlik'),
                const _SecurityNote(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: session.signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Çıkış yap'),
                  ),
                ),
                const SizedBox(height: 32),
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil görseli güncellendi.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yüklenemedi: $error')),
      );
    }
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Yetkilendirme nasıl çalışıyor?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '• Yönetici rolü Firebase Custom Claim ile taşınır ve kullanıcı '
                'dokümanıyla çapraz doğrulanır.\n'
                '• Rol, grup üyeliği ve aktiflik alanları yalnızca Cloud Functions '
                'tarafından yazılır.\n'
                '• Tüm veri erişimi Firestore Security Rules ile denetlenir.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
