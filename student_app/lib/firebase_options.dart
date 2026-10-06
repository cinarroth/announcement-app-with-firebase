// Firebase yapılandırması.
//
// Bu dosya **bulun ama içeriği kasıtlı olarak boş**: gerçek API anahtarları
// kaynak koda gömülmez. Projenize ait değerleri üretmek için:
//
//   cd student_app
//   flutterfire configure --project=<PROJENİZİN-ID>   # admin_app için de tekrarlayın
//
// Komut bu dosyayı gerçek `FirebaseOptions` değerleriyle doldurur.
// Üretimde anahtarları gizlemek için `--dart-define` veya `--env-file` kullanın.

import 'package:firebase_core/firebase_core.dart';

/// Uygulama bu değerleri kullanmadan önce `flutterfire configure` çalıştırılmalıdır.
const firebaseOptions = FirebaseOptions(
  apiKey: 'DART_DEFINE_YOK',
  appId: 'DART_DEFINE_YOK',
  messagingSenderId: 'DART_DEFINE_YOK',
  projectId: 'DART_DEFINE_YOK',
  storageBucket: 'DART_DEFINE_YOK',
);

/// Gerçek yapılandırma yüklendi mi?
bool get isFirebaseConfigured =>
    firebaseOptions.apiKey != 'DART_DEFINE_YOK' && firebaseOptions.projectId != 'DART_DEFINE_YOK';
