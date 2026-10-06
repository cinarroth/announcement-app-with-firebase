import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/student_data_controller.dart';
import 'announcement_detail_screen.dart';

/// Öğrencinin görebileceği tüm duyurular (gruba göre birleştirilmiş akış).
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _onlyUnread = false;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentDataController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyurular'),
        actions: [
          IconButton(
            tooltip: _onlyUnread ? 'Tümünü göster' : 'Sadece okunmamışlar',
            onPressed: () => setState(() => _onlyUnread = !_onlyUnread),
            icon: Icon(_onlyUnread ? Icons.filter_alt_rounded : Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<Announcement>>(
        stream: data.watchAnnouncements(limit: 50),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AppError(message: 'Duyurular yüklenemedi.');
          }
          if (!snapshot.hasData) return const AppLoading();

          final all = snapshot.data ?? const <Announcement>[];
          final items = _onlyUnread
              ? all.where((a) => !data.readAnnouncementIds.contains(a.id)).toList()
              : all;

          if (items.isEmpty) {
            return AppEmpty(
              title: _onlyUnread ? 'Okunmamış duyuru yok' : 'Duyuru bulunmuyor',
              description: _onlyUnread
                  ? 'Tüm duyuruları okudunuz.'
                  : 'Grubunuza yeni bir duyuru gönderildiğinde burada görünecek.',
              icon: _onlyUnread ? Icons.done_all_rounded : Icons.campaign_outlined,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final announcement = items[index];
              return AnnouncementCard(
                announcement: announcement,
                isUnread: !data.readAnnouncementIds.contains(announcement.id),
                onTap: () => AnnouncementDetailScreen.open(context, announcement),
              );
            },
          );
        },
      ),
    );
  }
}
