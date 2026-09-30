import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('tanpa transaksi 6 bulan terakhir menampilkan pesan kosong', (
    tester,
    h,
  ) async {
    expect(find.text('Tren 6 Bulan'), findsOneWidget);
    expect(find.text('Belum ada transaksi 6 bulan terakhir.'), findsOneWidget);
  });

  appTest(
    'dengan transaksi menampilkan label bulan dan legenda',
    (tester, h) async {
      expect(find.text('Tren 6 Bulan'), findsOneWidget);
      expect(find.text('Belum ada transaksi 6 bulan terakhir.'), findsNothing);
      // Muncul 2x: kartu ringkasan bulan ini + legenda grafik tren.
      expect(find.text('Pemasukan'), findsNWidgets(2));
      expect(find.text('Pengeluaran'), findsNWidgets(2));
      // Label bulan pendek untuk bulan berjalan (seed ditaruh di bulan ini).
      final now = DateTime.now();
      final monthAbbr = const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ][now.month - 1];
      expect(find.text(monthAbbr), findsOneWidget);
    },
    seed: (db) async {
      final now = DateTime.now();
      await db.addTransaction(
        type: TxType.income,
        amount: 3000000,
        accountId: 'acc-tunai',
        categoryId: 'cat-inc-gaji',
        date: now,
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: 500000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: now,
      );
    },
  );
}
