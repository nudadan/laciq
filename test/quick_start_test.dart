import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/features/dashboard/quick_start.dart';
import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _addTx(AppDatabase db) async {
  final acc = (await db.watchAccountBalances().first).first;
  await db.addTransaction(
    type: TxType.expense,
    amount: 25000,
    accountId: acc.id,
    categoryId: 'cat-exp-makan',
    date: DateTime.now(),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('buildQuickStart', () {
    test('instalasi baru: lima langkah, belum ada yang selesai', () {
      final qs = buildQuickStart(
        transactionCount: 0,
        hasBudget: false,
        hasGoal: false,
        hasReminder: false,
        backedUp: false,
      );
      expect(qs.items.length, 5);
      expect(qs.doneCount, 0);
      expect(qs.allDone, isFalse);
    });

    test('tiap langkah tercentang dari datanya sendiri', () {
      bool done(QuickStart q, QuickStartStep s) =>
          q.items.firstWhere((i) => i.step == s).done;

      var qs = buildQuickStart(
        transactionCount: 3,
        hasBudget: false,
        hasGoal: false,
        hasReminder: false,
        backedUp: false,
      );
      expect(done(qs, QuickStartStep.firstTransaction), isTrue);
      expect(qs.doneCount, 1);

      qs = buildQuickStart(
        transactionCount: 0,
        hasBudget: true,
        hasGoal: true,
        hasReminder: true,
        backedUp: true,
      );
      expect(done(qs, QuickStartStep.firstTransaction), isFalse);
      expect(done(qs, QuickStartStep.budget), isTrue);
      expect(done(qs, QuickStartStep.goal), isTrue);
      expect(done(qs, QuickStartStep.reminder), isTrue);
      expect(done(qs, QuickStartStep.backup), isTrue);
      expect(qs.allDone, isFalse);
    });

    test('semua selesai', () {
      final qs = buildQuickStart(
        transactionCount: 1,
        hasBudget: true,
        hasGoal: true,
        hasReminder: true,
        backedUp: true,
      );
      expect(qs.allDone, isTrue);
    });
  });

  group('kartu Mulai cepat di Beranda', () {
    appTest('instalasi baru: kartu tampil dengan 0 dari 5', (tester, h) async {
      expect(find.text('Mulai cepat'), findsOneWidget);
      expect(find.text('0 dari 5'), findsOneWidget);
      expect(find.text('Catat transaksi pertama'), findsOneWidget);
      expect(find.byKey(const Key('quickstart-profitLoss')), findsNothing);
    });

    appTest(
      'pengguna lama: langkah yang sudah dikerjakan tercentang otomatis',
      (tester, h) async {
        expect(find.text('Mulai cepat'), findsOneWidget);
        expect(find.text('3 dari 5'), findsOneWidget);
      },
      seed: (db) async {
        await _addTx(db);
        await db.setBudget('cat-exp-makan', 500000);
        await db.addGoal(
          name: 'Liburan',
          targetAmount: 1000000,
          icon: 'travel',
          color: 0xFF00897B,
        );
      },
    );

    appTest('Sembunyikan: kartu hilang dan penandanya tersimpan', (
      tester,
      h,
    ) async {
      await tester.tap(find.text('Sembunyikan'));
      await settle(tester);
      expect(find.text('Mulai cepat'), findsNothing);
      expect(await h.store.read(quickStartHiddenKey), '1');
    });

    appTest('sudah disembunyikan di sesi sebelumnya: kartu tidak tampil', (
      tester,
      h,
    ) async {
      expect(find.text('Mulai cepat'), findsNothing);
    }, kvStore: MemoryKeyValueStore()..write(quickStartHiddenKey, '1'));

    appTest(
      'semua langkah selesai: kartu hilang dan tidak muncul lagi',
      (tester, h) async {
        expect(find.text('Mulai cepat'), findsNothing);
        expect(await h.store.read(quickStartDoneKey), '1');
      },
      seed: (db) async {
        await _addTx(db);
        await db.setBudget('cat-exp-makan', 500000);
        await db.addGoal(
          name: 'Liburan',
          targetAmount: 1000000,
          icon: 'travel',
          color: 0xFF00897B,
        );
        await db.addAgenda(
          title: 'Servis motor',
          frequency: Frequency.monthly,
          startDate: DateTime.now().add(const Duration(days: 20)),
        );
      },
      kvStore: MemoryKeyValueStore()..write(backupDoneKey, '1'),
    );

    appTest('"Lihat panduan lagi" memunculkan kartu yang disembunyikan', (
      tester,
      h,
    ) async {
      expect(find.text('Mulai cepat'), findsNothing);
      await tester.tap(find.byTooltip('Pengaturan'));
      await settle(tester);
      await tester.tap(find.text('Lihat panduan lagi'));
      await settle(tester);
      await tester.tap(find.text('Lewati'));
      await settle(tester);
      await tester.tap(find.byTooltip('Kembali'));
      await settle(tester);

      expect(find.text('Mulai cepat'), findsOneWidget);
      expect(await h.store.read(quickStartHiddenKey), isNull);
    }, kvStore: MemoryKeyValueStore()..write(quickStartHiddenKey, '1'));

    appTest('Mode usaha: tampil tautan Laba Rugi', (tester, h) async {
      expect(find.byKey(const Key('quickstart-profitLoss')), findsOneWidget);
    }, seed: (db) => db.setLedgerKind(kMainLedgerId, LedgerKind.business));

    appTest('ketuk Catat transaksi pertama membuka formulir', (
      tester,
      h,
    ) async {
      await tester.tap(find.byKey(const Key('quickstart-firstTransaction')));
      await settle(tester);
      expect(find.text('Simpan'), findsWidgets);
    });
  });
}
