import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'screens/setup_required_app.dart';
import 'state/session_controller.dart';
import 'state/student_data_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!isFirebaseConfigured) {
    runApp(const SetupRequiredApp(appName: 'student_app'));
    return;
  }

  final services = await FirebaseServices.initialize(options: firebaseOptions);
  runApp(StudentApp(services: services));
}

class StudentApp extends StatelessWidget {
  const StudentApp({super.key, required this.services});

  final FirebaseServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repository'ler ekranlara bağımlılık olarak verilir; hiçbir ekran
        // Firebase'e doğrudan dokunmaz.
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
          create: (context) => StudentDataController(
            services: services,
            session: context.read<SessionController>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Öğrenci',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accent: AppTheme.studentAccent),
        darkTheme: AppTheme.dark(accent: AppTheme.studentAccent),
        home: const AppGate(),
      ),
    );
  }
}
