import 'dart:typed_data';

import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

class _Shared {
  final files = <({String name, Uint8List bytes, String mime})>[];
}

Override _capture(_Shared s) => binaryShareProvider.overrideWithValue(({
  required fileName,
  required bytes,
  required mimeType,
  subject,
}) async {
  s.files.add((name: fileName, bytes: bytes, mime: mimeType));
});

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.now();
  await db.addTransaction(
    type: TxType.income,
    amount: 5000000,
    accountId: 'acc-tunai',
    categoryId: 'cat-inc-gaji',
    date: DateTime(now.year, now.month, 1),
  );
  await db.addTransaction(
    type: TxType.expense,
    amount: 120000,
    accountId: 'acc-tunai',
    categoryId: 'cat-exp-makan',
    date: DateTime(now.year, now.month, 1),
    note: 'Makan siang',
  );
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await settle(tester);
}

Future<void> _openMore(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('ekspor Excel', () {
    final shared = _Shared();
    setUp(shared.files.clear);

    appTest(
      'belum Premium: membuka halaman langganan, tidak ada berkas dibagikan',
      (tester, h) async {
        await _openSettings(tester);
        expect(find.text('Ekspor laporan (Excel)'), findsOneWidget);
        expect(find.text('Fitur Premium'), findsWidgets);

        await tester.tap(find.text('Ekspor laporan (Excel)'));
        await settle(tester);

        expect(find.text('LaciQ Premium'), findsOneWidget);
        expect(find.text('Ekspor laporan Excel'), findsNothing);
        expect(shared.files, isEmpty);
      },
      seed: _seed,
      extraOverrides: [_capture(shared)],
    );

    appTest(
      'Premium: pilih rentang lalu berkas .xlsx dibagikan',
      (tester, h) async {
        await _openSettings(tester);
        await tester.tap(find.text('Ekspor laporan (Excel)'));
        await settle(tester);

        expect(find.text('Ekspor laporan Excel'), findsOneWidget);
        expect(
          find.textContaining('Berkas dibuat di perangkat ini'),
          findsOneWidget,
        );
        await tester.tap(find.text('3 bulan terakhir'));
        await settle(tester);

        expect(shared.files, hasLength(1));
        final f = shared.files.single;
        expect(
          f.name,
          matches(RegExp(r'^laciq-laporan-\d{4}-\d{2}_\d{4}-\d{2}\.xlsx$')),
        );
        expect(
          f.mime,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        expect(f.bytes.sublist(0, 2), [0x50, 0x4B]); // "PK"
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: _seed,
      extraOverrides: [_capture(shared)],
    );

    appTest(
      'Premium: batal di dialog tidak membagikan apa pun',
      (tester, h) async {
        await _openSettings(tester);
        await tester.tap(find.text('Ekspor laporan (Excel)'));
        await settle(tester);
        await tester.tapAt(const Offset(5, 5)); // tutup dialog
        await settle(tester);
        expect(shared.files, isEmpty);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: _seed,
      extraOverrides: [_capture(shared)],
    );

    appTest(
      'Premium tanpa transaksi di rentang: pesan, tidak ada berkas',
      (tester, h) async {
        await _openSettings(tester);
        await tester.tap(find.text('Ekspor laporan (Excel)'));
        await settle(tester);
        await tester.tap(find.text('Seluruh riwayat'));
        await settle(tester);

        expect(
          find.text('Tidak ada transaksi untuk diekspor.'),
          findsOneWidget,
        );
        expect(shared.files, isEmpty);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      extraOverrides: [_capture(shared)],
    );
  });

  group('Laporan Bulanan', () {
    appTest('belum Premium: tile menawarkan upgrade', (tester, h) async {
      await _openMore(tester);
      expect(find.text('Laporan Bulanan'), findsOneWidget);
      await tester.tap(find.text('Laporan Bulanan'));
      await settle(tester);
      expect(find.text('LaciQ Premium'), findsOneWidget);
    }, seed: _seed);

    appTest(
      'Premium: menampilkan angka, sorotan, dan catatan privasi',
      (tester, h) async {
        await _openMore(tester);
        await tester.tap(find.text('Laporan Bulanan'));
        await settle(tester);

        expect(find.text('Laporan Bulanan'), findsWidgets); // AppBar
        expect(find.text('Sorotan'), findsOneWidget);
        expect(find.text('Pengeluaran per kategori'), findsOneWidget);
        expect(find.text('Makanan & Minuman'), findsOneWidget);
        expect(find.byKey(const Key('report-expense')), findsOneWidget);
        expect(
          find.textContaining('Tidak ada data yang dikirim'),
          findsOneWidget,
        );
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: _seed,
    );

    appTest('Premium tanpa transaksi: keadaan kosong', (tester, h) async {
      await _openMore(tester);
      await tester.tap(find.text('Laporan Bulanan'));
      await settle(tester);
      expect(find.textContaining('Belum ada transaksi'), findsOneWidget);
      expect(find.text('Sorotan'), findsNothing);
    }, subscription: FakeSubscriptionStatus(premium: true));
  });
}
