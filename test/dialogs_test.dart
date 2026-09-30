import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  // Dialog yang menutup dengan animasi tetap membangun ulang TextField-nya;
  // controller yang sudah di-dispose membuat framework melempar exception,
  // yang akan menggagalkan tes ini.
  group('dialog Tambah Dompet', () {
    appTest('simpan: dompet baru muncul dengan saldo awalnya', (
      tester,
      h,
    ) async {
      await _tab(tester, 'Dompet');
      await tester.tap(find.text('Tambah Dompet'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).at(0), 'BCA');
      await tester.enterText(find.byType(TextField).at(1), '1500000');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.text('BCA'), findsOneWidget);
      expect(find.textContaining('1.500.000'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final list = (await tester.runAsync(
        () => h.db.watchAccountBalances().first,
      ))!;
      final bca = list.firstWhere((a) => a.name == 'BCA');
      expect((bca.kind, bca.balance), (AccountKind.bank, 1500000));
    });

    appTest('batal menutup dialog tanpa membuat dompet', (tester, h) async {
      await _tab(tester, 'Dompet');
      await tester.tap(find.text('Tambah Dompet'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Tidak jadi');
      await tester.tap(find.text('Batal'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Tidak jadi'), findsNothing);
    });

    appTest('nama kosong: dialog tetap terbuka dengan pesan', (
      tester,
      h,
    ) async {
      await _tab(tester, 'Dompet');
      await tester.tap(find.text('Tambah Dompet'));
      await settle(tester);
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Nama dompet wajib diisi.'), findsOneWidget);
    });
  });

  group('dialog anggaran', () {
    appTest('simpan anggaran', (tester, h) async {
      await _tab(tester, 'Anggaran');
      await tester.tap(find.text('Makanan & Minuman'));
      await settle(tester);
      expect(find.text('Anggaran Makanan & Minuman'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '500000');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('500.000'), findsWidgets);
    });

    appTest('batal', (tester, h) async {
      await _tab(tester, 'Anggaran');
      await tester.tap(find.text('Makanan & Minuman'));
      await settle(tester);
      await tester.tap(find.text('Batal'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    appTest('hapus anggaran yang ada', (tester, h) async {
      await _tab(tester, 'Anggaran');
      await tester.tap(find.text('Makanan & Minuman'));
      await settle(tester);
      expect(
        find.widgetWithText(TextField, '300.000'),
        findsOneWidget,
      ); // terisi
      await tester.tap(find.text('Hapus'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final p = (await tester.runAsync(
        () => h.db.watchBudgetProgress(DateTime.now()).first,
      ))!.firstWhere((p) => p.category.id == 'cat-exp-makan');
      expect(p.budget, isNull);
    }, seed: (db) => db.setBudget('cat-exp-makan', 300000));

    appTest('simpan tanpa nominal: dialog tetap terbuka dengan pesan', (
      tester,
      h,
    ) async {
      await _tab(tester, 'Anggaran');
      await tester.tap(find.text('Makanan & Minuman'));
      await settle(tester);
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Masukkan nominal anggaran.'), findsOneWidget);
    });
  });
}
