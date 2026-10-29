import 'package:dompet_pintar/features/cloud_backup/cloud_backup_reminder_service.dart';
import 'package:dompet_pintar/features/cloud_backup/cloud_backup_service.dart';
import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Butuh hitung berapa kali `lastBackupAt()` dipanggil (untuk membuktikan
/// throttle jaringan) — bukan cuma nilainya, jadi bukan `FakeCloudBackupService`
/// harness biasa. Sisanya tidak dipakai layanan ini.
class _FakeCloud implements CloudBackupService {
  DateTime? backedUpAt;
  int lastBackupAtCalls = 0;

  @override
  Future<DateTime?> lastBackupAt() async {
    lastBackupAtCalls++;
    return backedUpAt;
  }

  @override
  String? get currentEmail => throw UnimplementedError();
  @override
  Future<bool> cachedSignedIn() => throw UnimplementedError();
  @override
  Stream<bool> watchSignedIn() => throw UnimplementedError();
  @override
  Future<void> signIn() => throw UnimplementedError();
  @override
  Future<void> signOut() => throw UnimplementedError();
  @override
  Future<void> uploadBackup(String plainJson) => throw UnimplementedError();
  @override
  Future<String> downloadBackup() => throw UnimplementedError();
  @override
  Future<void> uploadFile(String fileName, List<int> bytes) =>
      throw UnimplementedError();
  @override
  Future<List<int>?> downloadFile(String fileName) =>
      throw UnimplementedError();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late MemoryKeyValueStore store;
  late FakeNotificationSender sender;
  late _FakeCloud cloud;
  late CloudBackupReminderService service;
  final now = DateTime(2026, 9, 24);

  setUp(() {
    store = MemoryKeyValueStore();
    sender = FakeNotificationSender();
    cloud = _FakeCloud();
    service = CloudBackupReminderService(store, cloud, sender);
  });

  test(
    'belum pernah backup: notifikasi terkirim dengan pesan "belum pernah"',
    () async {
      await service.checkAndNotify(now: now);
      expect(sender.sent, hasLength(1));
      expect(sender.sent.single.body, contains('belum pernah'));
    },
  );

  test('backup dalam interval: tidak ada notifikasi', () async {
    cloud.backedUpAt = now.subtract(const Duration(days: 2));
    await service.checkAndNotify(now: now);
    expect(sender.sent, isEmpty);
  });

  test('backup di luar interval: notifikasi terkirim memuat tanggal', () async {
    cloud.backedUpAt = now.subtract(const Duration(days: 10));
    await service.checkAndNotify(now: now);
    expect(sender.sent, hasLength(1));
    expect(sender.sent.single.body, contains('14 Sep 2026'));
  });

  test('dipanggil dua kali di hari kalender yang sama: lastBackupAt cuma '
      'sekali (throttle jaringan)', () async {
    cloud.backedUpAt = now.subtract(const Duration(days: 10));
    await service.checkAndNotify(now: now);
    await service.checkAndNotify(now: now.add(const Duration(hours: 5)));
    expect(cloud.lastBackupAtCalls, 1);
    expect(sender.sent, hasLength(1));
  });

  test('sudah dinotifikasi: tidak diulang keesokan hari selama masih dalam '
      'interval sejak notifikasi terakhir (throttle notifikasi)', () async {
    cloud.backedUpAt = now.subtract(const Duration(days: 10));
    await service.checkAndNotify(now: now);
    expect(sender.sent, hasLength(1));

    cloud.backedUpAt = now.subtract(const Duration(days: 11)); // makin basi
    await service.checkAndNotify(now: now.add(const Duration(days: 1)));
    expect(sender.sent, hasLength(1)); // tidak nambah
  });

  test('dinonaktifkan: checkAndNotify tidak memanggil lastBackupAt sama '
      'sekali', () async {
    await service.setEnabled(false);
    cloud.backedUpAt = null;
    await service.checkAndNotify(now: now);
    expect(cloud.lastBackupAtCalls, 0);
    expect(sender.sent, isEmpty);
  });

  test('interval bulanan: backup 10 hari lalu belum dianggap basi', () async {
    await service.setIntervalDays(30);
    cloud.backedUpAt = now.subtract(const Duration(days: 10));
    await service.checkAndNotify(now: now);
    expect(sender.sent, isEmpty);
  });

  test('enabled()/intervalDays() mencerminkan setelan tersimpan', () async {
    expect(await service.enabled(), isTrue);
    expect(
      await service.intervalDays(),
      CloudBackupReminderService.defaultIntervalDays,
    );
    await service.setEnabled(false);
    await service.setIntervalDays(30);
    expect(await service.enabled(), isFalse);
    expect(await service.intervalDays(), 30);
  });

  group('pemasangan di app.dart', () {
    appTest(
      '_checkBackupReminder terpasang: notifikasi muncul saat app dibuka '
      'untuk pengguna yang sudah masuk dengan backup basi',
      (tester, h) async {
        expect(
          h.notifications.sent.any((n) => n.title == 'Waktunya backup datamu'),
          isTrue,
        );
      },
      cloudBackup: FakeCloudBackupService(
        signedIn: true,
        backupAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
    );

    appTest('_checkBackupReminder tidak mengirim apa pun untuk pengguna yang '
        'belum masuk Backup Cloud', (tester, h) async {
      expect(h.notifications.sent, isEmpty);
    }, cloudBackup: FakeCloudBackupService());
  });
}
