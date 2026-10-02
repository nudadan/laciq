import 'dart:io';

import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/features/transactions/receipt_storage.dart';
import 'package:dompet_pintar/features/transactions/receipt_viewer_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'support/harness.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

Future<void> _seedTx(AppDatabase db, {String? receiptPath}) async {
  await db.addTransaction(
    type: TxType.expense,
    amount: 15000,
    accountId: 'acc-tunai',
    categoryId: 'cat-exp-makan',
    date: DateTime.now(),
    receiptPath: receiptPath,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  // Penampil memakai loader yang bisa diganti: tes UI tidak menyentuh file
  // sungguhan (jam palsu testWidgets tidak cocok dengan I/O file asli).
  final loadsFile = receiptFileLoaderProvider.overrideWithValue(
    (path) async => File('/tidak/dipakai.jpg'),
  );
  final loadsNothing = receiptFileLoaderProvider.overrideWithValue(
    (path) async => null,
  );

  appTest(
    'transaksi dengan foto struk menampilkan ikon, dan mengetuknya membuka '
    'penampil',
    (tester, h) async {
      await tester.tap(find.text('Transaksi').last);
      await settle(tester);

      expect(find.byTooltip('Lihat foto struk'), findsOneWidget);
      await tester.tap(find.byTooltip('Lihat foto struk'));
      await settle(tester);

      expect(find.text('Foto struk'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    },
    seed: (db) => _seedTx(db, receiptPath: 'receipts/a.jpg'),
    extraOverrides: [loadsFile],
  );

  appTest('transaksi tanpa foto struk tidak menampilkan ikon', (
    tester,
    h,
  ) async {
    await tester.tap(find.text('Transaksi').last);
    await settle(tester);

    expect(find.byTooltip('Lihat foto struk'), findsNothing);
  }, seed: (db) => _seedTx(db));

  appTest(
    'foto tidak ada di perangkat: pesan jelas, bukan layar kosong',
    (tester, h) async {
      await tester.tap(find.text('Transaksi').last);
      await settle(tester);
      await tester.tap(find.byTooltip('Lihat foto struk'));
      await settle(tester);

      expect(
        find.text('Foto struk tidak ditemukan di perangkat ini.'),
        findsOneWidget,
      );
      expect(find.byType(InteractiveViewer), findsNothing);
    },
    seed: (db) => _seedTx(db, receiptPath: 'receipts/a.jpg'),
    extraOverrides: [loadsNothing],
  );

  appTest(
    'foto struk tetap bisa dilihat walau paket Gratis',
    (tester, h) async {
      // FakeSubscriptionStatus default = Gratis.
      await tester.tap(find.text('Transaksi').last);
      await settle(tester);
      await tester.tap(find.byTooltip('Lihat foto struk'));
      await settle(tester);

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Fitur Premium'), findsNothing);
    },
    seed: (db) => _seedTx(db, receiptPath: 'receipts/a.jpg'),
    extraOverrides: [loadsFile],
  );

  appTest(
    'formulir ubah transaksi: baris Foto struk membuka penampil',
    (tester, h) async {
      await tester.tap(find.text('Transaksi').last);
      await settle(tester);
      await tester.tap(find.text('Makanan & Minuman'));
      await settle(tester);

      expect(find.text('Foto struk'), findsOneWidget);
      await tester.tap(find.text('Foto struk'));
      await settle(tester);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    },
    seed: (db) => _seedTx(db, receiptPath: 'receipts/a.jpg'),
    extraOverrides: [loadsFile],
  );

  appTest('formulir ubah transaksi tanpa foto: tidak ada baris Foto struk', (
    tester,
    h,
  ) async {
    await tester.tap(find.text('Transaksi').last);
    await settle(tester);
    await tester.tap(find.text('Makanan & Minuman'));
    await settle(tester);

    expect(find.text('Foto struk'), findsNothing);
  }, seed: (db) => _seedTx(db));

  appTest(
    'hapus foto dari formulir ubah: dikonfirmasi, kolom dikosongkan',
    (tester, h) async {
      await tester.tap(find.text('Transaksi').last);
      await settle(tester);
      await tester.tap(find.text('Makanan & Minuman'));
      await settle(tester);

      await tester.tap(find.byTooltip('Hapus foto'));
      await settle(tester);
      expect(find.text('Hapus foto struk?'), findsOneWidget);
      // Batal: tidak ada yang berubah.
      await tester.tap(find.text('Batal'));
      await settle(tester);
      expect(find.text('Foto struk'), findsOneWidget);

      await tester.tap(find.byTooltip('Hapus foto'));
      await settle(tester);
      await tester.tap(find.text('Hapus'));
      await settle(tester);

      expect(find.text('Foto struk'), findsNothing);
      final paths = await tester.runAsync(h.db.allReceiptPaths);
      expect(paths, isEmpty);
    },
    seed: (db) => _seedTx(db, receiptPath: 'receipts/a.jpg'),
    extraOverrides: [loadsFile],
  );

  group('penyimpanan foto', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dompetku_viewer_test');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('existingReceiptFile: null bila tidak ada, File bila ada', () async {
      expect(await existingReceiptFile('receipts/x.jpg'), isNull);
      await writeReceiptFile('receipts/x.jpg', [1, 2, 3]);
      expect(await existingReceiptFile('receipts/x.jpg'), isNotNull);
    });

    test(
      'deleteReceiptFile: menghapus, dan aman bila file tidak ada',
      () async {
        await writeReceiptFile('receipts/x.jpg', [1]);
        await deleteReceiptFile('receipts/x.jpg');
        expect(await existingReceiptFile('receipts/x.jpg'), isNull);
        await deleteReceiptFile('receipts/tidak-ada.jpg'); // tidak melempar
      },
    );

    test('purgeOrphanReceiptFiles: hanya foto yatim yang sudah lama', () async {
      await writeReceiptFile('receipts/dipakai.jpg', [1]);
      await writeReceiptFile('receipts/yatim-lama.jpg', [2]);
      await writeReceiptFile('receipts/yatim-baru.jpg', [3]);
      final old = DateTime.now().subtract(const Duration(days: 3));
      for (final n in ['dipakai.jpg', 'yatim-lama.jpg']) {
        await File('${tempDir.path}/receipts/$n').setLastModified(old);
      }

      final removed = await purgeOrphanReceiptFiles({'receipts/dipakai.jpg'});

      expect(removed, 1);
      expect(await existingReceiptFile('receipts/dipakai.jpg'), isNotNull);
      expect(await existingReceiptFile('receipts/yatim-lama.jpg'), isNull);
      // Foto baru bisa milik form yang belum disimpan.
      expect(await existingReceiptFile('receipts/yatim-baru.jpg'), isNotNull);
    });

    test(
      'purgeOrphanReceiptFiles: tanpa folder receipts tidak melempar',
      () async {
        expect(await purgeOrphanReceiptFiles({}), 0);
      },
    );
  });

  test('allReceiptPaths mencakup transaksi yang dihapus lunak', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.addTransaction(
      type: TxType.expense,
      amount: 1000,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-makan',
      date: DateTime.now(),
      receiptPath: 'receipts/dihapus.jpg',
    );
    await db.setTransactionDeleted(id, deleted: true);

    expect(await db.allReceiptPaths(), {'receipts/dihapus.jpg'});
  });
}
