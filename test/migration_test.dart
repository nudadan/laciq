import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;
import 'generated_migrations/schema_v5.dart' as v5;
import 'generated_migrations/schema_v6.dart' as v6;
import 'generated_migrations/schema_v7.dart' as v7;
import 'generated_migrations/schema_v8.dart' as v8;

/// Data pengguna nyata di setiap versi lama harus selamat dari semua migrasi.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  const latest = 9;

  for (final from in [1, 2, 3, 4, 5, 6, 7, 8]) {
    test(
      'skema hasil migrasi v$from -> v$latest identik dengan skema v$latest baru',
      () async {
        final schema = await verifier.schemaAt(from);
        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, latest);
        await db.close();
      },
    );
  }

  Future<void> insertV1Data(v1.DatabaseAtV1 old) async {
    await old.customStatement(
      "INSERT INTO accounts (id, name, kind, initial_balance, archived, updated_at) "
      "VALUES ('a1', 'BCA', 1, 1000000, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO categories (id, name, type, icon, color, sort_order, archived, updated_at) "
      "VALUES ('c1', 'Makan', 1, 'food', 4293848814, 0, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO transactions (id, type, amount, account_id, category_id, "
      "transfer_to_account_id, date, note, created_at, updated_at, deleted_at) "
      "VALUES ('t1', 1, 50000, 'a1', 'c1', NULL, 1700000000, 'kopi', 1700000000, 1700000000, NULL)",
    );
  }

  test(
    'data pengguna v1 utuh setelah migrasi ke v$latest; semua fitur baru berfungsi',
    () async {
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      await insertV1Data(old);
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);

      expect(
        (await db.watchAccountBalances().first).single.balance,
        1000000 - 50000,
      );
      final tx = (await db.getTransactions()).single.tx;
      expect((tx.note, tx.amount, tx.recurringId), ('kopi', 50000, null));

      // v2: transaksi berulang.
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 10000,
        accountId: 'a1',
        categoryId: 'c1',
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 1, 1),
      );
      expect(await db.generateDueRecurring(now: DateTime(2026, 3, 1)), 3);

      // v3: target tabungan, tanpa memengaruhi saldo dompet.
      final balanceBefore =
          (await db.watchAccountBalances().first).single.balance;
      final goal = await db.addGoal(
        name: 'Dana darurat',
        targetAmount: 5000000,
        icon: 'savings',
        color: 1,
      );
      await db.addContribution(
        goalId: goal,
        kind: ContributionKind.deposit,
        amount: 750000,
      );
      final g = (await db.watchGoals().first).single;
      expect(g.saved, 750000);
      expect(
        (await db.watchAccountBalances().first).single.balance,
        balanceBefore,
      );
      await db.close();
    },
  );

  test(
    'data pengguna v2 (termasuk aturan berulang) utuh setelah migrasi ke v$latest',
    () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await old.customStatement(
        "INSERT INTO accounts (id, name, kind, initial_balance, archived, updated_at) "
        "VALUES ('a1', 'BCA', 1, 0, 0, 1700000000)",
      );
      await old.customStatement(
        "INSERT INTO categories (id, name, type, icon, color, sort_order, archived, updated_at) "
        "VALUES ('c1', 'Sewa', 1, 'home', 4293848814, 0, 0, 1700000000)",
      );
      await old.customStatement(
        "INSERT INTO recurring_rules (id, type, amount, account_id, category_id, "
        "transfer_to_account_id, note, frequency, start_date, next_index, end_date, "
        "active, created_at, updated_at) "
        "VALUES ('r1', 1, 100000, 'a1', 'c1', NULL, 'Sewa', 1, 1767225600, 2, NULL, 1, 1700000000, 1700000000)",
      );
      await old.customStatement(
        "INSERT INTO transactions (id, type, amount, account_id, category_id, "
        "transfer_to_account_id, date, note, created_at, updated_at, deleted_at, recurring_id) "
        "VALUES ('rec-r1-0', 1, 100000, 'a1', 'c1', NULL, 1767225600, 'Sewa', 1700000000, 1700000000, NULL, 'r1')",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);

      final rule = (await db.watchRecurringRules().first).single.rule;
      expect(
        (rule.id, rule.amount, rule.nextIndex, rule.active),
        ('r1', 100000, 2, true),
      );
      final tx = (await db.getTransactions()).single.tx;
      expect((tx.id, tx.recurringId), ('rec-r1-0', 'r1'));
      expect(await db.watchGoals().first, isEmpty); // tabel baru, kosong
      await db.close();
    },
  );

  test(
    'data pengguna v3 utuh setelah migrasi ke v$latest; sub-kategori dan tag berfungsi',
    () async {
      final schema = await verifier.schemaAt(3);
      final old = v3.DatabaseAtV3(schema.newConnection());
      await old.customStatement(
        "INSERT INTO accounts (id, name, kind, initial_balance, archived, updated_at) "
        "VALUES ('a1', 'BCA', 1, 0, 0, 1700000000)",
      );
      await old.customStatement(
        "INSERT INTO categories (id, name, type, icon, color, sort_order, archived, updated_at) "
        "VALUES ('c1', 'Makan', 1, 'food', 4293848814, 0, 0, 1700000000)",
      );
      await old.customStatement(
        "INSERT INTO transactions (id, type, amount, account_id, category_id, "
        "transfer_to_account_id, date, note, created_at, updated_at, deleted_at) "
        "VALUES ('t1', 1, 25000, 'a1', 'c1', NULL, 1700000000, 'kopi', 1700000000, 1700000000, NULL)",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);

      // Data lama utuh, kategori lama tanpa induk. (Kategori bawaan "Utang"
      // baru dari migrasi v8->v9 juga ikut ada di daftar ini sejak itu.)
      expect((await db.watchAccountBalances().first).single.balance, -25000);
      final expenseCats = await db.watchCategories(TxType.expense).first;
      final oldCat = expenseCats.firstWhere((c) => c.id == 'c1');
      expect((oldCat.id, oldCat.parentId), ('c1', null));

      // v4: sub-kategori (satu tingkat).
      final sub = await db.addCategory(
        type: TxType.expense,
        name: 'Kopi',
        icon: 'food',
        color: 1,
        parentId: 'c1',
      );
      expect(
        () => db.addCategory(
          type: TxType.expense,
          name: 'Cucu',
          icon: 'food',
          color: 1,
          parentId: sub,
        ),
        throwsA(isA<CategoryException>()),
      );

      // v4: tag, dan menandai transaksi lama dengan tag baru.
      final tagId = await db.addTag('Kantor');
      await db.setTransactionTags('t1', [tagId]);
      final tagsOfT1 = await db.watchTagsForTransaction('t1').first;
      expect(tagsOfT1.map((t) => t.name), ['Kantor']);

      await db.close();
    },
  );

  test('data pengguna v4 (aturan berulang tanpa reminder) utuh setelah '
      'migrasi ke v$latest; kolom reminder & agenda baru berfungsi', () async {
    final schema = await verifier.schemaAt(4);
    final old = v4.DatabaseAtV4(schema.newConnection());
    await old.customStatement(
      "INSERT INTO accounts (id, name, kind, initial_balance, archived, updated_at) "
      "VALUES ('a1', 'BCA', 1, 0, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO categories (id, name, type, icon, color, sort_order, archived, updated_at) "
      "VALUES ('c1', 'Cicilan', 1, 'installment', 4293848814, 0, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO recurring_rules (id, type, amount, account_id, category_id, "
      "transfer_to_account_id, note, frequency, start_date, next_index, end_date, "
      "active, created_at, updated_at) "
      "VALUES ('r1', 1, 500000, 'a1', 'c1', NULL, 'Cicilan motor', 1, 1767225600, 0, NULL, 1, 1700000000, 1700000000)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, latest);

    // Kolom baru punya nilai bawaan yang aman (reminder mati sampai
    // pengguna nyalakan sendiri).
    final rule = (await db.watchRecurringRules().first).single.rule;
    expect(
      (rule.id, rule.reminderEnabled, rule.reminderDaysBefore),
      ('r1', false, 1),
    );

    // Tabel agenda baru, kosong, tapi CRUD-nya berfungsi.
    expect(await db.watchAgendaReminders().first, isEmpty);
    await db.addAgenda(
      title: 'Servis AC',
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 1, 10),
    );
    final agenda = (await db.watchAgendaReminders().first).single;
    expect((agenda.title, agenda.reminderDaysBefore), ('Servis AC', 1));

    await db.close();
  });

  test('data pengguna v5 (agenda tanpa estimasi biaya) utuh setelah migrasi ke '
      'v$latest; kolom estimasi & eksekusi agenda berfungsi', () async {
    final schema = await verifier.schemaAt(5);
    final old = v5.DatabaseAtV5(schema.newConnection());
    await old.customStatement(
      "INSERT INTO accounts (id, name, kind, initial_balance, archived, updated_at) "
      "VALUES ('a1', 'BCA', 1, 1000000, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO categories (id, name, type, icon, color, sort_order, archived, updated_at) "
      "VALUES ('c1', 'Servis', 1, 'other', 4293848814, 0, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO agenda_reminders (id, title, note, frequency, start_date, "
      "next_index, end_date, reminder_days_before, active, created_at, updated_at) "
      "VALUES ('ag1', 'Servis AC', NULL, 1, 1767225600, 0, NULL, 1, 1, 1700000000, 1700000000)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, latest);

    // Kolom baru punya nilai bawaan yang aman (estimasi kosong sampai
    // pengguna isi sendiri; belum ada transaksi yang tertaut).
    final agenda = (await db.watchAgendaReminders().first).single;
    expect((agenda.id, agenda.estimatedAmount), ('ag1', null));

    // v6: eksekusi agenda lama mencatat transaksi nyata, nominal bebas
    // beda dari estimasi (yang memang belum diisi), dan memajukan jadwal.
    final txId = await db.executeAgenda(
      agendaId: 'ag1',
      amount: 250000,
      accountId: 'a1',
      categoryId: 'c1',
      date: DateTime(2026, 2, 1),
    );
    final tx = (await db.getTransactions()).single.tx;
    expect((tx.id, tx.amount, tx.agendaId), (txId, 250000, 'ag1'));
    final after = (await db.watchAgendaReminders().first).single;
    expect(after.nextIndex, 1);

    await db.close();
  });

  test('data pengguna v6 (transaksi tanpa foto struk) utuh setelah migrasi ke '
      'v$latest; kolom receiptPath baru berfungsi', () async {
    final schema = await verifier.schemaAt(6);
    final old = v6.DatabaseAtV6(schema.newConnection());
    await old.customStatement(
      "INSERT INTO accounts (id, name, kind, initial_balance, archived, updated_at) "
      "VALUES ('a1', 'BCA', 1, 1000000, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO categories (id, name, type, icon, color, sort_order, archived, updated_at) "
      "VALUES ('c1', 'Makan', 1, 'food', 4293848814, 0, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO transactions (id, type, amount, account_id, category_id, "
      "transfer_to_account_id, date, note, created_at, updated_at, deleted_at) "
      "VALUES ('t1', 1, 50000, 'a1', 'c1', NULL, 1700000000, 'kopi', 1700000000, 1700000000, NULL)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, latest);

    // Transaksi lama tidak punya foto struk (kolom baru, default null).
    final tx = (await db.getTransactions()).single.tx;
    expect((tx.id, tx.receiptPath), ('t1', null));

    // Fitur baru: transaksi baru bisa menautkan foto struk.
    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: 25000,
      accountId: 'a1',
      categoryId: 'c1',
      date: DateTime(2026, 3, 1),
      receiptPath: 'receipts/t2.jpg',
    );
    final withReceipt = (await db.getTransactions()).firstWhere(
      (e) => e.tx.id == txId,
    );
    expect(withReceipt.tx.receiptPath, 'receipts/t2.jpg');

    await db.close();
  });

  test('data pengguna v7 (transaksi tanpa utang/piutang) utuh setelah migrasi '
      'ke v$latest; tabel debts baru berfungsi', () async {
    final schema = await verifier.schemaAt(7);
    final old = v7.DatabaseAtV7(schema.newConnection());
    await old.customStatement(
      "INSERT INTO accounts (id, name, kind, initial_balance, archived, updated_at) "
      "VALUES ('a1', 'BCA', 1, 1000000, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO categories (id, name, type, icon, color, sort_order, archived, updated_at) "
      "VALUES ('c1', 'Makan', 1, 'food', 4293848814, 0, 0, 1700000000)",
    );
    await old.customStatement(
      "INSERT INTO transactions (id, type, amount, account_id, category_id, "
      "transfer_to_account_id, date, note, created_at, updated_at, deleted_at, "
      "recurring_id, agenda_id, receipt_path) "
      "VALUES ('t1', 1, 50000, 'a1', 'c1', NULL, 1700000000, 'kopi', 1700000000, "
      "1700000000, NULL, NULL, NULL, NULL)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, latest);

    // Transaksi lama tidak tertaut utang/piutang (kolom baru, default null).
    final tx = (await db.getTransactions()).single.tx;
    expect((tx.id, tx.debtId), ('t1', null));

    // Fitur baru: catat utang, bayar sebagian, cek paidAmount & transaksi.
    final debtId = await db.addDebt(
      type: DebtType.debt,
      counterpartyName: 'Budi',
      amount: 500000,
    );
    final txId = await db.recordDebtPayment(
      debtId: debtId,
      amount: 200000,
      accountId: 'a1',
      date: DateTime(2026, 4, 1),
    );
    final debt = (await db.watchDebts().first).single;
    expect((debt.id, debt.paidAmount), (debtId, 200000));
    final payment = (await db.getTransactions()).firstWhere(
      (e) => e.tx.id == txId,
    );
    expect(
      (payment.tx.type, payment.tx.amount, payment.tx.debtId),
      (TxType.expense, 200000, debtId),
    );

    await db.close();
  });

  test(
    'data pengguna v8 (kategori tanpa Utang/Piutang) utuh setelah migrasi ke '
    'v$latest; kategori Utang/Piutang baru otomatis tersedia',
    () async {
      final schema = await verifier.schemaAt(8);
      final old = v8.DatabaseAtV8(schema.newConnection());
      await old.customStatement(
        "INSERT INTO accounts (id, name, kind, initial_balance, archived, updated_at) "
        "VALUES ('a1', 'BCA', 1, 1000000, 0, 1700000000)",
      );
      await old.customStatement(
        "INSERT INTO categories (id, name, type, icon, color, sort_order, archived, updated_at) "
        "VALUES ('c1', 'Makan', 1, 'food', 4293848814, 0, 0, 1700000000)",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);

      // Kategori lama tetap ada, dan kategori baru "Utang"/"Piutang"
      // otomatis tersedia meski pengguna sudah lama pakai app (bukan cuma
      // pada instalasi baru lewat _seed()).
      final expenseCats = await db.watchCategories(TxType.expense).first;
      expect(
        expenseCats.map((c) => c.id),
        containsAll(['c1', 'cat-exp-utang']),
      );
      final utang = expenseCats.firstWhere((c) => c.id == 'cat-exp-utang');
      expect(utang.name, 'Utang');

      final incomeCats = await db.watchCategories(TxType.income).first;
      expect(incomeCats.map((c) => c.id), contains('cat-inc-piutang'));
      final piutang = incomeCats.firstWhere((c) => c.id == 'cat-inc-piutang');
      expect(piutang.name, 'Piutang');

      await db.close();
    },
  );
}
