import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/session_controller.dart';

/// Oturum durumuna göre giriş ekranı veya ana kabuk arasında geçiş yapar.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    if (session.loading && !session.isSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!session.isSignedIn) return const LoginScreen();

    // Pasif hesaplar içeriğe erişemez (Security Rules da engeller); kullanıcıya
    // net bir mesaj gösterilir.
    if (!session.isActive) return const _InactiveAccountScreen();

    return const HomeShell();
  }
}

class _InactiveAccountScreen extends StatelessWidget {
  const _InactiveAccountScreen();

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
              Icon(Icons.block_rounded, size: 52, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Hesabınız pasif',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Hesabınız yönetici tarafından pasifleştirildi. '
                'Duyuru ve mesajlara erişim sağlanamıyor.',
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
