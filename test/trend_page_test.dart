import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
}

Future<void> _seedTwoMonths(AppDatabase db) async {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 10);
  final lastMonth = DateTime(now.year, now.month - 1, 10);
  await db.addTransaction(
    type: TxType.expense,
    amount: 100000,
    accountId: 'acc-tunai',
    categoryId: 'cat-exp-makan',
    date: lastMonth,
  );
  await db.addTransaction(
    type: TxType.expense,
    amount: 300000,
    accountId: 'acc-tunai',
    categoryId: 'cat-exp-makan',
    date: thisMonth,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('belum premium: tile Analisa Tren langsung buka TrendPage, bukan '
      'diarahkan ke upgrade', (tester, h) async {
    await _openSettings(tester);
    expect(find.textContaining('gratis 3 bulan terakhir'), findsOneWidget);

    await tester.tap(find.text('Analisa Tren'));
    await settle(tester);

    // Membuka TrendPage langsung, bukan SubscriptionPage.
    expect(find.text('Analisa Tren'), findsWidgets);
    expect(find.text('LaciQ Premium'), findsNothing);
  }, subscription: FakeSubscriptionStatus());

  appTest(
    'belum premium dengan data 2 bulan: grafik tetap tampil, jendela terkunci '
    'ke 3 bulan',
    (tester, h) async {
      await _openSettings(tester);
      await tester.tap(find.text('Analisa Tren'));
      await settle(tester);

      expect(find.text('Tren Pengeluaran per Kategori'), findsOneWidget);
      expect(find.text('Makanan & Minuman'), findsOneWidget);

      // 3 bln terpilih (bukan bawaan 6), 12 bln tetap terlihat tapi
      // menyentuhnya mengarahkan ke upsell, bukan mengubah data.
      final segmented = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(segmented.selected, {3});

      await tester.tap(find.text('12 bln'));
      await settle(tester);
      expect(find.text('LaciQ Premium'), findsOneWidget);
    },
    seed: _seedTwoMonths,
    subscription: FakeSubscriptionStatus(),
  );

  appTest('premium tanpa cukup data menampilkan pesan kosong', (
    tester,
    h,
  ) async {
    await _openSettings(tester);
    await tester.tap(find.text('Analisa Tren'));
    await settle(tester);

    expect(
      find.text(
        'Butuh minimal 2 bulan data pengeluaran '
        'untuk melihat tren.',
      ),
      findsOneWidget,
    );
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest(
    'premium dengan data 2 bulan menampilkan grafik dan insight',
    (tester, h) async {
      await _openSettings(tester);
      await tester.tap(find.text('Analisa Tren'));
      await settle(tester);

      expect(find.text('Tren Pengeluaran per Kategori'), findsOneWidget);
      expect(find.text('Makanan & Minuman'), findsOneWidget);
      expect(find.textContaining('Makanan & Minuman naik'), findsOneWidget);
    },
    seed: _seedTwoMonths,
    subscription: FakeSubscriptionStatus(premium: true),
  );
}
