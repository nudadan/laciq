import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Multi buku kas: pemisahan data antar buku, aturan "satu buku", batas jumlah,
/// operasi lintas buku, dan backup. Lihat docs/RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final may = DateTime(2026, 5);
  final day = DateTime(2026, 5, 10);

  Future<String> addBiz({String name = 'Toko'}) => db.addLedger(
    name: name,
    icon: 'business',
    color: 0xFF00897B,
    template: LedgerTemplate.business,
  );

  String bizAcc(String biz) => ledgerSeedId(biz, 'acc-tunai');
  String bizExp(String biz, [String key = 'stok']) =>
      ledgerSeedId(biz, 'cat-exp-$key');
  String bizInc(String biz, [String key = 'penjualan']) =>
      ledgerSeedId(biz, 'cat-inc-$key');

  Matcher ledgerError([Matcher? msg]) => throwsA(
    isA<LedgerException>().having(
      (e) => e.message,
      'message',
      msg ?? isNotEmpty,
    ),
  );

  group('seed dan pembuatan buku', () {
    test('instalasi baru: satu Buku Utama dengan ID seed lama', () async {
      final ledgers = await db.watchLedgers().first;
      expect(ledgers.map((l) => l.id), [kMainLedgerId]);
      expect(ledgers.single.name, 'Buku Utama');
      final accounts = await db.watchAccountBalances().first;
      expect(accounts.map((a) => a.id), ['acc-tunai']);
      final exp = await db.watchCategories(TxType.expense).first;
      expect(exp.map((c) => c.id), contains('cat-exp-makan'));
      expect(exp.every((c) => c.ledgerId == kMainLedgerId), isTrue);
    });

    test(
      'template Bisnis: kategori usaha + Kas Usaha, ID berawalan buku',
      () async {
        final biz = await addBiz();
        expect(biz, startsWith('ledger-'));
        final exp = await db
            .watchCategories(TxType.expense, ledgerId: biz)
            .first;
        final inc = await db
            .watchCategories(TxType.income, ledgerId: biz)
            .first;
        expect(exp.length, 11);
        expect(inc.length, 6);
        expect(exp.map((c) => c.id), contains(bizExp(biz, 'stok')));
        expect(
          exp.map((c) => c.id),
          contains(debtCategoryId(biz, DebtType.debt)),
        );
        expect(
          inc.map((c) => c.id),
          contains(debtCategoryId(biz, DebtType.receivable)),
        );
        final accounts = await db.watchAccountBalances(ledgerId: biz).first;
        expect(
          (accounts.single.id, accounts.single.name),
          (bizAcc(biz), 'Kas Usaha'),
        );
      },
    );

    test(
      'template Kosong: hanya Lainnya + Utang/Piutang dan satu dompet',
      () async {
        final blank = await db.addLedger(
          name: 'Kosong',
          icon: 'savings',
          color: 1,
          template: LedgerTemplate.blank,
        );
        expect(
          (await db.watchCategories(TxType.expense, ledgerId: blank).first)
              .length,
          2,
        );
        expect(
          (await db.watchCategories(TxType.income, ledgerId: blank).first)
              .length,
          2,
        );
        expect(
          (await db.watchAccountBalances(ledgerId: blank).first).length,
          1,
        );
      },
    );

    test('debtCategoryId: Buku Utama memakai ID lama', () {
      expect(debtCategoryId(kMainLedgerId, DebtType.debt), 'cat-exp-utang');
      expect(
        debtCategoryId(kMainLedgerId, DebtType.receivable),
        'cat-inc-piutang',
      );
      expect(
        debtCategoryId('ledger-x', DebtType.debt),
        'ledger-x:cat-exp-utang',
      );
    });

    test(
      'nama buku: wajib, maks 40, unik tanpa peduli huruf besar/kecil',
      () async {
        await addBiz(name: 'Toko');
        await expectLater(
          addBiz(name: 'toko'),
          ledgerError(contains('Sudah ada')),
        );
        await expectLater(addBiz(name: '   '), ledgerError(contains('wajib')));
        await expectLater(addBiz(name: 'x' * 41), ledgerError(contains('40')));
      },
    );

    test(
      'batas $kMaxLedgers buku aktif; yang diarsipkan tidak dihitung',
      () async {
        final ids = <String>[];
        for (var i = 1; i < kMaxLedgers; i++) {
          ids.add(await addBiz(name: 'Buku $i'));
        }
        await expectLater(
          addBiz(name: 'Kelebihan'),
          ledgerError(contains('batas')),
        );

        await db.setLedgerArchived(ids.first, archived: true);
        final extra = await addBiz(name: 'Kelebihan');
        expect(extra, isNotEmpty);

        // Memulihkan yang diarsipkan sekarang melewati batas.
        await expectLater(
          db.setLedgerArchived(ids.first, archived: false),
          ledgerError(contains('batas')),
        );
      },
    );

    test('Buku Utama tidak bisa diarsipkan atau dihapus', () async {
      await expectLater(
        db.setLedgerArchived(kMainLedgerId, archived: true),
        ledgerError(contains('Buku Utama')),
      );
      await expectLater(
        db.deleteLedger(kMainLedgerId),
        ledgerError(contains('Buku Utama')),
      );
    });

    test(
      'updateLedger mengubah nama/ikon/warna dan menjaga keunikan nama',
      () async {
        final a = await addBiz(name: 'A');
        await addBiz(name: 'B');
        await db.updateLedger(id: a, name: 'A2', icon: 'home', color: 5);
        final l = (await db.watchLedgers().first).firstWhere((x) => x.id == a);
        expect((l.name, l.icon, l.color), ('A2', 'home', 5));
        await expectLater(
          db.updateLedger(id: a, name: 'b', icon: 'home', color: 5),
          ledgerError(contains('Sudah ada')),
        );
      },
    );

    test('menulis ke buku yang diarsipkan atau tidak ada ditolak', () async {
      final biz = await addBiz();
      await db.setLedgerArchived(biz, archived: true);
      await expectLater(
        db.addAccount(name: 'Baru', kind: AccountKind.cash, ledgerId: biz),
        ledgerError(contains('diarsipkan')),
      );
      await expectLater(
        db.addAccount(name: 'Baru', kind: AccountKind.cash, ledgerId: 'nope'),
        ledgerError(contains('tidak ditemukan')),
      );
    });
  });

  group('pemisahan data antar buku', () {
    late String biz;
    setUp(() async {
      biz = await addBiz();
      // Buku Utama: pengeluaran 30.000 (makan) + pemasukan 500.000 (gaji).
      await db.addTransaction(
        type: TxType.expense,
        amount: 30000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: day,
      );
      await db.addTransaction(
        type: TxType.income,
        amount: 500000,
        accountId: 'acc-tunai',
        categoryId: 'cat-inc-gaji',
        date: day,
      );
      // Buku Bisnis: pengeluaran 200.000 (stok) + pemasukan 900.000 (penjualan).
      await db.addTransaction(
        type: TxType.expense,
        amount: 200000,
        accountId: bizAcc(biz),
        categoryId: bizExp(biz),
        date: day,
      );
      await db.addTransaction(
        type: TxType.income,
        amount: 900000,
        accountId: bizAcc(biz),
        categoryId: bizInc(biz),
        date: day,
      );
    });

    test('saldo dompet dan total per bulan terpisah', () async {
      expect((await db.watchAccountBalances().first).single.balance, 470000);
      expect(
        (await db.watchAccountBalances(ledgerId: biz).first).single.balance,
        700000,
      );
      expect(await db.watchTotals(may).first, (income: 500000, expense: 30000));
      expect(await db.watchTotals(may, ledgerId: biz).first, (
        income: 900000,
        expense: 200000,
      ));
      // null = semua buku.
      expect((await db.watchAccountBalances(ledgerId: null).first).length, 2);
    });

    test(
      'daftar transaksi, tren bulanan, dan pengeluaran per kategori terpisah',
      () async {
        expect((await db.watchTransactions(may).first).length, 2);
        expect(
          (await db.watchTransactions(may, ledgerId: biz).first).length,
          2,
        );
        expect((await db.getTransactions()).length, 4); // semua buku
        expect((await db.getTransactions(ledgerId: biz)).length, 2);

        final trend = await db.watchMonthlyTrend(may, months: 1).first;
        expect((trend.single.income, trend.single.expense), (500000, 30000));
        final trendBiz = await db
            .watchMonthlyTrend(may, months: 1, ledgerId: biz)
            .first;
        expect(
          (trendBiz.single.income, trendBiz.single.expense),
          (900000, 200000),
        );

        final spend = await db.watchExpenseByCategory(may).first;
        expect(spend.map((s) => s.categoryId), ['cat-exp-makan']);
        final spendBiz = await db
            .watchExpenseByCategory(may, ledgerId: biz)
            .first;
        expect(spendBiz.map((s) => s.categoryId), [bizExp(biz)]);

        final catTrend = await db
            .watchCategoryMonthlyTrend(may, months: 1)
            .first;
        expect(catTrend.map((c) => c.categoryId), ['cat-exp-makan']);
      },
    );

    test('anggaran dan kemajuannya terpisah', () async {
      await db.setBudget(bizExp(biz), 1000000);
      final biz1 = await db.watchBudgetProgress(may, ledgerId: biz).first;
      final stok = biz1.firstWhere((b) => b.category.id == bizExp(biz));
      expect((stok.budget, stok.spent), (1000000, 200000));
      // Buku Utama tidak memuat kategori bisnis.
      final main = await db.watchBudgetProgress(may).first;
      expect(main.any((b) => b.category.ledgerId != kMainLedgerId), isFalse);
      // null = semua buku.
      final all = await db.watchBudgetProgress(may, ledgerId: null).first;
      expect(all.map((b) => b.category.ledgerId).toSet(), {kMainLedgerId, biz});
    });

    test('total saldo per buku (untuk pengalih)', () async {
      expect(await db.watchLedgerBalances().first, {
        kMainLedgerId: 470000,
        biz: 700000,
      });
    });

    test('target, agenda, utang, dan aturan berulang terpisah', () async {
      await db.addGoal(
        name: 'G-main',
        targetAmount: 1000,
        icon: 'savings',
        color: 1,
      );
      await db.addGoal(
        name: 'G-biz',
        targetAmount: 1000,
        icon: 'savings',
        color: 1,
        ledgerId: biz,
      );
      expect((await db.watchGoals().first).map((g) => g.goal.name), ['G-main']);
      expect(
        (await db.watchGoals(ledgerId: biz).first).map((g) => g.goal.name),
        ['G-biz'],
      );
      expect((await db.watchGoals(ledgerId: null).first).length, 2);

      await db.addAgenda(
        title: 'A-biz',
        frequency: Frequency.monthly,
        startDate: day,
        ledgerId: biz,
      );
      expect(await db.watchAgendaReminders().first, isEmpty);
      expect((await db.watchAgendaReminders(ledgerId: biz).first).length, 1);
      expect((await db.watchAgendaReminders(ledgerId: null).first).length, 1);

      await db.addDebt(
        type: DebtType.debt,
        counterpartyName: 'Supplier',
        amount: 5000,
        ledgerId: biz,
      );
      expect(await db.watchDebts().first, isEmpty);
      expect((await db.watchDebts(ledgerId: biz).first).length, 1);

      await db.addRecurringRule(
        type: TxType.expense,
        amount: 1000,
        accountId: bizAcc(biz),
        categoryId: bizExp(biz, 'sewa'),
        frequency: Frequency.monthly,
        startDate: day,
      );
      expect(await db.watchRecurringRules().first, isEmpty);
      expect((await db.watchRecurringRules(ledgerId: biz).first).length, 1);
      expect((await db.watchRecurringRules(ledgerId: null).first).length, 1);
    });

    test('dompet dan kategori boleh bernama sama di buku berbeda', () async {
      await db.addAccount(name: 'BCA', kind: AccountKind.bank);
      await db.addAccount(name: 'BCA', kind: AccountKind.bank, ledgerId: biz);
      await db.addCategory(
        type: TxType.expense,
        name: 'Parkir',
        icon: 'car',
        color: 1,
      );
      await db.addCategory(
        type: TxType.expense,
        name: 'Parkir',
        icon: 'car',
        color: 1,
        ledgerId: biz,
      );
      // Tetap unik di dalam satu buku.
      await expectLater(
        db.addAccount(name: 'bca', kind: AccountKind.bank, ledgerId: biz),
        throwsA(isA<AccountException>()),
      );
    });
  });

  group('aturan satu buku', () {
    late String biz;
    setUp(() async => biz = await addBiz());

    test('transaksi: dompet dan kategori harus satu buku', () async {
      await expectLater(
        db.addTransaction(
          type: TxType.expense,
          amount: 1000,
          accountId: 'acc-tunai',
          categoryId: bizExp(biz),
          date: day,
        ),
        ledgerError(contains('buku kas yang sama')),
      );
      await expectLater(
        db.addTransaction(
          type: TxType.expense,
          amount: 1000,
          accountId: bizAcc(biz),
          categoryId: 'cat-exp-makan',
          date: day,
        ),
        ledgerError(),
      );
    });

    test('transfer hanya antar dompet satu buku', () async {
      await expectLater(
        db.addTransaction(
          type: TxType.transfer,
          amount: 1000,
          accountId: 'acc-tunai',
          transferToAccountId: bizAcc(biz),
          date: day,
        ),
        ledgerError(),
      );
      // Antar dompet satu buku tetap boleh.
      await db.addAccount(name: 'Bank', kind: AccountKind.bank, ledgerId: biz);
      final other = (await db.watchAccountBalances(ledgerId: biz).first)
          .firstWhere((a) => a.name == 'Bank')
          .id;
      await db.addTransaction(
        type: TxType.transfer,
        amount: 1000,
        accountId: bizAcc(biz),
        transferToAccountId: other,
        date: day,
      );
    });

    test('mengubah transaksi ke dompet buku lain ditolak', () async {
      final id = await db.addTransaction(
        type: TxType.expense,
        amount: 1000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: day,
      );
      await expectLater(
        db.updateTransaction(
          id: id,
          type: TxType.expense,
          amount: 1000,
          accountId: bizAcc(biz),
          categoryId: 'cat-exp-makan',
          date: day,
        ),
        ledgerError(),
      );
    });

    test('aturan berulang lintas buku ditolak (tambah dan ubah)', () async {
      await expectLater(
        db.addRecurringRule(
          type: TxType.expense,
          amount: 1000,
          accountId: 'acc-tunai',
          categoryId: bizExp(biz),
          frequency: Frequency.monthly,
          startDate: day,
        ),
        ledgerError(),
      );
      final ruleId = await db.addRecurringRule(
        type: TxType.expense,
        amount: 1000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        frequency: Frequency.monthly,
        startDate: day,
      );
      await expectLater(
        db.updateRecurringRule(
          id: ruleId,
          type: TxType.expense,
          amount: 1000,
          accountId: bizAcc(biz),
          categoryId: 'cat-exp-makan',
        ),
        ledgerError(),
      );
    });

    test(
      'eksekusi agenda dan pembayaran utang harus di buku pemiliknya',
      () async {
        final agenda = await db.addAgenda(
          title: 'Pajak',
          frequency: Frequency.monthly,
          startDate: day,
          ledgerId: biz,
        );
        await expectLater(
          db.executeAgenda(
            agendaId: agenda,
            amount: 1000,
            accountId: 'acc-tunai',
            categoryId: 'cat-exp-makan',
            date: day,
          ),
          ledgerError(),
        );
        await db.executeAgenda(
          agendaId: agenda,
          amount: 1000,
          accountId: bizAcc(biz),
          categoryId: bizExp(biz, 'pajak'),
          date: day,
        );

        final debt = await db.addDebt(
          type: DebtType.debt,
          counterpartyName: 'Supplier',
          amount: 5000,
          ledgerId: biz,
        );
        await expectLater(
          db.recordDebtPayment(
            debtId: debt,
            amount: 1000,
            accountId: 'acc-tunai',
            categoryId: 'cat-exp-utang',
            date: day,
          ),
          ledgerError(),
        );
        await db.recordDebtPayment(
          debtId: debt,
          amount: 1000,
          accountId: bizAcc(biz),
          categoryId: debtCategoryId(biz, DebtType.debt),
          date: day,
        );
        expect(
          (await db.watchDebts(ledgerId: biz).first).single.paidAmount,
          1000,
        );
      },
    );

    test('utang dengan dompet buku lain ditolak', () async {
      await expectLater(
        db.addDebt(
          type: DebtType.debt,
          counterpartyName: 'X',
          amount: 1000,
          accountId: 'acc-tunai',
          ledgerId: biz,
        ),
        ledgerError(),
      );
    });

    test('sub-kategori harus satu buku dengan induknya', () async {
      await expectLater(
        db.addCategory(
          type: TxType.expense,
          name: 'Anak',
          icon: 'food',
          color: 1,
          parentId: 'cat-exp-makan',
          ledgerId: biz,
        ),
        throwsA(isA<CategoryException>()),
      );
      await db.addCategory(
        type: TxType.expense,
        name: 'Anak',
        icon: 'food',
        color: 1,
        parentId: bizExp(biz),
        ledgerId: biz,
      );
    });

    test('minimal satu dompet/kategori aktif dihitung per buku', () async {
      // Buku Utama punya banyak; buku Bisnis hanya satu dompet.
      await expectLater(
        db.setAccountArchived(bizAcc(biz), archived: true),
        throwsA(isA<AccountException>()),
      );
      await db.addAccount(name: 'Kedua', kind: AccountKind.cash);
      // Menambah dompet di Buku Utama tidak membantu buku Bisnis.
      await expectLater(
        db.setAccountArchived(bizAcc(biz), archived: true),
        throwsA(isA<AccountException>()),
      );

      // Kategori: arsipkan semua pengeluaran bisnis kecuali satu.
      final exp = await db.watchCategories(TxType.expense, ledgerId: biz).first;
      for (final c in exp.skip(1)) {
        await db.setCategoryArchived(c.id, archived: true);
      }
      await expectLater(
        db.setCategoryArchived(exp.first.id, archived: true),
        throwsA(isA<CategoryException>()),
      );
    });
  });

  group('operasi lintas buku', () {
    test('generateDueRecurring berlaku untuk semua buku', () async {
      final biz = await addBiz();
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 1000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 5, 1),
      );
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 2000,
        accountId: bizAcc(biz),
        categoryId: bizExp(biz, 'sewa'),
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 5, 1),
      );
      expect(await db.generateDueRecurring(now: DateTime(2026, 5, 2)), 2);
      expect((await db.getTransactions(ledgerId: biz)).single.tx.amount, 2000);
      expect((await db.getTransactions(ledgerId: kMainLedgerId)).length, 1);
    });

    test(
      'buku yang dijeda tidak menghasilkan transaksi dan disusul saat dibuka',
      () async {
        final biz = await addBiz();
        await db.addRecurringRule(
          type: TxType.expense,
          amount: 2000,
          accountId: bizAcc(biz),
          categoryId: bizExp(biz, 'sewa'),
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 5, 1),
        );
        expect(
          await db.generateDueRecurring(
            now: DateTime(2026, 7, 2),
            pausedLedgerIds: {biz},
          ),
          0,
        );
        expect(await db.getTransactions(ledgerId: biz), isEmpty);
        // Dibuka lagi: Mei, Juni, Juli disusul.
        expect(await db.generateDueRecurring(now: DateTime(2026, 7, 2)), 3);
      },
    );

    test('deleteLedger menghapus seluruh isi buku itu saja', () async {
      final biz = await addBiz();
      final tag = await db.addTag('promo');
      final tx = await db.addTransaction(
        type: TxType.expense,
        amount: 5000,
        accountId: bizAcc(biz),
        categoryId: bizExp(biz),
        date: day,
      );
      await db.setTransactionTags(tx, [tag]);
      await db.setBudget(bizExp(biz), 100000);
      final goal = await db.addGoal(
        name: 'G',
        targetAmount: 1000,
        icon: 'savings',
        color: 1,
        ledgerId: biz,
      );
      await db.addContribution(
        goalId: goal,
        kind: ContributionKind.deposit,
        amount: 100,
      );
      await db.addAgenda(
        title: 'A',
        frequency: Frequency.monthly,
        startDate: day,
        ledgerId: biz,
      );
      await db.addDebt(
        type: DebtType.debt,
        counterpartyName: 'S',
        amount: 100,
        ledgerId: biz,
      );
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 1,
        accountId: bizAcc(biz),
        categoryId: bizExp(biz),
        frequency: Frequency.monthly,
        startDate: day,
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: 7000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: day,
      );

      final usage = await db.ledgerUsage(biz);
      expect((usage.transactions, usage.accounts), (1, 1));

      await db.deleteLedger(biz);

      expect((await db.watchLedgers().first).map((l) => l.id), [kMainLedgerId]);
      expect(await db.watchAccountBalances(ledgerId: biz).first, isEmpty);
      expect(await db.watchGoals(ledgerId: biz).first, isEmpty);
      expect(await db.watchDebts(ledgerId: biz).first, isEmpty);
      expect(await db.watchAgendaReminders(ledgerId: biz).first, isEmpty);
      expect(await db.watchRecurringRules(ledgerId: biz).first, isEmpty);
      expect(
        await db.watchCategories(TxType.expense, ledgerId: biz).first,
        isEmpty,
      );
      expect(await db.watchTransactions(may, ledgerId: biz).first, isEmpty);
      // Tag global tetap ada; Buku Utama utuh.
      expect((await db.watchTags().first).length, 1);
      expect((await db.getTransactions()).single.tx.amount, 7000);
      await expectLater(
        db.deleteLedger(biz),
        ledgerError(contains('tidak ditemukan')),
      );
    });

    test('eraseAllData mengembalikan ke satu Buku Utama seed', () async {
      final biz = await addBiz();
      await db.addTransaction(
        type: TxType.expense,
        amount: 1,
        accountId: bizAcc(biz),
        categoryId: bizExp(biz),
        date: day,
      );
      await db.eraseAllData();
      expect((await db.watchLedgers().first).map((l) => l.id), [kMainLedgerId]);
      expect(
        (await db.watchAccountBalances(ledgerId: null).first).map((a) => a.id),
        ['acc-tunai'],
      );
      expect(await db.getTransactions(), isEmpty);
    });
  });

  group('backup', () {
    Future<String> exportTwoLedgers() async {
      final biz = await addBiz();
      await db.addTransaction(
        type: TxType.expense,
        amount: 12000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: day,
      );
      await db.addTransaction(
        type: TxType.income,
        amount: 34000,
        accountId: bizAcc(biz),
        categoryId: bizInc(biz),
        date: day,
      );
      await db.addGoal(
        name: 'G',
        targetAmount: 1000,
        icon: 'savings',
        color: 1,
        ledgerId: biz,
      );
      return BackupService(db).export();
    }

    test(
      'format v${BackupService.formatVersion}: dua buku bolak-balik utuh',
      () async {
        final json = await exportTwoLedgers();
        expect(jsonDecode(json)['version'], BackupService.formatVersion);

        final data = BackupService.parse(json);
        expect(data.ledgers.length, 2);

        final fresh = AppDatabase(NativeDatabase.memory());
        addTearDown(fresh.close);
        await BackupService(fresh).restore(data);

        final ledgers = await fresh.watchLedgers().first;
        expect(ledgers.length, 2);
        final bizId = ledgers.firstWhere((l) => l.id != kMainLedgerId).id;
        expect(await fresh.watchTotals(may).first, (income: 0, expense: 12000));
        expect(await fresh.watchTotals(may, ledgerId: bizId).first, (
          income: 34000,
          expense: 0,
        ));
        expect((await fresh.watchGoals(ledgerId: bizId).first).length, 1);
        // Pemulihan menghasilkan backup yang identik.
        expect(
          (jsonDecode(await BackupService(fresh).export()) as Map)['accounts'],
          (jsonDecode(json) as Map)['accounts'],
        );
      },
    );

    test(
      'backup lama (v6, tanpa ledgers/ledgerId) masuk ke Buku Utama',
      () async {
        await db.addTransaction(
          type: TxType.expense,
          amount: 12000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-makan',
          date: day,
        );
        final map = jsonDecode(
          await BackupService(db).export(),
        ) as Map<String, dynamic>;
        map['version'] = 6;
        map.remove('ledgers');
        for (final key in [
          'accounts',
          'categories',
          'savingsGoals',
          'agendaReminders',
          'debts',
        ]) {
          for (final row in map[key] as List) {
            (row as Map).remove('ledgerId');
          }
        }

        final data = BackupService.parse(jsonEncode(map));
        expect(data.ledgers.map((l) => l.id), [kMainLedgerId]);
        expect(data.accounts.every((a) => a.ledgerId == kMainLedgerId), isTrue);
        expect(
          data.categories.every((c) => c.ledgerId == kMainLedgerId),
          isTrue,
        );

        final fresh = AppDatabase(NativeDatabase.memory());
        addTearDown(fresh.close);
        await BackupService(fresh).restore(data);
        expect(await fresh.watchTotals(may).first, (income: 0, expense: 12000));
      },
    );

    test('backup lebih baru dari aplikasi tetap ditolak', () async {
      final map =
          jsonDecode(await BackupService(db).export()) as Map<String, dynamic>;
      map['version'] = BackupService.formatVersion + 1;
      expect(
        () => BackupService.parse(jsonEncode(map)),
        throwsA(isA<BackupException>()),
      );
    });

    test('integritas: transaksi lintas buku, referensi buku hilang, tanpa Buku Utama', () async {
      final json = await exportTwoLedgers();
      Map<String, dynamic> fresh() => jsonDecode(json) as Map<String, dynamic>;

      // Transaksi memakai dompet Buku Utama tetapi kategori buku Bisnis.
      final cross = fresh();
      final tx = (cross['transactions'] as List).firstWhere(
        (t) => (t as Map)['type'] == 1,
      ) as Map;
      tx['categoryId'] = (cross['categories'] as List).cast<Map>().firstWhere(
        (c) => c['ledgerId'] != kMainLedgerId && c['type'] == 1,
      )['id'];
      expect(
        () => BackupService.parse(jsonEncode(cross)),
        throwsA(isA<BackupException>()),
      );

      // Dompet menunjuk buku yang tidak ada.
      final dangling = fresh();
      ((dangling['accounts'] as List).first as Map)['ledgerId'] =
          'ledger-hantu';
      expect(
        () => BackupService.parse(jsonEncode(dangling)),
        throwsA(isA<BackupException>()),
      );

      // Buku Utama hilang dari daftar.
      final noMain = fresh();
      (noMain['ledgers'] as List).removeWhere(
        (l) => (l as Map)['id'] == kMainLedgerId,
      );
      expect(
        () => BackupService.parse(jsonEncode(noMain)),
        throwsA(isA<BackupException>()),
      );

      // ID buku ganda.
      final dup = fresh();
      (dup['ledgers'] as List).add(
        Map.of((dup['ledgers'] as List).first as Map),
      );
      expect(
        () => BackupService.parse(jsonEncode(dup)),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
