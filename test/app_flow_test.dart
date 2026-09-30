import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('catat pengeluaran lalu tampil di daftar dan mengurangi saldo', (
    tester,
    h,
  ) async {
    expect(find.text('Total Saldo'), findsOneWidget);

    await tester.tap(find.byTooltip('Catat'));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, '25000');
    await tester.tap(find.text('Makanan & Minuman'));
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await settle(tester);

    await tester.tap(find.text('Transaksi').last);
    await settle(tester);
    expect(find.text('Makanan & Minuman'), findsOneWidget);
    expect(find.byType(Dismissible), findsOneWidget);

    await tester.tap(find.text('Dompet').last);
    await settle(tester);
    // Saldo Tunai jadi negatif: Rp 0 - Rp 25.000.
    expect(find.textContaining('-Rp'), findsWidgets);
    expect(find.textContaining('25.000'), findsWidgets);
  });

  appTest('validasi: simpan tanpa nominal menampilkan pesan', (
    tester,
    h,
  ) async {
    await tester.tap(find.byTooltip('Catat'));
    await settle(tester);
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Masukkan nominal lebih dari 0.'), findsOneWidget);
  });

  appTest(
    'geser hapus transaksi: SnackBar dibersihkan saat app masuk latar '
    'belakang, tidak nongkrong sampai app dibuka lagi',
    (tester, h) async {
      await tester.tap(find.text('Transaksi').last);
      await settle(tester);
      expect(find.text('Transaksi dihapus'), findsNothing);

      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await settle(tester);
      expect(find.text('Transaksi dihapus'), findsOneWidget);

      final b = tester.binding;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        b.handleAppLifecycleStateChanged(s);
      }
      await settle(tester);
      expect(find.text('Transaksi dihapus'), findsNothing);
    },
    seed: (db) => db.addTransaction(
      type: TxType.expense,
      amount: 25000,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-makan',
      date: DateTime.now(),
    ),
  );
}
