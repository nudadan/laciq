import 'dart:io';

import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/features/transactions/receipt_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'support/harness.dart';

Future<void> _openCloudBackupPage(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await settle(tester);
  await tester.dragUntilVisible(
    find.text('Backup cloud terenkripsi'),
    find.byType(ListView),
    const Offset(0, -300),
  );
  await settle(tester);
  await tester.tap(find.text('Backup cloud terenkripsi'));
  await settle(tester);
}

/// Mengarahkan `getApplicationDocumentsDirectory()` ke folder sementara asli
/// di mesin tes (bukan device sungguhan) — `path_provider` tidak punya
/// platform channel di `flutter test`, jadi tanpa ini `File.exists()`/
/// `writeAsBytes()` di [resolveReceiptPath]/[writeReceiptFile] akan melempar
/// `MissingPluginException`. Pola standar `path_provider_platform_interface`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dompetku_receipt_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'resolveReceiptPath menggabungkan direktori dokumen dengan path relatif',
    () async {
      final absolute = await resolveReceiptPath('receipts/abc.jpg');
      expect(absolute, '${tempDir.path}/receipts/abc.jpg');
    },
  );

  test(
    'writeReceiptFile membuat folder receipts/ dan menulis byte-nya',
    () async {
      await writeReceiptFile('receipts/abc.jpg', [1, 2, 3, 4]);
      final file = File('${tempDir.path}/receipts/abc.jpg');
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test(
    'writeReceiptFile menimpa file lama di path yang sama (idempoten)',
    () async {
      await writeReceiptFile('receipts/abc.jpg', [1, 2, 3]);
      await writeReceiptFile('receipts/abc.jpg', [9, 9]);
      final file = File('${tempDir.path}/receipts/abc.jpg');
      expect(await file.readAsBytes(), [9, 9]);
    },
  );

  group('sinkronisasi Drive lewat CloudBackupPage (unggah lalu unduh)', () {
    appTest(
      'foto struk ikut terunggah saat backup, lalu benar-benar terunduh ulang '
      'saat restore ke "perangkat lain" (file lokal lama dihapus dulu)',
      (tester, h) async {
        // Seed sudah menaruh 1 transaksi dengan receiptPath + file fisiknya
        // (lihat `seed` di bawah). Buka Backup Cloud dan tekan "Backup sekarang".
        await _openCloudBackupPage(tester);
        await tester.tap(find.text('Backup sekarang'));
        await settle(tester);

        // Foto ikut terunggah (map di FakeCloudBackupService, bukan cuma JSON).
        expect(h.cloudBackup.storedFiles.keys, contains('receipt_r1.jpg.enc'));
        expect(h.cloudBackup.storedFiles['receipt_r1.jpg.enc'], [9, 8, 7]);

        // Simulasikan "perangkat lain": file foto lokal dihapus, tapi baris DB
        // (dan karenanya `receiptPath`-nya) masih ada sampai restore mengganti
        // semuanya. Hapus filenya saja untuk membuktikan restore menulis ulang.
        // I/O sungguhan (dart:io) HARUS lewat `tester.runAsync` di sini —
        // testWidgets berjalan di zona fake-async, awaited langsung tanpa ini
        // menggantung selamanya (pola sama alasan `settle()` di harness.dart).
        final localFile = File(await resolveReceiptPath('receipts/r1.jpg'));
        await tester.runAsync(() => localFile.delete());
        expect(await tester.runAsync(() => localFile.exists()), isFalse);

        await tester.tap(find.text('Pulihkan dari cloud'));
        await settle(tester);
        // Dialog konfirmasi "Ganti data" dari confirmAndRestore.
        await tester.tap(find.text('Ganti data'));
        await settle(tester);

        expect(await tester.runAsync(() => localFile.exists()), isTrue);
        expect(await tester.runAsync(() => localFile.readAsBytes()), [9, 8, 7]);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      cloudBackup: FakeCloudBackupService(signedIn: true),
      seed: (db) async {
        // 'acc-tunai'/'cat-exp-makan': dompet & kategori bawaan dari seed
        // default (_seed() di database.dart), tidak perlu buat baru.
        await db.addTransaction(
          type: TxType.expense,
          amount: 15000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-makan',
          date: DateTime(2026, 9, 20),
          receiptPath: 'receipts/r1.jpg',
        );
        await writeReceiptFile('receipts/r1.jpg', [9, 8, 7]);
      },
    );
  });
}
