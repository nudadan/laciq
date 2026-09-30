import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/providers.dart';
import 'package:dompet_pintar/features/agenda/agenda_reminder_service.dart';
import 'package:dompet_pintar/features/budget/budget_notification_service.dart';
import 'package:dompet_pintar/features/recurring/recurring_reminder_service.dart';
import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:dompet_pintar/features/security/lock_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Operasi lintas buku: notifikasi anggaran, pengingat, dan pembuatan
/// transaksi berulang harus bekerja untuk SEMUA buku yang dapat dipakai,
/// bukan hanya buku aktif.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('id_ID'));

  late AppDatabase db;
  late String biz;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    biz = await db.addLedger(
      name: 'Toko',
      icon: 'business',
      color: 1,
      template: LedgerTemplate.business,
    );
  });
  tearDown(() => db.close());

  String bizId(String base) => ledgerSeedId(biz, base);

  group('notifikasi anggaran', () {
    Future<void> overspend() async {
      final now = DateTime.now();
      // Buku Utama: anggaran Makan 10.000, terpakai 50.000.
      await db.setBudget('cat-exp-makan', 10000);
      await db.addTransaction(
        type: TxType.expense,
        amount: 50000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: now,
      );
      // Buku Toko: anggaran Stok 10.000, terpakai 50.000.
      await db.setBudget(bizId('cat-exp-stok'), 10000);
      await db.addTransaction(
        type: TxType.expense,
        amount: 50000,
        accountId: bizId('acc-tunai'),
        categoryId: bizId('cat-exp-stok'),
        date: now,
      );
    }

    test('memeriksa semua buku, bukan hanya buku utama', () async {
      await overspend();
      final sender = FakeNotificationSender();
      await BudgetNotificationService(
        MemoryKeyValueStore(),
        sender,
      ).checkAndNotify(db);
      expect(sender.sent.length, 2);
    });

    test('buku terkunci dilewati', () async {
      await overspend();
      final sender = FakeNotificationSender();
      await BudgetNotificationService(
        MemoryKeyValueStore(),
        sender,
      ).checkAndNotify(db, lockedLedgerIds: {biz});
      expect(sender.sent.length, 1);
      expect(sender.sent.single.title, contains('Makanan'));
    });

    test(
      'nama buku ditambahkan ke judul bila lebih dari satu buku aktif',
      () async {
        await overspend();
        final sender = FakeNotificationSender();
        await BudgetNotificationService(
          MemoryKeyValueStore(),
          sender,
        ).checkAndNotify(
          db,
          ledgerNames: {kMainLedgerId: 'Buku Utama', biz: 'Toko'},
        );
        expect(
          sender.sent.map((s) => s.title),
          containsAll([
            contains('Makanan & Minuman · Buku Utama'),
            contains('Pembelian Stok / Bahan Baku · Toko'),
          ]),
        );
      },
    );

    test('tanpa nama buku, judul seperti semula', () async {
      await overspend();
      final sender = FakeNotificationSender();
      await BudgetNotificationService(
        MemoryKeyValueStore(),
        sender,
      ).checkAndNotify(db);
      expect(sender.sent.every((s) => !s.title.contains('·')), isTrue);
    });
  });

  group('pengingat', () {
    test(
      'pengingat transaksi berulang menyebut nama buku bila diberikan',
      () async {
        final due = DateTime.now().add(const Duration(days: 10));
        await db.addRecurringRule(
          type: TxType.expense,
          amount: 100000,
          accountId: bizId('acc-tunai'),
          categoryId: bizId('cat-exp-sewa'),
          frequency: Frequency.monthly,
          startDate: DateTime(due.year, due.month, due.day),
          reminderEnabled: true,
          reminderDaysBefore: 1,
        );
        final rules = await db.watchRecurringRules(ledgerId: null).first;
        final sender = FakeNotificationSender();
        await RecurringReminderService(sender)
            .reschedule(rules, ledgerNames: {biz: 'Toko'});
        expect(
          sender.scheduled.single.title,
          'Pengingat transaksi berulang · Toko',
        );

        final plain = FakeNotificationSender();
        await RecurringReminderService(plain).reschedule(rules);
        expect(plain.scheduled.single.title, 'Pengingat transaksi berulang');
      },
    );

    test('pengingat agenda menyebut nama buku bila diberikan', () async {
      final due = DateTime.now().add(const Duration(days: 10));
      await db.addAgenda(
        title: 'Bayar pajak',
        frequency: Frequency.yearly,
        startDate: DateTime(due.year, due.month, due.day),
        ledgerId: biz,
      );
      final items = [
        for (final a in await db.watchAgendaReminders(ledgerId: null).first)
          AgendaView(a),
      ];
      final sender = FakeNotificationSender();
      await AgendaReminderService(sender)
          .reschedule(items, premium: true, ledgerNames: {biz: 'Toko'});
      expect(sender.scheduled.single.title, 'Bayar pajak · Toko');

      final plain = FakeNotificationSender();
      await AgendaReminderService(plain).reschedule(items, premium: true);
      expect(plain.scheduled.single.title, 'Bayar pajak');
    });
  });

  group('recurringGeneratorProvider', () {
    Future<int> generate({required bool ultimate}) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          subscriptionStatusProvider.overrideWithValue(
            FakeSubscriptionStatus(ultimate: ultimate),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(recurringGeneratorProvider)();
    }

    setUp(() async {
      final start = DateTime.now().subtract(const Duration(days: 1));
      final day = DateTime(start.year, start.month, start.day);
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 1000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        frequency: Frequency.monthly,
        startDate: day,
      );
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 2000,
        accountId: bizId('acc-tunai'),
        categoryId: bizId('cat-exp-sewa'),
        frequency: Frequency.monthly,
        startDate: day,
      );
    });

    test('Ultimate: aturan di semua buku dibuat', () async {
      expect(await generate(ultimate: true), 2);
      expect((await db.getTransactions(ledgerId: biz)).length, 1);
    });

    test(
      'bukan Ultimate: aturan di buku terkunci dijeda, Buku Utama tetap jalan',
      () async {
        expect(await generate(ultimate: false), 1);
        expect(await db.getTransactions(ledgerId: biz), isEmpty);
        // Ultimate aktif lagi: disusul.
        expect(await generate(ultimate: true), 1);
      },
    );
  });
}
