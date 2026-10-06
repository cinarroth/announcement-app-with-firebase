import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/session_controller.dart';
import '../state/student_data_controller.dart';
import 'announcement_detail_screen.dart';
import 'group_detail_screen.dart';

/// Öğrenci ana sayfası: son duyurular, okunmamışlar, gruplar, bildirimler.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final data = context.watch<StudentDataController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Merhaba, ${session.user?.name.isNotEmpty == true ? session.user!.name : 'öğrenci'}'),
        actions: [
          if (session.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Badge(
                  label: Text('${session.unreadCount}'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            ),
        ],
      ),
      body: data.loading
          ? const AppLoading(label: 'Yükleniyor…')
          : RefreshIndicator(
              onRefresh: session.reload,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const SectionHeader(
                    title: 'Gruplarım',
                    subtitle: 'Üyesi olduğun sınıflar',
                  ),
                  if (data.myGroups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: AppEmpty(
                        title: 'Henüz bir gruba atanmadınız',
                        description: 'Yönetici sizi bir sınıfa eklediğinde burada görünecek.',
                        icon: Icons.groups_rounded,
                      ),
                    )
                  else
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: data.myGroups.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final group = data.myGroups[index];
                          return GroupTile(
                            group: group,
                            onTap: () => GroupDetailScreen.open(context, group.id),
                          );
                        },
                      ),
                    ),
                  const SectionHeader(title: 'Son duyurular'),
                  _AnnouncementPreview(data: data),
                ],
              ),
            ),
    );
  }
}

/// Duyuru önizlemesi: okunmamış varsa işaretli liste, aksi hâlde boş durum.
class _AnnouncementPreview extends StatelessWidget {
  const _AnnouncementPreview({required this.data});

  final StudentDataController data;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      // Akış yalnızca bu ekran açıkken kurulur; kapatılınca okuma maliyeti biter.
      stream: data.watchAnnouncements(limit: 10),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppError(message: 'Duyurular yüklenemedi.'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: AppLoading(),
          );
        }
        final announcements = snapshot.data ?? const <Announcement>[];
        if (announcements.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppEmpty(
              title: 'Duyuru yok',
              description: 'Grubunuza yeni bir duyuru gönderildiğinde burada görünecek.',
              icon: Icons.campaign_outlined,
            ),
          );
        }

        final unread = announcements
            .where((a) => !data.readAnnouncementIds.contains(a.id))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unread.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Okunmamış · ${unread.length}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ),
              ...unread.take(3).map(
                    (a) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: AnnouncementCard(
                        announcement: a,
                        isUnread: true,
                        onTap: () => AnnouncementDetailScreen.open(context, a),
                      ),
                    ),
                  ),
            ],
            ...announcements.take(5).map(
                  (a) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: AnnouncementCard(
                      announcement: a,
                      isUnread: false,
                      onTap: () => AnnouncementDetailScreen.open(context, a),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
