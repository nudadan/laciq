import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Pilihan "Lainnya" pada setor/tarik tabungan: sumber/tujuan dana di luar
/// dompet pengguna (transfer ke rekening orang lain, bayar tagihan, dst.).

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

Future<SavingsView> _view(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.watchSavings().first))!.single;

Future<void> _seed(AppDatabase db) async {
  await db.updateAccount(
    id: 'acc-tunai',
    name: 'Tunai',
    kind: AccountKind.cash,
    initialBalance: 1000000,
  );
}

/// Membuat tabungan "Liburan" (bersaldo [deposit] dari dompet Tunai bila > 0),
/// lalu membuka halaman detailnya.
Future<void> _openDetail(
  WidgetTester tester,
  AppDatabase db, {
  int deposit = 0,
}) async {
  final id = await tester.runAsync(
    () => db.addSavings(name: 'Liburan', icon: 'savings', color: 0xFF00897B),
  );
  if (deposit > 0) {
    await tester.runAsync(
      () => db.depositToSavings(
        savingsId: id!,
        accountId: 'acc-tunai',
        amount: deposit,
        date: DateTime.now(),
      ),
    );
  }
  await _openSavings(tester);
  await tester.tap(find.text('Liburan'));
  await settle(tester);
}

/// Memilih "Lainnya" pada pilihan dompet di dialog setor/tarik yang terbuka.
Future<void> _pickOther(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await settle(tester);
  // Item menu terakhir = yang tampil di daftar pilihan (yang pertama milik
  // tombol dropdown itu sendiri).
  await tester.tap(find.text('Lainnya').last);
  await settle(tester);
}

Future<void> _submit(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, label),
    ),
  );
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest(
    'setor dari Lainnya: saldo tabungan naik, saldo dompet tidak berubah',
    (tester, h) async {
      await _openDetail(tester, h.db);

      await tester.tap(find.text('Setor'));
      await settle(tester);
      // Bawaan: dompet pertama, dengan keterangan saldo dompetnya.
      expect(find.textContaining('Saldo dompet Rp'), findsOneWidget);

      await _pickOther(tester);
      expect(find.textContaining('Saldo dompet tidak berubah'), findsOneWidget);
      expect(find.text('Hanya menambah saldo tabungan'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '250000');
      await _submit(tester, 'Setor');

      expect(await _wallet(tester, h.db), 1000000);
      final v = await _view(tester, h.db);
      expect((v.balance, v.deposited, v.withdrawn), (250000, 250000, 0));
      expect(find.text('Setoran'), findsOneWidget);
      expect(find.textContaining('dari Lainnya'), findsOneWidget);
      // Bukan transaksi dompet.
      final txs = await tester.runAsync(() => h.db.getTransactions());
      expect(txs, isEmpty);
    },
    seed: _seed,
    subscription: FakeSubscriptionStatus(ultimate: true),
  );

  appTest(
    'tarik ke Lainnya: saldo tabungan turun, saldo dompet tidak berubah',
    (tester, h) async {
      await _openDetail(tester, h.db, deposit: 300000);
      expect(await _wallet(tester, h.db), 700000);

      await tester.tap(find.text('Tarik'));
      await settle(tester);
      await _pickOther(tester);
      expect(
        find.textContaining('transfer ke rekening orang lain'),
        findsOneWidget,
      );

      // Batas saldo tabungan tetap berlaku untuk Lainnya.
      await tester.enterText(find.byType(TextField).first, '999999');
      await _submit(tester, 'Tarik');
      expect(find.textContaining('Saldo tabungan hanya'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '120000');
      await _submit(tester, 'Tarik');

      expect(await _wallet(tester, h.db), 700000);
      final v = await _view(tester, h.db);
      expect((v.balance, v.deposited, v.withdrawn), (180000, 300000, 120000));
      expect(find.text('Penarikan'), findsOneWidget);
      expect(find.textContaining('ke Lainnya'), findsOneWidget);
    },
    seed: _seed,
    subscription: FakeSubscriptionStatus(ultimate: true),
  );

  appTest(
    'menghapus setoran Lainnya: saldo tabungan kembali, pesan tanpa saldo dompet',
    (tester, h) async {
      await _openDetail(tester, h.db);
      await tester.tap(find.text('Setor'));
      await settle(tester);
      await _pickOther(tester);
      await tester.enterText(find.byType(TextField).first, '75000');
      await _submit(tester, 'Setor');
      expect((await _view(tester, h.db)).balance, 75000);

      await tester.drag(find.text('Setoran'), const Offset(-600, 0));
      await settle(tester);

      expect((await _view(tester, h.db)).balance, 0);
      // Entri Lainnya tidak punya dompet: pesannya tidak menyebut saldo dompet.
      expect(find.text('Setoran dihapus'), findsOneWidget);
      expect(await _wallet(tester, h.db), 1000000);
    },
    seed: _seed,
    subscription: FakeSubscriptionStatus(ultimate: true),
  );
}
