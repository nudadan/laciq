import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await settle(tester);
}

/// BCA (saldo awal 1.000.000) di samping Tunai bawaan.
Future<void> _seedBca(
  AppDatabase db, {
  bool withTx = false,
  bool withRule = false,
  bool archived = false,
}) async {
  await db.addAccount(
    name: 'BCA',
    kind: AccountKind.bank,
    initialBalance: 1000000,
  );
  final bca = (await db.watchAccountBalances().first).firstWhere(
    (a) => a.name == 'BCA',
  );
  if (withTx) {
    await db.addTransaction(
      type: TxType.expense,
      amount: 250000,
      accountId: bca.id,
      categoryId: 'cat-exp-makan',
      date: DateTime.now(),
    );
  }
  if (withRule) {
    await db.addRecurringRule(
      type: TxType.expense,
      amount: 10000,
      accountId: bca.id,
      categoryId: 'cat-exp-tagihan',
      frequency: Frequency.monthly,
      startDate: DateTime.now().add(const Duration(days: 30)),
    );
  }
  if (archived) await db.setAccountArchived(bca.id, archived: true);
}

Future<List<AccountBalance>> _accounts(
  WidgetTester tester,
  AppHarness h,
) async => (await tester.runAsync(
  () => h.db.watchAccountBalances(includeArchived: true).first,
))!;

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('ubah dompet', () {
    appTest('dompet bertransaksi: nama tersimpan, saldo awal terkunci', (
      tester,
      h,
    ) async {
      await _tab(tester, 'Dompet');
      await tester.tap(find.text('BCA'));
      await settle(tester);

      expect(find.text('Ubah Dompet'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        'BCA',
      );
      final balance = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(balance.controller!.text, '1.000.000');
      expect(balance.enabled, isFalse);
      expect(find.textContaining('saldo awal dikunci'), findsOneWidget);
      expect(find.textContaining('Sesuaikan saldo (kini'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'BCA Utama');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Dompet diperbarui'), findsOneWidget);
      final a = (await _accounts(
        tester,
        h,
      )).firstWhere((a) => a.name == 'BCA Utama');
      expect((a.initialBalance, a.balance), (1000000, 750000));
    }, seed: (db) => _seedBca(db, withTx: true));

    appTest('dompet tanpa transaksi: saldo awal masih bisa diubah', (
      tester,
      h,
    ) async {
      await _tab(tester, 'Dompet');
      await tester.tap(find.text('BCA'));
      await settle(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).enabled,
        isTrue,
      );
      expect(find.textContaining('Sesuaikan saldo'), findsNothing);
      await tester.enterText(find.byType(TextField).at(1), '2000000');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      final a = (await _accounts(tester, h)).firstWhere((a) => a.name == 'BCA');
      expect((a.initialBalance, a.balance), (2000000, 2000000));
    }, seed: (db) => _seedBca(db));

    appTest('Sesuaikan saldo: pratinjau selisih, lalu tercatat sebagai '
        'penyesuaian', (tester, h) async {
      await _tab(tester, 'Dompet');
      await tester.tap(find.text('BCA'));
      await settle(tester);
      await tester.tap(find.textContaining('Sesuaikan saldo (kini'));
      await settle(tester);

      expect(find.text('Sesuaikan saldo BCA'), findsOneWidget);
      // Tanpa selisih: tombol mati.
      await tester.enterText(find.byType(TextField).last, '750000');
      await tester.pump();
      expect(find.text('Sudah sama dengan saldo di aplikasi.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '800000');
      await tester.pump();
      expect(find.textContaining('pemasukan +'), findsOneWidget);
      await tester.tap(find.text('Sesuaikan'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Saldo disesuaikan menjadi'), findsOneWidget);
      final a = (await _accounts(tester, h)).firstWhere((a) => a.name == 'BCA');
      expect((a.initialBalance, a.balance), (1000000, 800000));
    }, seed: (db) => _seedBca(db, withTx: true));

    appTest(
      'nama kembar: dialog tetap terbuka dengan pesan, isian tidak hilang',
      (tester, h) async {
        await _tab(tester, 'Dompet');
        await tester.tap(find.text('BCA'));
        await settle(tester);
        await tester.enterText(find.byType(TextField).at(0), 'tunai');
        await tester.tap(find.text('Simpan'));
        await settle(tester);

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Sudah ada dompet "tunai".'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(0))
              .controller!
              .text,
          'tunai',
        );
        expect(
          (await _accounts(tester, h)).map((a) => a.name),
          contains('BCA'),
        );
      },
      seed: _seedBca,
    );

    appTest('batal tidak mengubah apa pun', (tester, h) async {
      await _tab(tester, 'Dompet');
      await tester.tap(find.text('BCA'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Tidak jadi');
      await tester.tap(find.text('Batal'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Tidak jadi'), findsNothing);
      expect(find.text('BCA'), findsOneWidget);
    }, seed: _seedBca);
  });

  group('arsip dompet', () {
    appTest(
      'konfirmasi menjelaskan dampak saldo; pindah ke Diarsipkan; keluar dari Total Saldo; bisa dipulihkan',
      (tester, h) async {
        await _tab(tester, 'Dompet');
        expect(find.text('Diarsipkan'), findsNothing);
        await tester.tap(find.text('BCA'));
        await settle(tester);
        await tester.tap(find.text('Arsipkan'));
        await settle(tester);

        // Saldo masih ada: pengguna diberi tahu bahwa Total Saldo akan berubah.
        expect(find.text('Arsipkan BCA?'), findsOneWidget);
        expect(
          find.textContaining('tidak akan dihitung di Total Saldo'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog).last,
            matching: find.textContaining('750.000'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Arsipkan'));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Dompet diarsipkan'), findsOneWidget);
        expect(find.text('Diarsipkan'), findsOneWidget);
        expect(
          (await _accounts(
            tester,
            h,
          )).firstWhere((a) => a.name == 'BCA').archived,
          isTrue,
        );

        await _tab(tester, 'Ringkasan');
        expect(find.text('1 dompet'), findsOneWidget);

        await _tab(tester, 'Dompet');
        await tester.tap(find.text('BCA'));
        await settle(tester);
        await tester.tap(find.text('Pulihkan'));
        await settle(tester);

        expect(find.text('Dompet dipulihkan'), findsOneWidget);
        expect(find.text('Diarsipkan'), findsNothing);
        await _tab(tester, 'Ringkasan');
        expect(find.text('2 dompet'), findsOneWidget);
      },
      seed: (db) => _seedBca(db, withTx: true),
    );

    appTest('dompet tanpa saldo langsung diarsipkan tanpa konfirmasi', (
      tester,
      h,
    ) async {
      await _tab(tester, 'Dompet');
      await tester.tap(find.text('Tunai').first); // nama, bukan label jenis
      await settle(tester);
      await tester.tap(find.text('Arsipkan'));
      await settle(tester);

      expect(find.textContaining('tidak akan dihitung'), findsNothing);
      expect(find.text('Dompet diarsipkan'), findsOneWidget);
    }, seed: _seedBca);

    appTest('dompet aktif terakhir tidak bisa diarsipkan', (tester, h) async {
      await _tab(tester, 'Dompet');
      await tester.tap(find.text('Tunai').first); // nama, bukan label jenis
      await settle(tester);
      await tester.tap(find.text('Arsipkan'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget); // tetap terbuka
      expect(find.text('Harus ada minimal satu dompet aktif.'), findsOneWidget);
      expect((await _accounts(tester, h)).single.archived, isFalse);
    });

    appTest(
      'dompet yang dipakai transaksi berulang aktif ditolak dengan alasannya',
      (tester, h) async {
        await _tab(tester, 'Dompet');
        await tester.tap(find.text('BCA'));
        await settle(tester);
        await tester.tap(find.text('Arsipkan'));
        await settle(tester);
        await tester.tap(
          find.widgetWithText(FilledButton, 'Arsipkan'),
        ); // konfirmasi saldo
        await settle(tester);

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.textContaining('1 transaksi berulang aktif'),
          findsOneWidget,
        );
        expect(
          (await _accounts(
            tester,
            h,
          )).firstWhere((a) => a.name == 'BCA').archived,
          isFalse,
        );
      },
      seed: (db) => _seedBca(db, withRule: true),
    );
  });

  // Mengubah transaksi lama yang dompetnya sudah diarsipkan: dropdown tidak
  // boleh berisi nilai yang tak ada di daftarnya (framework melempar assertion).
  group('dompet diarsipkan di form transaksi', () {
    appTest(
      'mengubah transaksi lama tetap bisa; dompetnya ditandai diarsipkan',
      (tester, h) async {
        await _tab(tester, 'Transaksi');
        await tester.tap(find.text('Makanan & Minuman'));
        await settle(tester);

        expect(find.text('Ubah Transaksi'), findsOneWidget);
        expect(find.text('BCA (diarsipkan)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      seed: (db) => _seedBca(db, withTx: true, archived: true),
    );

    appTest('transaksi baru tidak menawarkan dompet yang diarsipkan', (
      tester,
      h,
    ) async {
      await tester.tap(find.byTooltip('Catat'));
      await settle(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await settle(tester);

      expect(find.text('BCA'), findsNothing);
      expect(find.text('BCA (diarsipkan)'), findsNothing);
      expect(find.text('Tunai'), findsWidgets);
    }, seed: (db) => _seedBca(db, archived: true));
  });
}
