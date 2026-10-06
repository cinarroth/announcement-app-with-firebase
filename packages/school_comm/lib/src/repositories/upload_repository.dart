import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';
import '../services/firebase_services.dart';

/// Dosya yükleme.
///
/// Buradaki boyut/tip kontrolü kullanıcıya hızlı geri bildirim içindir;
/// asıl güvenlik sınırı storage.rules.
class UploadRepository {
  UploadRepository({required FirebaseServices services}) : _storage = services.storage;

  /// Storage kurallarıyla eşleşen sınırlar (10 MB).
  static const maxFileSize = 10 * 1024 * 1024;
  static const maxImageSize = 5 * 1024 * 1024;

  static const _allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  final FirebaseStorage _storage;

  // Statik; test edilebilsin diye.
  static bool isAllowedType(String mimeType) => _allowedMimeTypes.contains(mimeType);

  // Boyut + tip denetimi. Boş dönüyorsa dosya yüklenebilir.
  static String validate(File file) {
    final mimeType = mimeTypeOf(file.path);
    if (!isAllowedType(mimeType)) {
      return 'Bu dosya türü desteklenmiyor. Görsel, PDF veya ofis dosyası seçin.';
    }
    final limit = mimeType.startsWith('image/') ? maxImageSize : maxFileSize;
    if (file.lengthSync() > limit) {
      return 'Dosya çok büyük (en fazla ${(limit / (1024 * 1024)).round()} MB).';
    }
    return '';
  }

  static String mimeTypeOf(String path) => _mimeOf(path);

  /// Duyuru görseli (yalnızca admin yükleyebilir).
  Future<Attachment> uploadAnnouncementImage({
    required String announcementId,
    required File file,
    String functionName = 'create',
  }) async {
    final error = UploadRepository.validate(file);
    if (error.isNotEmpty) throw ArgumentError(error);
    final ref = _storage.ref('announcements/$announcementId/$functionName${_ext(file.path)}');
    final task = await ref.putFile(file);
    return Attachment(
      url: await task.ref.getDownloadURL(),
      name: _baseName(file.path),
      mimeType: _mimeOf(file.path),
      size: file.lengthSync(),
    );
  }

  /// Grup mesajı eki — üye yalnızca üyesi olduğu gruba yükleyebilir.
  Future<Attachment> uploadMessageAttachment({
    required String groupId,
    required String messageId,
    required File file,
  }) async {
    final error = UploadRepository.validate(file);
    if (error.isNotEmpty) throw ArgumentError(error);
    final ref = _storage.ref(
      'groups/$groupId/messages/$messageId/attachments${_ext(file.path)}',
    );
    final task = await ref.putFile(file);
    return Attachment(
      url: await task.ref.getDownloadURL(),
      name: _baseName(file.path),
      mimeType: _mimeOf(file.path),
      size: file.lengthSync(),
    );
  }

  /// Profil fotoğrafı.
  Future<String> uploadProfileImage({required String uid, required File file}) async {
    final error = UploadRepository.validate(file);
    if (error.isNotEmpty) throw ArgumentError(error);
    if (file.lengthSync() > maxImageSize) {
      throw ArgumentError('Profil görseli en fazla 5 MB olabilir.');
    }
    final ref = _storage.ref('users/$uid/profile${_ext(file.path)}');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  static String _baseName(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? 'dosya' : parts.last;
  }

  static String _ext(String path) {
    final name = _baseName(path);
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot);
  }

  static String _mimeOf(String path) {
    final ext = _ext(path).toLowerCase();
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.heic' => 'image/heic',
      '.heif' => 'image/heif',
      '.pdf' => 'application/pdf',
      '.doc' => 'application/msword',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt' => 'application/vnd.ms-powerpoint',
      '.pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      _ => 'application/octet-stream',
    };
  }
}
