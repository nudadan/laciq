import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _addCoffee(AppDatabase db) => db.addTransaction(
  type: TxType.expense,
  amount: 25000,
  accountId: 'acc-tunai',
  categoryId: 'cat-exp-makan',
  date: DateTime.now(),
  note: 'kopi',
);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await settle(tester);
}

Future<void> _openRecurringPage(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Transaksi berulang'));
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('ubah transaksi', () {
    appTest('ketuk transaksi, ubah nominal dan kategori, tersimpan', (
      tester,
      h,
    ) async {
      await _openTab(tester, 'Transaksi');
      await tester.tap(find.text('Makanan & Minuman'));
      await settle(tester);

      expect(find.text('Ubah Transaksi'), findsOneWidget);
      // Form terisi dengan data yang ada.
      expect(find.text('25.000'), findsOneWidget);
      expect(find.text('kopi'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '40000');
      await tester.tap(find.text('Transportasi'));
      await tester.pump();
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.text('Perubahan disimpan'), findsOneWidget);
      expect(find.text('Transportasi'), findsOneWidget);
      expect(find.text('Makanan & Minuman'), findsNothing);
      final tx = (await tester.runAsync(() => h.db.getTransactions()))!
          .single
          .tx;
      expect(tx.amount, 40000);
      expect(tx.categoryId, 'cat-exp-transport');
      expect(tx.note, 'kopi'); // tidak ikut berubah
    }, seed: _addCoffee);

    appTest('validasi tetap berlaku saat mengubah', (tester, h) async {
      await _openTab(tester, 'Transaksi');
      await tester.tap(find.text('Makanan & Minuman'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      expect(find.text('Masukkan nominal lebih dari 0.'), findsOneWidget);
      expect(find.text('Ubah Transaksi'), findsOneWidget); // masih di form
    }, seed: _addCoffee);

    appTest(
      'transaksi dari aturan berulang ditandai dan diberi penjelasan',
      (tester, h) async {
        await _openTab(tester, 'Transaksi');
        expect(find.byIcon(Icons.repeat), findsOneWidget);

        await tester.tap(find.text('Tagihan & Utilitas'));
        await settle(tester);
        expect(
          find.textContaining('dibuat otomatis dari transaksi berulang'),
          findsOneWidget,
        );
      },
      seed: (db) async {
        await db.addRecurringRule(
          type: TxType.expense,
          amount: 100000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-tagihan',
          frequency: Frequency.monthly,
          startDate: DateTime.now(),
        );
      },
    );
  });

  group('transaksi berulang', () {
    appTest(
      'membuat dari form: aturan tersimpan dan kejadian hari ini dicatat',
      (tester, h) async {
        await tester.tap(find.byTooltip('Catat'));
        await settle(tester);

        await tester.enterText(find.byType(TextField).first, '100000');
        await tester.tap(find.text('Tagihan & Utilitas'));
        await tester.pump();
        await tester.tap(find.text('Tidak berulang'));
        await settle(tester);
        await tester.tap(find.text('Bulanan').last);
        await settle(tester);
        expect(find.text('Tanggal mulai'), findsOneWidget);
        expect(find.text('Tanpa tanggal berakhir'), findsOneWidget);

        await tester.tap(find.text('Simpan'));
        await settle(tester);

        expect(find.text('Transaksi berulang dibuat'), findsOneWidget);
        final rules = await tester.runAsync(
          () => h.db.watchRecurringRules().first,
        );
        expect(rules, hasLength(1));
        expect(rules!.single.rule.frequency, Frequency.monthly);
        final txs = await tester.runAsync(() => h.db.getTransactions());
        expect(txs, hasLength(1)); // mulai hari ini => langsung tercatat
        expect(txs!.single.tx.recurringId, rules.single.rule.id);
      },
    );

    appTest(
      'mengubah aturan: form terisi, jadwal read-only, bisa disimpan',
      (tester, h) async {
        await _openRecurringPage(tester);
        await tester.tap(find.text('Tagihan & Utilitas'));
        await settle(tester);
        expect(find.text('Ubah Transaksi Berulang'), findsOneWidget);
        expect(
          find.textContaining('Perubahan berlaku mulai transaksi berikutnya'),
          findsOneWidget,
        );
        await tester.tap(find.text('Simpan'));
        await settle(tester);
        expect(find.text('Perubahan disimpan'), findsOneWidget);
      },
      seed: (db) async {
        await db.addRecurringRule(
          type: TxType.expense,
          amount: 100000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-tagihan',
          frequency: Frequency.monthly,
          startDate: DateTime(2030, 1, 15),
        );
      },
    );

    appTest(
      'daftar menampilkan jadwal; jeda, lanjutkan, lalu hapus',
      (tester, h) async {
        await _openRecurringPage(tester);
        expect(find.text('Tagihan & Utilitas · Sewa'), findsOneWidget);
        expect(find.textContaining('Setiap bulan, tanggal 15'), findsOneWidget);
        expect(find.textContaining('Berikutnya 15 Jan 2030'), findsOneWidget);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await settle(tester);
        await tester.tap(find.text('Jeda'));
        await settle(tester);
        expect(find.textContaining('Dijeda'), findsOneWidget);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await settle(tester);
        await tester.tap(find.text('Lanjutkan'));
        await settle(tester);
        expect(find.textContaining('Berikutnya'), findsOneWidget);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await settle(tester);
        await tester.tap(find.text('Hapus'));
        await settle(tester);
        expect(find.text('Hapus transaksi berulang?'), findsOneWidget);
        await tester.tap(find.text('Hapus').last);
        await settle(tester);

        expect(
          find.textContaining('Belum ada transaksi berulang'),
          findsOneWidget,
        );
        final rules = await tester.runAsync(
          () => h.db.watchRecurringRules().first,
        );
        expect(rules, isEmpty);
      },
      seed: (db) async {
        await db.addRecurringRule(
          type: TxType.expense,
          amount: 100000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-tagihan',
          frequency: Frequency.monthly,
          startDate: DateTime(2030, 1, 15),
          note: 'Sewa',
        );
      },
    );

    appTest(
      'belum premium: pengingat menawarkan upgrade, bukan sakelar aktif',
      (tester, h) async {
        await tester.tap(find.byTooltip('Catat'));
        await settle(tester);
        await tester.enterText(find.byType(TextField).first, '100000');
        await tester.tap(find.text('Tagihan & Utilitas'));
        await tester.pump();
        await tester.tap(find.text('Tidak berulang'));
        await settle(tester);
        await tester.tap(find.text('Bulanan').last);
        await settle(tester);

        expect(find.text('Ingatkan saya'), findsOneWidget);
        // 2: tile "Ingatkan saya" ini DAN tile "Scan Struk" (selalu tampil di
        // mode create) sama-sama premium-gated dan berbagi subtitle ini.
        expect(find.text('Fitur Premium'), findsNWidgets(2));
        expect(find.byType(SwitchListTile), findsNothing);
      },
      subscription: FakeSubscriptionStatus(),
    );

    appTest('premium: menyalakan pengingat dan memilih H-3 tersimpan', (
      tester,
      h,
    ) async {
      await tester.tap(find.byTooltip('Catat'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '100000');
      await tester.tap(find.text('Tagihan & Utilitas'));
      await tester.pump();
      await tester.tap(find.text('Tidak berulang'));
      await settle(tester);
      await tester.tap(find.text('Bulanan').last);
      await settle(tester);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Ingatkan saya'));
      await settle(tester);
      await tester.tap(find.text('H-1'));
      await settle(tester);
      await tester.tap(find.text('H-3').last);
      await settle(tester);

      await tester.tap(find.text('Simpan'));
      await settle(tester);

      final rules = await tester.runAsync(
        () => h.db.watchRecurringRules().first,
      );
      final rule = rules!.single.rule;
      expect((rule.reminderEnabled, rule.reminderDaysBefore), (true, 3));
    }, subscription: FakeSubscriptionStatus(premium: true));

    appTest(
      'saat aplikasi dibuka, kejadian yang terlewat dicatat otomatis',
      (tester, h) async {
        expect(find.text('3 transaksi berulang dicatat'), findsOneWidget);
        final txs = await tester.runAsync(() => h.db.getTransactions());
        expect(txs, hasLength(3));
        // Dibuka lagi: tidak ada tambahan.
        final again = await tester.runAsync(() => h.db.generateDueRecurring());
        expect(again, 0);
      },
      seed: (db) async {
        final now = DateTime.now();
        await db.addRecurringRule(
          type: TxType.expense,
          amount: 50000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-hiburan',
          frequency: Frequency.monthly,
          startDate: DateTime(now.year, now.month - 2, 1),
        );
      },
    );
  });
}
