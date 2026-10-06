import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/announcements_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/login_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/students_screen.dart';
import 'state/session_controller.dart';

/// Oturum durumuna göre giriş ekranı veya yönetim paneli.
class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    if (session.loading && !session.isSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!session.isSignedIn) return const AdminLoginScreen();
    if (!session.isAdmin) return const _NotAuthorized();
    return const AdminShell();
  }
}

class _NotAuthorized extends StatelessWidget {
  const _NotAuthorized();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gpp_bad_rounded, size: 52, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Yetkiniz yok', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Bu uygulamaya yalnızca yönetici hesapları erişebilir.\n'
                'Yönetici rolü sunucu tarafında atanır.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: session.signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yönetim paneli kabuğu: dar ekranda alt bar, geniş ekranda yan menü.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _destinations = <_Destination>[
    _Destination('Dashboard', Icons.dashboard_rounded, Icons.dashboard_outlined),
    _Destination('Öğrenciler', Icons.school_rounded, Icons.school_outlined),
    _Destination('Gruplar', Icons.groups_rounded, Icons.groups_outlined),
    _Destination('Duyurular', Icons.campaign_rounded, Icons.campaign_outlined),
    _Destination('Mesajlar', Icons.forum_rounded, Icons.forum_outlined),
    _Destination('Bildirimler', Icons.notifications_rounded, Icons.notifications_outlined),
    _Destination('Ayarlar', Icons.settings_rounded, Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    final body = IndexedStack(
      index: _index,
      children: const [
        DashboardScreen(),
        StudentsScreen(),
        GroupsScreen(),
        AnnouncementsScreen(),
        MessagesScreen(),
        NotificationsScreen(),
        SettingsScreen(),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Icon(Icons.admin_panel_settings_rounded, size: 28),
              ),
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final destination in _destinations.take(5))
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.selectedIcon, this.icon);

  final String label;
  final IconData selectedIcon;
  final IconData icon;
}
