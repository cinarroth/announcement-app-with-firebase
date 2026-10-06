/// Duyuru / grup / öğrenci iletişim sistemi — ortak paket.
///
/// Hem yönetici hem öğrenci uygulaması bu paketi kullanır; modeller,
/// repository katmanı, tema ve ortak widget'lar tek kaynaktan gelir.
library;

export 'src/models/models.dart';
export 'src/repositories/announcement_repository.dart';
export 'src/repositories/auth_repository.dart';
export 'src/repositories/group_repository.dart';
export 'src/repositories/message_repository.dart';
export 'src/repositories/notification_repository.dart';
export 'src/repositories/upload_repository.dart';
export 'src/repositories/user_repository.dart';
export 'src/services/firebase_services.dart';
export 'src/theme/app_theme.dart';
export 'src/widgets/announcement_card.dart';
export 'src/widgets/common.dart';
export 'src/widgets/group_tile.dart';
export 'src/widgets/message_bubble.dart';
export 'src/widgets/message_composer.dart';
