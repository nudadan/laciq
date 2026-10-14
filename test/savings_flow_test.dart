import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _openSavings(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Tabungan'));
  await settle(tester);
}

Future<int> _wallet(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.watchAccountBalances().first))!
        .firstWhere((a) => a.id == 'acc-tunai')
        .balance;

Future<void> _seed(AppDatabase db) async {
  await db.updateAccount(
    id: 'acc-tunai',
    name: 'Tunai',
    kind: AccountKind.cash,
    initialBalance: 1000000,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest(
    'daftar kosong lalu membuat tabungan baru',
    (tester, h) async {
      await _openSavings(tester);
      expect(find.textContaining('Belum ada tabungan'), findsOneWidget);

      await tester.tap(find.byTooltip('Tabungan Baru'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Dana Darurat');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.text('Tabungan dibuat'), findsOneWidget);
      expect(find.text('Dana Darurat'), findsOneWidget);
      final list = (await tester.runAsync(() => h.db.watchSavings().first))!;
      expect(list.single.balance, 0);
    },
    seed: _seed,
    subscription: FakeSubscriptionStatus(ultimate: true),
  );

  appTest(
    'setor dari dompet lalu tarik kembali',
    (tester, h) async {
      await _openSavings(tester);
      await tester.tap(find.byTooltip('Tabungan Baru'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Liburan');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      await tester.tap(find.text('Liburan'));
      await settle(tester);

      // Tarik belum aktif karena saldo masih kosong.
      final withdraw = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Tarik'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(withdraw.onPressed, isNull);

      await tester.tap(find.text('Setor'));
      await settle(tester);
      expect(find.text('Setor ke Liburan'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '300000');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Setor'),
        ),
      );
      await settle(tester);

      expect(await _wallet(tester, h.db), 700000);
      expect(find.textContaining('300.000'), findsWidgets);
      expect(find.text('Setoran'), findsOneWidget);

      // Penarikan melebihi saldo ditolak di dialog.
      await tester.tap(find.text('Tarik'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '999999');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Tarik'),
        ),
      );
      await settle(tester);
      expect(find.textContaining('Saldo tabungan hanya'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '100000');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Tarik'),
        ),
      );
      await settle(tester);

      expect(await _wallet(tester, h.db), 800000);
      expect(find.text('Penarikan'), findsOneWidget);
      final v = (await tester.runAsync(() => h.db.watchSavings().first))!
          .single;
      expect((v.balance, v.deposited, v.withdrawn), (200000, 300000, 100000));
    },
    seed: _seed,
    subscription: FakeSubscriptionStatus(ultimate: true),
  );

  appTest(
    'transaksi tabungan di daftar transaksi tidak bisa diubah',
    (tester, h) async {
      final id = await tester.runAsync(
        () => h.db.addSavings(name: 'Haji', icon: 'savings', color: 0xFF00897B),
      );
      await tester.runAsync(
        () => h.db.depositToSavings(
          savingsId: id!,
          accountId: 'acc-tunai',
          amount: 150000,
          date: DateTime.now(),
        ),
      );
      await settle(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transaksi'),
        ),
      );
      await settle(tester);
      expect(find.text('Tabungan'), findsWidgets);

      // Menggeser tidak menghapus.
      await tester.drag(
        find.textContaining('Setoran ke Haji'),
        const Offset(-600, 0),
      );
      await settle(tester);
      expect(find.text('Transaksi dihapus'), findsNothing);
      expect(
        (await tester.runAsync(() => h.db.getTransactions()))!,
        hasLength(1),
      );

      // Mengetuk membuka halaman Tabungan, bukan formulir transaksi.
      await tester.tap(find.textContaining('Setoran ke Haji'));
      await settle(tester);
      expect(find.text('Saldo tabungan'), findsOneWidget);
    },
    seed: _seed,
    subscription: FakeSubscriptionStatus(ultimate: true),
  );

  group('gembok Ultimate', () {
    Future<void> openMore(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Lainnya'),
        ),
      );
      await settle(tester);
    }

    appTest('Premium tanpa tabungan: tile ditawarkan sebagai fitur Ultimate '
        'dan membuka halaman upgrade', (tester, h) async {
      await openMore(tester);
      // Tile hanya muncul bila Ultimate dijual; harness menjualnya.
      expect(find.text('Fitur Ultimate'), findsWidgets);
      await tester.tap(find.text('Tabungan'));
      await settle(tester);
      expect(find.text('Upgrade ke Ultimate'), findsOneWidget);
      expect(find.byTooltip('Tabungan Baru'), findsNothing);
    }, subscription: FakeSubscriptionStatus(premium: true));

    appTest('turun dari Ultimate: tabungan lama tetap tampil dan bisa ditarik, '
        'setor dan tabungan baru terkunci', (tester, h) async {
      final id = (await tester.runAsync(
        () => h.db.addSavings(name: 'Haji', icon: 'savings', color: 1),
      ))!;
      await tester.runAsync(
        () => h.db.depositToSavings(
          savingsId: id,
          accountId: 'acc-tunai',
          amount: 400000,
          date: DateTime.now(),
        ),
      );
      await openMore(tester);
      await tester.tap(find.text('Tabungan'));
      await settle(tester);
      expect(find.text('Haji'), findsOneWidget);
      expect(find.textContaining('fitur Ultimate'), findsOneWidget);

      // Tabungan baru -> halaman upgrade, bukan formulir.
      await tester.tap(find.byTooltip('Tabungan Baru'));
      await settle(tester);
      expect(find.text('Upgrade ke Ultimate'), findsOneWidget);
      Navigator.of(tester.element(find.text('Upgrade ke Ultimate'))).pop();
      await settle(tester);

      // Setor -> halaman upgrade; tarik tetap berfungsi.
      await tester.tap(find.text('Haji'));
      await settle(tester);
      await tester.tap(find.text('Setor'));
      await settle(tester);
      expect(find.text('Upgrade ke Ultimate'), findsOneWidget);
      Navigator.of(tester.element(find.text('Upgrade ke Ultimate'))).pop();
      await settle(tester);

      await tester.tap(find.text('Tarik'));
      await settle(tester);
      expect(find.text('Tarik dari Haji'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '150000');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Tarik'),
        ),
      );
      await settle(tester);
      final v = (await tester.runAsync(() => h.db.watchSavings().first))!
          .single;
      expect(v.balance, 250000);
    }, subscription: FakeSubscriptionStatus(premium: true));
  });
}
