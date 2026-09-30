import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _foreground(WidgetTester tester) async {
  final b = tester.binding;
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    b.handleAppLifecycleStateChanged(s);
  }
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest(
    'lewat 80% memicu notifikasi sekali, tidak berulang tanpa perubahan',
    (tester, h) async {
      // 900rb dari anggaran 1jt = 90%, warning.
      expect(h.notifications.sent, hasLength(1));
      expect(h.notifications.sent.single.title, contains('hampir habis'));

      // Buka lagi tanpa transaksi baru: tidak ada notifikasi kedua.
      await _foreground(tester);
      expect(h.notifications.sent, hasLength(1));
    },
    seed: (db) async {
      await db.setBudget('cat-exp-makan', 1000000);
      await db.addTransaction(
        type: TxType.expense,
        amount: 900000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime.now(),
      );
    },
  );

  appTest(
    'lewat 100% memicu notifikasi kedua yang berbeda dari ambang warning',
    (tester, h) async {
      expect(h.notifications.sent, hasLength(1));
      expect(h.notifications.sent.single.title, contains('hampir habis'));

      await tester.runAsync(
        () => h.db.addTransaction(
          type: TxType.expense,
          amount: 200000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-makan',
          date: DateTime.now(),
        ),
      );
      await _foreground(tester);

      expect(h.notifications.sent, hasLength(2));
      expect(h.notifications.sent.last.title, contains('terlampaui'));
    },
    seed: (db) async {
      await db.setBudget('cat-exp-makan', 1000000);
      await db.addTransaction(
        type: TxType.expense,
        amount: 900000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime.now(),
      );
    },
  );

  appTest(
    'di bawah 80% tidak memicu notifikasi',
    (tester, h) async {
      expect(h.notifications.sent, isEmpty);
    },
    seed: (db) async {
      await db.setBudget('cat-exp-makan', 1000000);
      await db.addTransaction(
        type: TxType.expense,
        amount: 300000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime.now(),
      );
    },
  );
}
