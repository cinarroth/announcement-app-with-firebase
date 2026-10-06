import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_comm/school_comm.dart';

/// Modeller saf Dart sınıflarıdır; Firebase bağımlılığı olmadan test edilir.
void main() {
  group('AppUser', () {
    test('eksik alanlarla güvenli varsayılan üretir', () {
      final user = AppUser.fromMap(const {}, 'u1');

      expect(user.id, 'u1');
      expect(user.role, UserRole.student);
      expect(user.isActive, isFalse);
      expect(user.groupIds, isEmpty);
      expect(user.unreadCount, 0);
      expect(user.initials, '?');
    });

    test('ad ve soyad birleşir, baş harfler üretilir', () {
      final user = AppUser.fromMap(const {
        'name': 'Ali',
        'surname': 'Yılmaz',
        'role': 'admin',
        'isActive': true,
      }, 'u1');

      expect(user.fullName, 'Ali Yılmaz');
      expect(user.initials, 'AY');
      expect(user.isAdmin, isTrue);
      expect(user.role, UserRole.admin);
    });

    test('rol değeri tanınmıyorsa öğrenci kabul edilir', () {
      expect(AppUser.fromMap(const {'role': 'superadmin'}, 'u1').role, UserRole.student);
      expect(AppUser.fromMap(const {'role': null}, 'u1').role, UserRole.student);
    });

    test('grup listesi varsayılan olarak boş küçük listedir', () {
      expect(AppUser.fromMap(const {}, 'u1').groupIds, isA<List<String>>());
    });
  });

  group('Announcement', () {
    final base = {
      'title': 'Sınav',
      'content': 'Sınav tarihi',
      'createdBy': 'admin',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'publishedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    };

    test('süresi geçmemiş duyuru yayındadır', () {
      final announcement = Announcement.fromMap(base, 'a1');
      final now = DateTime(2026, 1, 5);

      expect(announcement.isPublishedAt(now), isTrue);
      expect(announcement.isExpiredAt(now), isFalse);
    });

    test('son geçerlilik tarihi geçmişse süresi dolmuş sayılır', () {
      final announcement = Announcement.fromMap(
        {...base, 'expiresAt': Timestamp.fromDate(DateTime(2026, 1, 3))},
        'a1',
      );

      expect(announcement.isExpiredAt(DateTime(2026, 1, 5)), isTrue);
      expect(announcement.isExpiredAt(DateTime(2026, 1, 2)), isFalse);
    });

    test('gelecek yayın tarihi henüz yayında değildir', () {
      final announcement = Announcement.fromMap(
        {...base, 'publishedAt': Timestamp.fromDate(DateTime(2026, 2, 1))},
        'a1',
      );

      expect(announcement.isPublishedAt(DateTime(2026, 1, 5)), isFalse);
    });

    test('ekler okunur, okunmamış alanlar boş listeye düşer', () {
      final announcement = Announcement.fromMap({
        ...base,
        'attachments': [
          {'url': 'https://x/a.png', 'name': 'a.png', 'mimeType': 'image/png', 'size': 1024},
        ],
      }, 'a1');

      expect(announcement.attachments, hasLength(1));
      expect(announcement.attachments.first.isImage, isTrue);
      expect(announcement.targetGroupIds, isEmpty);
      expect(announcement.readCount, 0);
    });

    test('son geçerlilik verilmemişse süresizdir', () {
      expect(Announcement.fromMap(base, 'a1').expiresAt, isNull);
    });
  });

  group('GroupMessage', () {
    test('mesaj türü varsayılan olarak metindir', () {
      final message = GroupMessage.fromMap(const {
        'senderId': 'u1',
        'content': 'merhaba',
      }, 'm1', 'g1');

      expect(message.type, MessageType.text);
      expect(message.groupId, 'g1');
      expect(message.isFrom('u1'), isTrue);
      expect(message.isFrom('u2'), isFalse);
    });

    test('dosya mesajı türü çözümlenir', () {
      final message = GroupMessage.fromMap(const {
        'senderId': 'u1',
        'content': '',
        'type': 'file',
        'attachments': [
          {'url': 'https://x/a.pdf', 'name': 'a.pdf', 'mimeType': 'application/pdf', 'size': 2048},
        ],
      }, 'm1', 'g1');

      expect(message.type, MessageType.file);
      expect(message.attachments.first.isImage, isFalse);
    });
  });

  group('Attachment', () {
    test('boyut okunabilir ve alanlar korunur', () {
      final attachment = Attachment.fromMap(const {
        'url': 'https://x/f.png',
        'name': 'f.png',
        'mimeType': 'image/png',
        'size': 2048,
      });

      expect(attachment.toMap()['url'], 'https://x/f.png');
      expect(attachment.size, 2048);
    });
  });

  group('AppGroup', () {
    test('grup varsayılanları', () {
      final group = AppGroup.fromMap(const {'name': '5-A'}, 'g1');

      expect(group.name, '5-A');
      expect(group.memberCount, 0);
      expect(group.isActive, isTrue);
    });
  });

  group('AppDate', () {
    test('göreli zaman', () {
      final now = DateTime(2026, 1, 10, 12);
      expect(AppDate.relative(now.subtract(const Duration(seconds: 10)), now: now), 'az önce');
      expect(AppDate.relative(now.subtract(const Duration(minutes: 5)), now: now), '5 dk önce');
      expect(AppDate.relative(now.subtract(const Duration(hours: 3)), now: now), '3 saat önce');
      expect(AppDate.relative(now.subtract(const Duration(days: 1)), now: now), 'dün');
      expect(AppDate.relative(now.subtract(const Duration(days: 3)), now: now), '3 gün önce');
    });

    test('tarih ve dosya boyutu biçimlendirme', () {
      expect(AppDate.date(DateTime(2026, 1, 5)), '5 Oca 2026');
      expect(AppDate.time(DateTime(2026, 1, 5, 9, 3)), '09:03');
      expect(AppDate.fileSize(512), '512 B');
      expect(AppDate.fileSize(2048), '2 KB');
      expect(AppDate.fileSize(3 * 1024 * 1024), '3.0 MB');
    });
  });

  group('UploadRepository doğrulaması', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('school_comm_upload_test');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    File write(String name, int bytes) =>
        File('${tempDir.path}${Platform.pathSeparator}$name')..writeAsBytesSync(List.filled(bytes, 0));

    test('izin verilen görsel tipi kabul edilir', () {
      expect(UploadRepository.validate(write('foto.png', 1024)), isEmpty);
      expect(UploadRepository.isAllowedType('image/png'), isTrue);
      expect(UploadRepository.isAllowedType('application/pdf'), isTrue);
    });

    test('izin verilmeyen dosya tipi reddedilir', () {
      expect(UploadRepository.validate(write('zararli.exe', 10)), isNotEmpty);
      expect(UploadRepository.isAllowedType('application/x-msdownload'), isFalse);
    });

    test('5 MB üzeri görsel reddedilir', () {
      final tooBig = write('buyuk.jpg', 5 * 1024 * 1024 + 1);
      expect(UploadRepository.validate(tooBig), contains('5 MB'));
    });

    test('10 MB üzeri belge reddedilir', () {
      final tooBig = write('belge.pdf', 10 * 1024 * 1024 + 1);
      expect(UploadRepository.validate(tooBig), contains('10 MB'));
    });

    test('bilinmeyen uzantı reddedilir', () {
      expect(UploadRepository.validate(write('arsiv.zip', 10)), isNotEmpty);
    });

    test('MIME tipi uzantıdan türetilir', () {
      expect(UploadRepository.mimeTypeOf('a/b/c.JPEG'), 'image/jpeg');
      expect(UploadRepository.mimeTypeOf('rapor.docx'), contains('officedocument'));
      expect(UploadRepository.mimeTypeOf('sunum.pptx'), contains('presentationml'));
      expect(UploadRepository.mimeTypeOf('veri.xlsx'), contains('spreadsheetml'));
      expect(UploadRepository.mimeTypeOf('bilinmeyen.xyz'), 'application/octet-stream');
    });
  });
}
