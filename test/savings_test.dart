import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tabungan berdompet: setoran = pengeluaran dompet asal, penarikan =
/// pemasukan dompet tujuan; saldo tabungan terpisah dari saldo dompet.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> walletBalance([String id = 'acc-tunai']) async =>
      (await db.watchAccountBalances().first)
          .firstWhere((a) => a.id == id)
          .balance;

  Future<SavingsView> savingsView(String id) async =>
      (await db.watchSavings().first).firstWhere((s) => s.savings.id == id);

  Future<String> newSavings([String name = 'Dana Darurat']) =>
      db.addSavings(name: name, icon: 'savings', color: 0xFF00897B);

  Future<void> fundWallet(int amount) => db.updateAccount(
    id: 'acc-tunai',
    name: 'Tunai',
    kind: AccountKind.cash,
    initialBalance: amount,
  );

  final day = DateTime(2026, 5, 10);

  test('setoran: pengeluaran dompet asal, saldo tabungan naik', () async {
    await fundWallet(1000000);
    final id = await newSavings();

    final txId = await db.depositToSavings(
      savingsId: id,
      accountId: 'acc-tunai',
      amount: 300000,
      date: day,
    );

    expect(await walletBalance(), 700000);
    final v = await savingsView(id);
    expect((v.balance, v.deposited, v.withdrawn), (300000, 300000, 0));

    final tx = (await db.getTransactions()).single.tx;
    expect(tx.id, txId);
    expect(tx.type, TxType.expense);
    expect(tx.amount, 300000);
    expect(tx.savingsId, id);
    expect(tx.note, 'Setoran ke Dana Darurat');
    final cat = (await db.getTransactions()).single.category!;
    expect((cat.name, cat.type), ('Tabungan', TxType.expense));
  });

  test('penarikan: pemasukan dompet tujuan, saldo tabungan turun', () async {
    await fundWallet(1000000);
    await db.addAccount(name: 'BCA', kind: AccountKind.bank);
    final bca = (await db.watchAccountBalances().first)
        .firstWhere((a) => a.name == 'BCA')
        .id;
    final id = await newSavings();
    await db.depositToSavings(
      savingsId: id,
      accountId: 'acc-tunai',
      amount: 500000,
      date: day,
    );

    await db.withdrawFromSavings(
      savingsId: id,
      accountId: bca,
      amount: 200000,
      date: day,
      note: 'Servis motor',
    );

    expect(await walletBalance(), 500000); // dompet asal tidak ikut berubah
    expect(await walletBalance(bca), 200000);
    final v = await savingsView(id);
    expect((v.balance, v.deposited, v.withdrawn), (300000, 500000, 200000));
    final withdrawal = (await db.getTransactions())
        .map((e) => e.tx)
        .firstWhere((t) => t.type == TxType.income);
    expect((withdrawal.note, withdrawal.savingsId), ('Servis motor', id));
    final cat = (await db.getTransactions())
        .firstWhere((e) => e.tx.id == withdrawal.id)
        .category!;
    expect((cat.name, cat.type), ('Tabungan', TxType.income));
  });

  test('penarikan melebihi saldo tabungan ditolak', () async {
    final id = await newSavings();
    await db.depositToSavings(
      savingsId: id,
      accountId: 'acc-tunai',
      amount: 100000,
      date: day,
    );
    await expectLater(
      db.withdrawFromSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 100001,
        date: day,
      ),
      throwsA(isA<SavingsException>()),
    );
    expect((await savingsView(id)).balance, 100000);
    await expectLater(
      db.withdrawFromSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 0,
        date: day,
      ),
      throwsA(isA<SavingsException>()),
    );
  });

  test(
    'saldo tabungan tidak ikut Total Saldo dompet, antar tabungan terpisah',
    () async {
      await fundWallet(1000000);
      final a = await newSavings('A');
      final b = await newSavings('B');
      await db.depositToSavings(
        savingsId: a,
        accountId: 'acc-tunai',
        amount: 100000,
        date: day,
      );
      await db.depositToSavings(
        savingsId: b,
        accountId: 'acc-tunai',
        amount: 50000,
        date: day,
      );
      expect((await savingsView(a)).balance, 100000);
      expect((await savingsView(b)).balance, 50000);
      expect(await walletBalance(), 850000);
    },
  );

  test(
    'hapus setoran mengembalikan saldo dompet; ditolak bila saldo negatif',
    () async {
      await fundWallet(1000000);
      final id = await newSavings();
      final dep = await db.depositToSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 400000,
        date: day,
      );
      expect(await walletBalance(), 600000);

      await db.setSavingsEntryDeleted(dep, deleted: true);
      expect(await walletBalance(), 1000000);
      expect((await savingsView(id)).balance, 0);
      await db.setSavingsEntryDeleted(dep, deleted: false);
      expect((await savingsView(id)).balance, 400000);

      await db.withdrawFromSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 300000,
        date: day,
      );
      // Setoran sudah sebagian ditarik: menghapusnya membuat saldo negatif.
      await expectLater(
        db.setSavingsEntryDeleted(dep, deleted: true),
        throwsA(isA<SavingsException>()),
      );
      expect((await savingsView(id)).balance, 100000);
    },
  );

  test(
    'transaksi tabungan tidak bisa diubah/dihapus lewat jalur biasa',
    () async {
      final id = await newSavings();
      final dep = await db.depositToSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 50000,
        date: day,
      );
      await expectLater(
        db.setTransactionDeleted(dep, deleted: true),
        throwsA(isA<SavingsException>()),
      );
      await expectLater(
        db.updateTransaction(
          id: dep,
          type: TxType.income,
          amount: 1,
          accountId: 'acc-tunai',
          categoryId: 'cat-inc-gaji',
          date: day,
        ),
        throwsA(isA<SavingsException>()),
      );
      expect((await savingsView(id)).balance, 50000);
    },
  );

  test(
    'arsip hanya saat saldo kosong; tabungan terarsip menolak setoran',
    () async {
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 10000,
        date: day,
      );
      await expectLater(
        db.setSavingsArchived(id, archived: true),
        throwsA(isA<SavingsException>()),
      );
      await db.withdrawFromSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 10000,
        date: day,
      );
      await db.setSavingsArchived(id, archived: true);
      await expectLater(
        db.depositToSavings(
          savingsId: id,
          accountId: 'acc-tunai',
          amount: 1,
          date: day,
        ),
        throwsA(isA<SavingsException>()),
      );
      await db.setSavingsArchived(id, archived: false);
    },
  );

  test('hapus tabungan: hanya yang belum punya riwayat', () async {
    final unused = await newSavings('Kosong');
    await db.deleteSavings(unused);
    expect(await db.watchSavings().first, isEmpty);

    final used = await newSavings('Dipakai');
    await db.depositToSavings(
      savingsId: used,
      accountId: 'acc-tunai',
      amount: 1000,
      date: day,
    );
    await expectLater(db.deleteSavings(used), throwsA(isA<SavingsException>()));
  });

  test('nama tabungan wajib dan unik per buku', () async {
    await newSavings('Liburan');
    await expectLater(
      db.addSavings(name: ' liburan ', icon: 'savings', color: 1),
      throwsA(isA<SavingsException>()),
    );
    await expectLater(
      db.addSavings(name: '  ', icon: 'savings', color: 1),
      throwsA(isA<SavingsException>()),
    );
  });

  test(
    'kategori Tabungan buatan pengguna dipakai ulang, tidak ganda',
    () async {
      await db.addCategory(
        type: TxType.expense,
        name: 'tabungan',
        icon: 'other',
        color: 1,
      );
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 1000,
        date: day,
      );
      final cats = (await db.watchCategories(TxType.expense).first).where(
        (c) => c.name.toLowerCase() == 'tabungan',
      );
      expect(cats, hasLength(1));
    },
  );

  test('buku kas: dompet harus se-buku dengan tabungan', () async {
    final other = await db.addLedger(
      name: 'Bisnis',
      icon: 'savings',
      color: 1,
      template: LedgerTemplate.business,
    );
    final id = await newSavings(); // Buku Utama
    await expectLater(
      db.depositToSavings(
        savingsId: id,
        accountId: ledgerSeedId(other, 'acc-tunai'),
        amount: 1000,
        date: day,
      ),
      throwsA(isA<SavingsException>()),
    );

    // Tabungan di buku lain terpisah dari Buku Utama, kategorinya milik buku itu.
    final biz = await db.addSavings(
      name: 'Cadangan',
      icon: 'savings',
      color: 1,
      ledgerId: other,
    );
    await db.depositToSavings(
      savingsId: biz,
      accountId: ledgerSeedId(other, 'acc-tunai'),
      amount: 5000,
      date: day,
    );
    expect((await db.watchSavings().first).single.balance, 0); // Buku Utama
    expect((await db.watchSavings(ledgerId: other).first).single.balance, 5000);

    // Menghapus buku ikut menghapus tabungannya.
    await db.deleteLedger(other);
    final left = await db.watchSavings(ledgerId: null).first;
    expect(left.map((s) => s.savings.name), ['Dana Darurat']);
  });

  test('backup: tabungan dan transaksinya utuh bolak-balik', () async {
    await fundWallet(1000000);
    final id = await newSavings();
    await db.depositToSavings(
      savingsId: id,
      accountId: 'acc-tunai',
      amount: 250000,
      date: day,
    );
    final json = await BackupService(db).export();
    expect(jsonDecode(json)['savingsAccounts'], hasLength(1));

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await BackupService(other).restore(BackupService.parse(json));
    final v = (await other.watchSavings().first).single;
    expect((v.savings.name, v.balance), ('Dana Darurat', 250000));
    expect(
      (await other.watchAccountBalances().first)
          .firstWhere((a) => a.id == 'acc-tunai')
          .balance,
      750000,
    );
  });

  test('backup: transaksi tabungan menggantung/negatif ditolak', () async {
    final id = await newSavings();
    await db.depositToSavings(
      savingsId: id,
      accountId: 'acc-tunai',
      amount: 1000,
      date: day,
    );
    final map =
        jsonDecode(await BackupService(db).export()) as Map<String, dynamic>;

    final dangling = jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
    dangling['savingsAccounts'] = [];
    expect(
      () => BackupService.parse(jsonEncode(dangling)),
      throwsA(isA<BackupException>()),
    );

    // Penarikan tanpa setoran -> saldo negatif.
    final negative = jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
    for (final t in negative['transactions'] as List) {
      if (t['savingsId'] != null) {
        t['type'] = TxType.income.index;
        t['categoryId'] = 'cat-inc-gaji';
      }
    }
    expect(
      () => BackupService.parse(jsonEncode(negative)),
      throwsA(isA<BackupException>()),
    );
  });

  test('backup lama tanpa savingsAccounts tetap bisa dipulihkan', () async {
    final map =
        jsonDecode(await BackupService(db).export()) as Map<String, dynamic>
          ..remove('savingsAccounts')
          ..['version'] = 7;
    final data = BackupService.parse(jsonEncode(map));
    expect(data.savingsAccounts, isEmpty);
  });
}
