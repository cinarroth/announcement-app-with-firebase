import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'screens/setup_required_app.dart';
import 'state/admin_controller.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!isFirebaseConfigured) {
    runApp(const SetupRequiredApp(appName: 'admin_app'));
    return;
  }

  final services = await FirebaseServices.initialize(options: firebaseOptions);
  runApp(AdminApp(services: services));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.services});

  final FirebaseServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseServices>.value(value: services),
        Provider<AuthRepository>(create: (_) => AuthRepository(services: services)),
        Provider<UserRepository>(create: (_) => UserRepository(services: services)),
        Provider<GroupRepository>(create: (_) => GroupRepository(services: services)),
        Provider<AnnouncementRepository>(
          create: (_) => AnnouncementRepository(services: services),
        ),
        Provider<MessageRepository>(create: (_) => MessageRepository(services: services)),
        Provider<NotificationRepository>(
          create: (_) => NotificationRepository(services: services),
        ),
        Provider<UploadRepository>(create: (_) => UploadRepository(services: services)),
        ChangeNotifierProvider(
          create: (context) => SessionController(
            authRepository: context.read<AuthRepository>(),
            userRepository: context.read<UserRepository>(),
            uploadRepository: context.read<UploadRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AdminController(
            services: services,
            session: context.read<SessionController>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Yönetim Paneli',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accent: AppTheme.adminAccent),
        darkTheme: AppTheme.dark(accent: AppTheme.adminAccent),
        home: const AdminGate(),
      ),
    );
  }
}
