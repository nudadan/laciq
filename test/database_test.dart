import 'package:drift/native.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final month = DateTime(2026, 9);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<AccountBalance> balanceOf(String id) async =>
      (await db.watchAccountBalances().first).firstWhere((a) => a.id == id);

  test('seed membuat kategori Indonesia dan dompet Tunai', () async {
    final expense = await db.watchCategories(TxType.expense).first;
    final income = await db.watchCategories(TxType.income).first;
    expect(expense.map((c) => c.name), contains('Makanan & Minuman'));
    expect(income.map((c) => c.name), contains('Gaji'));
    expect((await balanceOf('acc-tunai')).balance, 0);
  });

  test(
    'saldo memperhitungkan saldo awal, pemasukan, pengeluaran, transfer',
    () async {
      await db.addAccount(
        name: 'BCA',
        kind: AccountKind.bank,
        initialBalance: 1000000,
      );
      final bca = (await db.watchAccountBalances().first).firstWhere(
        (a) => a.name == 'BCA',
      );

      await db.addTransaction(
        type: TxType.income,
        amount: 5000000,
        accountId: bca.id,
        categoryId: 'cat-inc-gaji',
        date: DateTime(2026, 9, 1),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: 250000,
        accountId: bca.id,
        categoryId: 'cat-exp-makan',
        date: DateTime(2026, 9, 2),
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: 1000000,
        accountId: bca.id,
        transferToAccountId: 'acc-tunai',
        date: DateTime(2026, 9, 3),
      );

      expect(
        (await balanceOf(bca.id)).balance,
        1000000 + 5000000 - 250000 - 1000000,
      );
      expect((await balanceOf('acc-tunai')).balance, 1000000);
    },
  );

  test('transfer tidak dihitung sebagai pemasukan/pengeluaran', () async {
    await db.addTransaction(
      type: TxType.income,
      amount: 100000,
      accountId: 'acc-tunai',
      categoryId: 'cat-inc-gaji',
      date: DateTime(2026, 9, 5),
    );
    await db.addAccount(name: 'Dana', kind: AccountKind.ewallet);
    final dana = (await db.watchAccountBalances().first).firstWhere(
      (a) => a.name == 'Dana',
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: 40000,
      accountId: 'acc-tunai',
      transferToAccountId: dana.id,
      date: DateTime(2026, 9, 6),
    );

    final totals = await db.watchTotals(month).first;
    expect(totals.income, 100000);
    expect(totals.expense, 0);
  });

  test(
    'soft delete menghapus dari saldo dan laporan, restore mengembalikan',
    () async {
      await db.addTransaction(
        type: TxType.expense,
        amount: 30000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime(2026, 9, 10),
      );
      final id = (await db.watchTransactions(month).first).single.tx.id;

      await db.setTransactionDeleted(id, deleted: true);
      expect(await db.watchTransactions(month).first, isEmpty);
      expect((await balanceOf('acc-tunai')).balance, 0);

      await db.setTransactionDeleted(id, deleted: false);
      expect((await db.watchTransactions(month).first), hasLength(1));
      expect((await balanceOf('acc-tunai')).balance, -30000);
    },
  );

  test('laporan bulanan hanya memuat transaksi dalam bulan tersebut', () async {
    for (final d in [
      DateTime(2026, 8, 31, 23, 59),
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 30, 23, 59),
      DateTime(2026, 10, 1),
    ]) {
      await db.addTransaction(
        type: TxType.expense,
        amount: 10000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: d,
      );
    }
    expect((await db.watchTotals(month).first).expense, 20000);
    expect(await db.watchTransactions(month).first, hasLength(2));
  });

  test(
    'progres anggaran menghitung pengeluaran kategori dan bisa dihapus',
    () async {
      await db.setBudget('cat-exp-makan', 500000);
      await db.addTransaction(
        type: TxType.expense,
        amount: 120000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime(2026, 9, 12),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: 50000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-transport',
        date: DateTime(2026, 9, 12),
      );

      var progress = await db.watchBudgetProgress(month).first;
      final makan = progress.firstWhere(
        (p) => p.category.id == 'cat-exp-makan',
      );
      final transport = progress.firstWhere(
        (p) => p.category.id == 'cat-exp-transport',
      );
      expect(makan.budget, 500000);
      expect(makan.spent, 120000);
      expect(transport.budget, isNull);
      expect(transport.spent, 50000);

      await db.setBudget('cat-exp-makan', null);
      progress = await db.watchBudgetProgress(month).first;
      expect(
        progress.firstWhere((p) => p.category.id == 'cat-exp-makan').budget,
        isNull,
      );
    },
  );

  test('pengeluaran per kategori diurutkan dari terbesar', () async {
    await db.addTransaction(
      type: TxType.expense,
      amount: 10000,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-makan',
      date: DateTime(2026, 9, 2),
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: 90000,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-hiburan',
      date: DateTime(2026, 9, 2),
    );
    final spend = await db.watchExpenseByCategory(month).first;
    expect(spend.map((s) => s.categoryId), [
      'cat-exp-hiburan',
      'cat-exp-makan',
    ]);
  });

  group('tren bulanan', () {
    test(
      '6 bulan berurutan, bulan tanpa transaksi tetap muncul dengan 0',
      () async {
        await db.addTransaction(
          type: TxType.income,
          amount: 5000000,
          accountId: 'acc-tunai',
          categoryId: 'cat-inc-gaji',
          date: DateTime(2026, 7, 1), // Juli, indeks 3 dari jendela Apr-Sep
        );
        await db.addTransaction(
          type: TxType.expense,
          amount: 200000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-makan',
          date: DateTime(2026, 9, 15),
        );

        final trend = await db.watchMonthlyTrend(DateTime(2026, 9)).first;
        expect(trend, hasLength(6));
        expect(trend.map((m) => (m.month.year, m.month.month)), [
          (2026, 4),
          (2026, 5),
          (2026, 6),
          (2026, 7),
          (2026, 8),
          (2026, 9),
        ]);
        expect(trend[3].income, 5000000); // Juli
        expect(trend[3].expense, 0);
        expect(trend[5].expense, 200000); // September
        // Bulan tanpa transaksi (Apr, Mei, Jun, Agu) tetap ada, bukan hilang.
        for (final i in [0, 1, 2, 4]) {
          expect((trend[i].income, trend[i].expense), (0, 0));
        }
      },
    );

    test('transaksi di luar jendela 6 bulan tidak ikut terhitung', () async {
      await db.addTransaction(
        type: TxType.income,
        amount: 1000000,
        accountId: 'acc-tunai',
        categoryId: 'cat-inc-gaji',
        date: DateTime(2026, 3, 15), // sebulan sebelum jendela (Apr-Sep)
      );
      final trend = await db.watchMonthlyTrend(DateTime(2026, 9)).first;
      expect(trend.every((m) => m.income == 0), isTrue);
    });

    test('transaksi terhapus dan transfer tidak ikut terhitung', () async {
      await db.addTransaction(
        type: TxType.expense,
        amount: 30000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime(2026, 9, 5),
      );
      final txId =
          (await db.watchTransactions(DateTime(2026, 9)).first).single.tx.id;
      await db.setTransactionDeleted(txId, deleted: true);

      await db.addAccount(name: 'Dana', kind: AccountKind.ewallet);
      final dana = (await db.watchAccountBalances().first).firstWhere(
        (a) => a.name == 'Dana',
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: 500000,
        accountId: 'acc-tunai',
        transferToAccountId: dana.id,
        date: DateTime(2026, 9, 6),
      );

      final trend = await db.watchMonthlyTrend(DateTime(2026, 9)).first;
      expect((trend.last.income, trend.last.expense), (0, 0));
    });
  });

  group('hapus semua data', () {
    test('mengembalikan ke kondisi seperti baru terpasang', () async {
      // Isi banyak data: akun, sub-kategori, tag, transaksi, anggaran, target.
      await db.addAccount(
        name: 'BCA',
        kind: AccountKind.bank,
        initialBalance: 1000000,
      );
      final sub = await db.addCategory(
        type: TxType.expense,
        name: 'Kopi',
        icon: 'coffee',
        color: 1,
        parentId: 'cat-exp-makan',
      );
      final tag = await db.addTag('Kantor');
      final txId = await db.addTransaction(
        type: TxType.expense,
        amount: 20000,
        accountId: 'acc-tunai',
        categoryId: sub,
        date: DateTime(2026, 9, 5),
      );
      await db.setTransactionTags(txId, [tag]);
      await db.setBudget('cat-exp-makan', 500000);
      await db.addGoal(
        name: 'Dana darurat',
        targetAmount: 1000000,
        icon: 'savings',
        color: 1,
      );
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 10000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 1, 1),
      );

      await db.addDebt(
        type: DebtType.debt,
        counterpartyName: 'Budi',
        amount: 100000,
      );
      await db
          .into(db.agendaReminders)
          .insert(
            AgendaRemindersCompanion.insert(
              id: 'ag-1',
              title: 'Listrik',
              frequency: Frequency.monthly,
              startDate: DateTime(2026, 9, 1),
              createdAt: DateTime(2026, 9, 1),
              updatedAt: DateTime(2026, 9, 1),
            ),
          );

      await db.eraseAllData();
      expect(await db.watchDebts().first, isEmpty);
      expect(await db.watchAgendaReminders().first, isEmpty);

      // Bandingkan dengan DB baru yang belum pernah diisi (hasil onCreate).
      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);

      final accounts = await db
          .watchAccountBalances(includeArchived: true)
          .first;
      final freshAccounts = await fresh
          .watchAccountBalances(includeArchived: true)
          .first;
      expect(
        accounts.map((a) => (a.name, a.kind, a.balance)),
        freshAccounts.map((a) => (a.name, a.kind, a.balance)),
      );

      final expenseCats = await db
          .watchCategories(TxType.expense, includeArchived: true)
          .first;
      final freshExpenseCats = await fresh
          .watchCategories(TxType.expense, includeArchived: true)
          .first;
      expect(
        expenseCats.map((c) => (c.id, c.name, c.parentId)),
        freshExpenseCats.map((c) => (c.id, c.name, c.parentId)),
      );

      expect(await db.watchTags().first, isEmpty);
      expect(await db.getTransactions(), isEmpty);
      expect(await db.watchRecurringRules().first, isEmpty);
      expect(await db.watchGoals().first, isEmpty);
      final progress = await db.watchBudgetProgress(DateTime(2026, 9)).first;
      expect(progress.every((p) => p.budget == null), isTrue);
    });
  });
}
