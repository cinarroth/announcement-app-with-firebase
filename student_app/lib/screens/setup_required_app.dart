import 'package:flutter/material.dart';

/// Firebase yapılandırılmamışsa gösterilen geliştirici ekranı.
///
/// `flutterfire configure` çalıştırılmadan uygulama bu ekranı açar; gerçek
/// Firebase kimlik bilgileri kaynak koda gömülmez.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.appName});

  /// Hangi uygulamanın yapılandırılması gerektiğini söyler (ör. `admin_app`).
  final String appName;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_ethernet_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Firebase yapılandırması eksik',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$appName dizininde şunu çalıştır:\n\n'
                    'flutterfire configure --project=<PROJE_ID>\n\n'
                    'Ardından uygulamayı yeniden başlat.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
