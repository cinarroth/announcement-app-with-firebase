import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/admin_controller.dart';

/// Yönetim paneli ana ekranı: sayaçlar, son duyurular, son öğrenciler.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminController>().refreshStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final stats = admin.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: admin.refreshStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: admin.refreshStats,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (admin.loadingStats && stats == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: AppLoading(label: 'İstatistikler hesaplanıyor…'),
              )
            else if (admin.error != null)
              AppError(message: admin.error!, onRetry: admin.refreshStats)
            else if (stats != null)
              _StatsGrid(stats: stats),
            const SectionHeader(title: 'Son eklenen öğrenciler'),
            _RecentStudents(),
            const SectionHeader(title: 'Son duyurular'),
            _RecentAnnouncements(),
            const SectionHeader(title: 'Gruplar'),
            _RecentGroups(),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        final spacing = (constraints.maxWidth - (columns * 150)) / (columns - 1);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: spacing < 12 ? 12 : spacing,
          childAspectRatio: 1.35,
          children: [
            StatCard(
              label: 'Toplam öğrenci',
              value: '${stats.totalStudents}',
              icon: Icons.school_rounded,
            ),
            StatCard(
              label: 'Aktif öğrenci',
              value: '${stats.activeStudents}',
              icon: Icons.verified_user_rounded,
            ),
            StatCard(
              label: 'Toplam grup',
              value: '${stats.totalGroups}',
              icon: Icons.groups_rounded,
            ),
            StatCard(
              label: 'Aktif grup',
              value: '${stats.activeGroups}',
              icon: Icons.check_circle_rounded,
            ),
            StatCard(
              label: 'Toplam duyuru',
              value: '${stats.totalAnnouncements}',
              icon: Icons.campaign_rounded,
            ),
            StatCard(
              label: 'Pasif öğrenci',
              value: '${stats.totalStudents - stats.activeStudents}',
              icon: Icons.pause_circle_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _RecentStudents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserRepository>();
    return StreamBuilder<List<AppUser>>(
      stream: users.watchStudents(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AppError(message: 'Öğrenciler alınamadı.');
        final items = snapshot.data ?? const <AppUser>[];
        if (items.isEmpty) {
          return const AppEmpty(title: 'Henüz öğrenci yok', icon: Icons.school_outlined);
        }
        return Card(
          child: Column(
            children: [
              for (final student in items)
                ListTile(
                  leading: AppAvatar(
                    initials: student.initials,
                    imageUrl: student.profileImage,
                    radius: 18,
                  ),
                  title: Text(student.fullName.isEmpty ? student.email : student.fullName),
                  subtitle: Text(student.email),
                  trailing: student.isActive
                      ? null
                      : Icon(
                          Icons.pause_circle_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentAnnouncements extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final announcements = context.watch<AnnouncementRepository>();
    return StreamBuilder<List<Announcement>>(
      stream: announcements.watchAll(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AppError(message: 'Duyurular alınamadı.');
        final items = snapshot.data ?? const <Announcement>[];
        if (items.isEmpty) {
          return const AppEmpty(title: 'Henüz duyuru yok', icon: Icons.campaign_outlined);
        }
        return Card(
          child: Column(
            children: [
              for (final announcement in items)
                ListTile(
                  leading: const Icon(Icons.campaign_rounded),
                  title: Text(
                    announcement.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${announcement.targetGroupIds.isEmpty ? 'Tüm öğrenciler' : '${announcement.targetGroupIds.length} grup'} · '
                    '${AppDate.relative(announcement.publishedAt)}',
                  ),
                  trailing: Text('${announcement.readCount} okuma'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentGroups extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupRepository>();
    return StreamBuilder<List<AppGroup>>(
      stream: groups.watchAllGroups(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AppError(message: 'Gruplar alınamadı.');
        final items = snapshot.data ?? const <AppGroup>[];
        if (items.isEmpty) {
          return const AppEmpty(title: 'Henüz grup yok', icon: Icons.groups_outlined);
        }
        return Card(
          child: Column(
            children: [
              for (final group in items)
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: Text(group.name),
                  subtitle: Text(group.description.isEmpty ? '${group.memberCount} üye' : group.description),
                  trailing: group.isActive
                      ? Chip(label: Text('${group.memberCount} üye'))
                      : Chip(
                          label: const Text('Pasif'),
                          backgroundColor: Theme.of(context).colorScheme.errorContainer,
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
