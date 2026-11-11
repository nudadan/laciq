import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Setoran/penarikan tabungan ke/dari "Lainnya" (di luar dompet pengguna, mis.
/// transfer ke rekening orang lain atau bayar tagihan): hanya menggeser saldo
/// tabungan; saldo dompet dan transaksi dompet tidak tersentuh.
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

  group('saldo tabungan', () {
    test(
      'setoran dari Lainnya: saldo tabungan naik, dompet dan transaksi tidak '
      'berubah',
      () async {
        await fundWallet(1000000);
        final id = await newSavings();

        final entryId = await db.depositToSavings(
          savingsId: id,
          accountId: null,
          amount: 250000,
          date: day,
          note: 'Dikirim kakak',
        );

        final v = await savingsView(id);
        expect((v.balance, v.deposited, v.withdrawn), (250000, 250000, 0));
        expect(await walletBalance(), 1000000);
        // Bukan transaksi dompet: tidak muncul sebagai pengeluaran/pemasukan.
        expect(await db.getTransactions(), isEmpty);
        final row = (await db.select(db.savingsExternalEntries).get()).single;
        expect(row.id, entryId);
        expect((row.savingsId, row.deposit, row.amount), (id, true, 250000));
        expect(row.note, 'Dikirim kakak');
      },
    );

    test('penarikan ke Lainnya: saldo tabungan turun, dompet dan transaksi '
        'tidak berubah', () async {
      await fundWallet(1000000);
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 500000,
        date: day,
      );
      expect(await walletBalance(), 500000);

      await db.withdrawFromSavings(
        savingsId: id,
        accountId: null,
        amount: 200000,
        date: day,
        note: 'Bayar listrik',
      );

      final v = await savingsView(id);
      expect((v.balance, v.deposited, v.withdrawn), (300000, 500000, 200000));
      // Dompet tetap 500.000: hanya setoran dompet yang mengurangi saldonya.
      expect(await walletBalance(), 500000);
      // Hanya transaksi setoran dompet; penarikan ke Lainnya bukan pemasukan.
      final txs = await db.getTransactions();
      expect(txs.single.tx.type, TxType.expense);
      expect(txs.single.tx.amount, 500000);
    });

    test('saldo gabungan dompet dan Lainnya dihitung benar', () async {
      await fundWallet(1000000);
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 100000,
        date: day,
      );
      await db.depositToSavings(
        savingsId: id,
        accountId: null,
        amount: 50000,
        date: day,
      );
      await db.withdrawFromSavings(
        savingsId: id,
        accountId: null,
        amount: 120000,
        date: day,
      );
      await db.withdrawFromSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 10000,
        date: day,
      );

      final v = await savingsView(id);
      expect(v.deposited, 150000);
      expect(v.withdrawn, 130000);
      expect(v.balance, 20000);
      // Dompet: -100.000 (setoran) +10.000 (penarikan); Lainnya tak menyentuhnya.
      expect(await walletBalance(), 910000);
    });

    test('penarikan ke Lainnya tidak boleh melebihi saldo tabungan', () async {
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: null,
        amount: 80000,
        date: day,
      );

      await expectLater(
        db.withdrawFromSavings(
          savingsId: id,
          accountId: null,
          amount: 80001,
          date: day,
        ),
        throwsA(
          isA<SavingsException>().having(
            (e) => e.message,
            'message',
            contains('Saldo tabungan hanya'),
          ),
        ),
      );
      expect((await savingsView(id)).balance, 80000);
      // Pas sebesar saldo boleh.
      await db.withdrawFromSavings(
        savingsId: id,
        accountId: null,
        amount: 80000,
        date: day,
      );
      expect((await savingsView(id)).balance, 0);
    });

    test('nominal harus positif dan tidak melebihi batas', () async {
      final id = await newSavings();
      await expectLater(
        db.depositToSavings(
          savingsId: id,
          accountId: null,
          amount: 0,
          date: day,
        ),
        throwsA(isA<SavingsException>()),
      );
      await expectLater(
        db.depositToSavings(
          savingsId: id,
          accountId: null,
          amount: AppDatabase.maxAccountBalance + 1,
          date: day,
        ),
        throwsA(isA<SavingsException>()),
      );
      expect(await db.select(db.savingsExternalEntries).get(), isEmpty);
    });

    test('tabungan diarsipkan menolak setoran/penarikan Lainnya', () async {
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: null,
        amount: 10000,
        date: day,
      );
      // Aturan lama: tabungan berisi saldo tidak bisa diarsipkan. Saldo dari
      // setoran Lainnya ikut dihitung.
      await expectLater(
        db.setSavingsArchived(id, archived: true),
        throwsA(isA<SavingsException>()),
      );
      await db.withdrawFromSavings(
        savingsId: id,
        accountId: null,
        amount: 10000,
        date: day,
      );
      await db.setSavingsArchived(id, archived: true);

      await expectLater(
        db.depositToSavings(
          savingsId: id,
          accountId: null,
          amount: 1000,
          date: day,
        ),
        throwsA(isA<SavingsException>()),
      );
      await expectLater(
        db.withdrawFromSavings(
          savingsId: id,
          accountId: null,
          amount: 1000,
          date: day,
        ),
        throwsA(isA<SavingsException>()),
      );
    });
  });

  group('riwayat', () {
    test('menggabungkan entri dompet dan Lainnya, terbaru dulu', () async {
      await fundWallet(1000000);
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 100000,
        date: DateTime(2026, 5, 1),
      );
      await db.depositToSavings(
        savingsId: id,
        accountId: null,
        amount: 40000,
        date: DateTime(2026, 5, 3),
        note: 'Transfer dari Ibu',
      );
      await db.withdrawFromSavings(
        savingsId: id,
        accountId: null,
        amount: 25000,
        date: DateTime(2026, 5, 5),
      );

      final list = await db.watchSavingsEntries(id).first;
      expect(list.map((e) => e.amount), [25000, 40000, 100000]);
      expect(list.map((e) => e.deposit), [false, true, true]);
      expect(list.map((e) => e.isExternal), [true, true, false]);
      expect(list.map((e) => e.accountName), [null, null, 'Tunai']);
      expect(list[1].note, 'Transfer dari Ibu');
      expect(list[2].accountId, 'acc-tunai');
    });

    test('entri yang dihapus lunak tidak tampil dan tidak dihitung', () async {
      final id = await newSavings();
      final dep = await db.depositToSavings(
        savingsId: id,
        accountId: null,
        amount: 70000,
        date: day,
      );

      await db.setSavingsEntryDeleted(dep, deleted: true);
      expect(await db.watchSavingsEntries(id).first, isEmpty);
      expect((await savingsView(id)).balance, 0);

      await db.setSavingsEntryDeleted(dep, deleted: false);
      expect((await db.watchSavingsEntries(id).first).single.amount, 70000);
      expect((await savingsView(id)).balance, 70000);
      // Mengulang status yang sama tidak mengubah apa pun.
      await db.setSavingsEntryDeleted(dep, deleted: false);
      expect((await savingsView(id)).balance, 70000);
    });

    test(
      'menghapus setoran Lainnya yang sudah sebagian ditarik ditolak',
      () async {
        final id = await newSavings();
        final dep = await db.depositToSavings(
          savingsId: id,
          accountId: null,
          amount: 100000,
          date: day,
        );
        final wd = await db.withdrawFromSavings(
          savingsId: id,
          accountId: null,
          amount: 60000,
          date: day,
        );

        await expectLater(
          db.setSavingsEntryDeleted(dep, deleted: true),
          throwsA(isA<SavingsException>()),
        );
        expect((await savingsView(id)).balance, 40000);

        // Menghapus penarikannya dulu membuka jalan.
        await db.setSavingsEntryDeleted(wd, deleted: true);
        await db.setSavingsEntryDeleted(dep, deleted: true);
        expect((await savingsView(id)).balance, 0);
      },
    );

    test('ID yang tidak dikenal tetap melempar StateError', () async {
      await expectLater(
        db.setSavingsEntryDeleted('tidak-ada', deleted: true),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('siklus hidup tabungan', () {
    test(
      'tabungan yang punya entri Lainnya tidak bisa dihapus permanen',
      () async {
        final id = await newSavings();
        final empty = await newSavings('Kosong');
        final dep = await db.depositToSavings(
          savingsId: id,
          accountId: null,
          amount: 5000,
          date: day,
        );
        // Termasuk yang sudah dihapus lunak: riwayatnya tetap ada.
        await db.setSavingsEntryDeleted(dep, deleted: true);

        await expectLater(
          db.deleteSavings(id),
          throwsA(isA<SavingsException>()),
        );
        await db.deleteSavings(empty); // yang belum pernah dipakai tetap bisa
        expect((await db.watchSavings().first).map((s) => s.savings.id), [id]);
      },
    );

    test(
      'menghapus buku kas ikut menghapus entri Lainnya tabungannya',
      () async {
        final ledger = await db.addLedger(
          name: 'Toko',
          icon: 'business',
          color: 0xFF455A64,
        );
        final savings = await db.addSavings(
          name: 'Modal',
          icon: 'savings',
          color: 0xFF00897B,
          ledgerId: ledger,
        );
        await db.depositToSavings(
          savingsId: savings,
          accountId: null,
          amount: 90000,
          date: day,
        );
        expect(await db.select(db.savingsExternalEntries).get(), hasLength(1));

        // Foreign key aktif: gagal bila entri tidak ikut dihapus.
        await db.deleteLedger(ledger);

        expect(await db.select(db.savingsExternalEntries).get(), isEmpty);
        expect(await db.select(db.savingsAccounts).get(), isEmpty);
      },
    );

    test('hapus semua data juga mengosongkan entri Lainnya', () async {
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: null,
        amount: 5000,
        date: day,
      );

      await db.eraseAllData();

      expect(await db.select(db.savingsExternalEntries).get(), isEmpty);
      expect(await db.select(db.savingsAccounts).get(), isEmpty);
    });
  });

  group('backup', () {
    Future<Map<String, dynamic>> exported() async =>
        jsonDecode(await BackupService(db).export()) as Map<String, dynamic>;

    test(
      'backup memuat entri Lainnya (format v10) dan bisa dipulihkan',
      () async {
        await fundWallet(1000000);
        final id = await newSavings();
        await db.depositToSavings(
          savingsId: id,
          accountId: 'acc-tunai',
          amount: 100000,
          date: day,
        );
        await db.depositToSavings(
          savingsId: id,
          accountId: null,
          amount: 50000,
          date: day,
          note: 'Dari Ayah',
        );
        await db.withdrawFromSavings(
          savingsId: id,
          accountId: null,
          amount: 30000,
          date: day,
        );
        final json = await BackupService(db).export();
        final m = jsonDecode(json) as Map<String, dynamic>;
        expect(m['version'], 10);
        expect(m['savingsExternalEntries'], hasLength(2));

        final other = AppDatabase(NativeDatabase.memory());
        addTearDown(other.close);
        await BackupService(other).restore(BackupService.parse(json));

        final v = (await other.watchSavings().first).single;
        expect((v.balance, v.deposited, v.withdrawn), (120000, 150000, 30000));
        final entries = await other.watchSavingsEntries(v.savings.id).first;
        expect(entries.where((e) => e.isExternal), hasLength(2));
        expect(entries.firstWhere((e) => e.note == 'Dari Ayah').amount, 50000);
      },
    );

    test('backup lama tanpa entri Lainnya tetap bisa dipulihkan', () async {
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: 'acc-tunai',
        amount: 20000,
        date: day,
      );
      final m = await exported()
        ..['version'] = 9
        ..remove('savingsExternalEntries');

      final data = BackupService.parse(jsonEncode(m));

      expect(data.savingsExternalEntries, isEmpty);
      expect(data.savingsAccounts, hasLength(1));
    });

    Future<Map<String, dynamic>> withOneExternalEntry() async {
      final id = await newSavings();
      await db.depositToSavings(
        savingsId: id,
        accountId: null,
        amount: 50000,
        date: day,
      );
      return exported();
    }

    void expectCorrupt(Map<String, dynamic> m) => expect(
      () => BackupService.parse(jsonEncode(m)),
      throwsA(isA<BackupException>()),
    );

    test('entri Lainnya yang merujuk tabungan tak ada ditolak', () async {
      final m = await withOneExternalEntry();
      (m['savingsExternalEntries'] as List).first['savingsId'] = 'hantu';
      expectCorrupt(m);
    });

    test('entri Lainnya dengan nominal tidak positif ditolak', () async {
      final m = await withOneExternalEntry();
      (m['savingsExternalEntries'] as List).first['amount'] = 0;
      expectCorrupt(m);
    });

    test('ID entri Lainnya ganda ditolak', () async {
      final m = await withOneExternalEntry();
      final list = m['savingsExternalEntries'] as List;
      list.add(Map<String, dynamic>.from(list.first as Map));
      expectCorrupt(m);
    });

    test('penarikan Lainnya yang membuat saldo negatif ditolak', () async {
      final m = await withOneExternalEntry();
      // Setoran 50.000 diubah menjadi penarikan: saldo -50.000.
      (m['savingsExternalEntries'] as List).first['deposit'] = false;
      expectCorrupt(m);
    });

    test(
      'entri Lainnya yang sudah dihapus tidak dihitung dalam saldo',
      () async {
        final m = await withOneExternalEntry();
        final first = (m['savingsExternalEntries'] as List).first as Map;
        first['deposit'] = false; // akan membuat saldo negatif bila dihitung
        first['deletedAt'] = DateTime.now().toIso8601String();

        expect(
          BackupService.parse(jsonEncode(m)).savingsExternalEntries,
          hasLength(1),
        );
      },
    );
  });
}
