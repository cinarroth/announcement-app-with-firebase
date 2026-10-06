// Firebase yapılandırması (yönetici uygulaması).
//
// Gerçek değerler kaynak koda gömülmez. Üretmek için:
//
//   cd admin_app
//   flutterfire configure --project=<PROJENİZİN-ID>

import 'package:firebase_core/firebase_core.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'DART_DEFINE_YOK',
  appId: 'DART_DEFINE_YOK',
  messagingSenderId: 'DART_DEFINE_YOK',
  projectId: 'DART_DEFINE_YOK',
  storageBucket: 'DART_DEFINE_YOK',
);

bool get isFirebaseConfigured =>
    firebaseOptions.apiKey != 'DART_DEFINE_YOK' && firebaseOptions.projectId != 'DART_DEFINE_YOK';
