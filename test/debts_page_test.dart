import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _openDebts(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Utang & Piutang'));
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest(
    'belum premium: tile Utang & Piutang menawarkan upgrade, halaman tidak '
    'terjangkau',
    (tester, h) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Lainnya'),
        ),
      );
      await settle(tester);
      expect(find.text('Fitur Premium'), findsWidgets);

      await tester.tap(find.text('Utang & Piutang'));
      await settle(tester);

      expect(find.text('DompetKu Premium'), findsOneWidget);
      expect(find.text('Utang & Piutang'), findsNothing);
    },
    subscription: FakeSubscriptionStatus(),
  );

  appTest('premium: halaman kosong tampil ajakan tambah', (tester, h) async {
    await _openDebts(tester);
    expect(find.textContaining('Belum ada utang/piutang'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest('premium: tambah utang baru, tampil di daftar dengan sisa penuh', (
    tester,
    h,
  ) async {
    await _openDebts(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);

    expect(find.text('Utang'), findsWidgets);
    await tester.enterText(find.byType(TextField).at(0), 'Budi');
    await tester.enterText(find.byType(TextField).at(1), '500000');
    await tester.tap(find.text('Simpan'));
    await settle(tester);

    expect(find.text('Tersimpan'), findsOneWidget);
    expect(find.textContaining('Utang · Budi'), findsOneWidget);
    expect(find.textContaining('Sisa Rp 500.000'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest('premium: tambah piutang, catat pembayaran sebagian lewat menu, sisa '
      'berkurang', (tester, h) async {
    await _openDebts(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    await tester.tap(find.text('Piutang'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Sari');
    await tester.enterText(find.byType(TextField).at(1), '300000');
    await tester.tap(find.text('Simpan'));
    await settle(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('Catat pembayaran'));
    await settle(tester);

    expect(find.text('Catat Penerimaan'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      '300.000',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
      'Sari',
    );

    await tester.enterText(find.byType(TextField).at(0), '100000');
    await tester.tap(find.byType(ChoiceChip).first);
    await settle(tester);
    await tester.tap(find.text('Simpan'));
    await settle(tester);

    expect(find.text('Penerimaan dicatat'), findsOneWidget);
    final txs = await tester.runAsync(() => h.db.getTransactions());
    expect(
      (txs!.single.tx.type, txs.single.tx.amount),
      (TxType.income, 100000),
    );
    expect(find.textContaining('Sisa Rp 200.000'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest(
    'premium: pembayaran penuh menandai lunas, aksi "Catat pembayaran" hilang',
    (tester, h) async {
      await _openDebts(tester);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Budi');
      await tester.enterText(find.byType(TextField).at(1), '150000');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('Catat pembayaran'));
      await settle(tester);
      await tester.tap(find.byType(ChoiceChip).first);
      await settle(tester);
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.text('Lunas'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      expect(find.text('Catat pembayaran'), findsNothing);
      expect(find.text('Ubah'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);
    },
    subscription: FakeSubscriptionStatus(premium: true),
  );

  appTest('premium: hapus utang/piutang menghilangkannya dari daftar', (
    tester,
    h,
  ) async {
    await _openDebts(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Budi');
    await tester.enterText(find.byType(TextField).at(1), '100000');
    await tester.tap(find.text('Simpan'));
    await settle(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('Hapus'));
    await settle(tester);
    await tester.tap(find.text('Hapus').last);
    await settle(tester);

    expect(find.textContaining('Belum ada utang/piutang'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest('premium: kategori "Piutang" otomatis terpilih di form pembayaran '
      'piutang, tanpa perlu dipilih manual, supaya mudah dilacak', (
    tester,
    h,
  ) async {
    await _openDebts(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    await tester.tap(find.text('Piutang'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Sari');
    await tester.enterText(find.byType(TextField).at(1), '300000');
    await tester.tap(find.text('Simpan'));
    await settle(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('Catat pembayaran'));
    await settle(tester);

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Piutang'))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Simpan'));
    await settle(tester);

    final tx = (await tester.runAsync(() => h.db.getTransactions()))!.single;
    expect(tx.tx.categoryId, 'cat-inc-piutang');
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest('premium: kategori "Utang" otomatis terpilih di form pembayaran '
      'utang, tanpa perlu dipilih manual, supaya mudah dilacak', (
    tester,
    h,
  ) async {
    await _openDebts(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Budi');
    await tester.enterText(find.byType(TextField).at(1), '150000');
    await tester.tap(find.text('Simpan'));
    await settle(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('Catat pembayaran'));
    await settle(tester);

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Utang'))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Simpan'));
    await settle(tester);

    final tx = (await tester.runAsync(() => h.db.getTransactions()))!.single;
    expect(tx.tx.categoryId, 'cat-exp-utang');
  }, subscription: FakeSubscriptionStatus(premium: true));
}
