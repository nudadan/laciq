import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

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

  appTest(
    'navbar tidak lagi punya tab Target sendiri, digantikan "Lainnya" yang '
    'membuka hub berisi semua menu yang dulunya ada di Pengaturan > Kelola',
    (tester, h) async {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Target'),
        ),
        findsNothing,
      );
      await _openMore(tester);
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Transaksi berulang'), findsOneWidget);
      expect(find.text('Tag'), findsOneWidget);
      expect(find.text('Analisa Tren'), findsOneWidget);
      expect(find.text('Laporan Bulanan'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Utang & Piutang'), findsOneWidget);
      expect(find.text('Target'), findsOneWidget);
    },
    subscription: FakeSubscriptionStatus(),
  );

  appTest('Pengaturan tidak lagi punya bagian "Kelola" — semua menunya sudah '
      'pindah ke "Lainnya"', (tester, h) async {
    await tester.tap(find.byTooltip('Pengaturan'));
    await settle(tester);
    expect(find.text('KELOLA'), findsNothing);
    expect(find.text('Kategori'), findsNothing);
    expect(find.text('Transaksi berulang'), findsNothing);
    expect(find.text('Tag'), findsNothing);
    expect(find.text('Analisa Tren'), findsNothing);
    expect(find.text('Agenda'), findsNothing);
    expect(find.text('Utang & Piutang'), findsNothing);
    // Bagian lain tetap ada (tidak ikut terhapus); label seksi huruf besar.
    expect(find.text('LANGGANAN'), findsOneWidget);
    expect(find.text('KEAMANAN'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus());

  appTest('belum premium: Kategori/Transaksi berulang/Tag selalu terjangkau, '
      'Analisa Tren & Agenda tetap terjangkau dengan batasan, Utang & '
      'Piutang menawarkan upgrade', (tester, h) async {
    await _openMore(tester);
    expect(find.textContaining('gratis 3 bulan terakhir'), findsOneWidget);
    expect(find.textContaining('gratis 3 item'), findsOneWidget);
    // Utang & Piutang dan Laporan Bulanan.
    expect(find.text('Fitur Premium'), findsNWidgets(2));

    await tester.tap(find.text('Kategori'));
    await settle(tester);
    expect(find.text('Kategori'), findsWidgets); // AppBar halaman Kategori
    await tester.tap(find.byTooltip('Kembali'));
    await settle(tester);

    await tester.tap(find.text('Transaksi berulang'));
    await settle(tester);
    expect(find.text('Transaksi Berulang'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await settle(tester);

    await tester.tap(find.text('Tag'));
    await settle(tester);
    expect(find.text('Kelola Tag'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await settle(tester);

    await tester.tap(find.text('Analisa Tren'));
    await settle(tester);
    expect(find.text('Analisa Tren'), findsWidgets); // AppBar
    expect(find.text('LaciQ Premium'), findsNothing);
    await tester.tap(find.byTooltip('Kembali'));
    await settle(tester);

    await tester.tap(find.text('Agenda'));
    await settle(tester);
    expect(find.text('Agenda'), findsWidgets); // AppBar halaman Agenda
    await tester.tap(find.byTooltip('Kembali'));
    await settle(tester);

    await tester.tap(find.text('Utang & Piutang'));
    await settle(tester);
    expect(find.text('LaciQ Premium'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus());

  appTest('premium: Target dan Utang & Piutang membuka halamannya '
      'masing-masing', (tester, h) async {
    await _openMore(tester);
    expect(find.textContaining('gratis 3 item'), findsNothing);
    expect(find.text('Fitur Premium'), findsNothing);

    await tester.tap(find.text('Target'));
    await settle(tester);
    expect(find.byTooltip('Target Baru'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await settle(tester);

    await tester.tap(find.text('Utang & Piutang'));
    await settle(tester);
    expect(find.textContaining('Belum ada utang/piutang'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));
}
