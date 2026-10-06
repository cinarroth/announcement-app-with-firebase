import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Repository'lerin kullandığı Firebase istemcileri. main() içinde bir kez
/// initialize() edilir; testte fake takılabilir, hiçbir ekran
/// FirebaseAuth.instance çağırmaz.
class FirebaseServices {
  FirebaseServices({
    required this.auth,
    required this.firestore,
    required this.storage,
    required this.messaging,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final FirebaseMessaging messaging;

  static Future<FirebaseServices> initialize({FirebaseOptions? options}) async {
    if (Firebase.apps.isEmpty) {
      if (options == null) {
        throw StateError(
          'Firebase başlatılamadı: FirebaseOptions sağlanmadı. '
          '`flutterfire configure` ile firebase_options.dart üretin.',
        );
      }
      await Firebase.initializeApp(options: options);
    }
    return FirebaseServices(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
      messaging: FirebaseMessaging.instance,
    );
  }
}
