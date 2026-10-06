import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

/// "Duyuruyu kaç kişi okudu / kimler okudu" ekranı.
///
/// Sayı `count()` agregasyonu ile (1 okuma), liste sayfalı okunur.
/// Öğrenciler okundu bilgisini yalnızca kendi kopyasına yazar; asıl kayıtları
/// `onAnnouncementReadCreated` trigger'ı üretir.
class AnnouncementReadsScreen extends StatelessWidget {
  const AnnouncementReadsScreen({super.key, required this.announcement});

  final Announcement announcement;

  static Future<void> open(BuildContext context, Announcement announcement) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AnnouncementReadsScreen(announcement: announcement)),
      );

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AnnouncementRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Okuma istatistiği')),
      body: FutureBuilder<List<AppUser>>(
        future: repository.readerProfiles(announcement.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AppError(message: 'Okuma kayıtları alınamadı.');
          }
          if (!snapshot.hasData) return const AppLoading();

          final readers = snapshot.data ?? const <AppUser>[];

          return ListView(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              label: 'Okuyan',
                              value: '${announcement.readCount}',
                              icon: Icons.visibility_rounded,
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              label: 'Bildirilen',
                              value: '${announcement.notifiedCount}',
                              icon: Icons.notifications_active_rounded,
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              label: 'Okuma oranı',
                              value: _rate(announcement),
                              icon: Icons.percent_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SectionHeader(title: 'Okuyan öğrenciler'),
              if (readers.isEmpty)
                const AppEmpty(
                  title: 'Henüz kimse okumadı',
                  description: 'Öğrenciler duyuruyu açtığında liste güncellenir.',
                  icon: Icons.visibility_off_rounded,
                )
              else
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      for (final reader in readers)
                        ListTile(
                          leading: AppAvatar(
                            initials: reader.initials,
                            imageUrl: reader.profileImage,
                            radius: 18,
                          ),
                          title: Text(
                            reader.fullName.isEmpty ? reader.email : reader.fullName,
                          ),
                          subtitle: Text(reader.email),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _rate(Announcement announcement) {
    if (announcement.notifiedCount == 0) return '-';
    return '${(announcement.readCount * 100 / announcement.notifiedCount).round()}%';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
