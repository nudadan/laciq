import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<AccountBalance>> active() => db.watchAccountBalances().first;
  Future<List<AccountBalance>> all() =>
      db.watchAccountBalances(includeArchived: true).first;
  Future<AccountBalance> byName(String name) async =>
      (await all()).firstWhere((a) => a.name == name);

  Matcher accountError(Matcher msg) =>
      throwsA(isA<AccountException>().having((e) => e.message, 'message', msg));

  Future<String> addBca({int initial = 1000000}) async {
    await db.addAccount(
      name: 'BCA',
      kind: AccountKind.bank,
      initialBalance: initial,
    );
    return (await byName('BCA')).id;
  }

  group('tambah', () {
    test('nama dirapikan; nama kembar (tanpa beda huruf) ditolak', () async {
      await db.addAccount(name: '  Go   Pay ', kind: AccountKind.ewallet);
      expect((await byName('Go Pay')).kind, AccountKind.ewallet);

      await expectLater(
        db.addAccount(name: 'go pay', kind: AccountKind.cash),
        accountError(contains('Sudah ada dompet "go pay"')),
      );
      // Dompet bawaan juga dihitung.
      await expectLater(
        db.addAccount(name: 'TUNAI', kind: AccountKind.cash),
        accountError(contains('Sudah ada')),
      );
      expect(await all(), hasLength(2));
    });

    test(
      'nama kosong, terlalu panjang, dan saldo awal tak valid ditolak',
      () async {
        await expectLater(
          db.addAccount(name: '   ', kind: AccountKind.cash),
          accountError(equals('Nama dompet wajib diisi.')),
        );
        await expectLater(
          db.addAccount(name: 'x' * 61, kind: AccountKind.cash),
          accountError(equals('Nama dompet maksimal 60 karakter.')),
        );
        await expectLater(
          db.addAccount(name: 'A', kind: AccountKind.cash, initialBalance: -1),
          accountError(equals('Saldo awal tidak valid.')),
        );
        await expectLater(
          db.addAccount(
            name: 'A',
            kind: AccountKind.cash,
            initialBalance: AppDatabase.maxAccountBalance + 1,
          ),
          accountError(equals('Saldo awal tidak valid.')),
        );
        expect(await all(), hasLength(1)); // hanya Tunai bawaan
      },
    );
  });

  group('ubah', () {
    test('dompet kosong: nama, jenis, dan saldo awal bisa diubah', () async {
      final id = await addBca(initial: 1000000);
      await db.updateAccount(
        id: id,
        name: ' BCA  Utama ',
        kind: AccountKind.card,
        initialBalance: 2000000,
      );
      final a = await byName('BCA Utama');
      expect(
        (a.kind, a.initialBalance, a.balance),
        (AccountKind.card, 2000000, 2000000),
      );
      expect(a.id, id);
    });

    test('dompet bertransaksi: nama dan jenis bisa diubah, saldo awal '
        'dikunci', () async {
      final id = await addBca(initial: 1000000);
      await db.addTransaction(
        type: TxType.expense,
        amount: 250000,
        accountId: id,
        categoryId: 'cat-exp-makan',
        date: DateTime.now(),
      );
      expect(await db.accountHasTransactions(id), isTrue);

      // Saldo awal yang sama (tidak berubah) tetap boleh disimpan.
      await db.updateAccount(
        id: id,
        name: ' BCA  Utama ',
        kind: AccountKind.card,
        initialBalance: 1000000,
      );
      final a = await byName('BCA Utama');
      expect(
        (a.kind, a.initialBalance, a.balance),
        (AccountKind.card, 1000000, 750000),
      );
      expect(a.id, id); // ID tetap: transaksi lama tetap menempel

      await expectLater(
        db.updateAccount(
          id: id,
          name: 'BCA Utama',
          kind: AccountKind.card,
          initialBalance: 2000000,
        ),
        throwsA(isA<AccountException>()),
      );
      expect((await byName('BCA Utama')).balance, 750000);
    });

    test('dompet tujuan transfer juga terkunci; transaksi yang dihapus tidak '
        'menghitung', () async {
      final a = await addBca(initial: 100000);
      final txId = await db.addTransaction(
        type: TxType.transfer,
        amount: 10000,
        accountId: 'acc-tunai',
        transferToAccountId: a,
        date: DateTime.now(),
      );
      expect(await db.accountHasTransactions(a), isTrue);
      await db.setTransactionDeleted(txId, deleted: true);
      expect(await db.accountHasTransactions(a), isFalse);
      await db.updateAccount(
        id: a,
        name: 'BCA',
        kind: AccountKind.bank,
        initialBalance: 5000,
      );
    });

    group('sesuaikan saldo', () {
      test('saldo aktual lebih kecil: pengeluaran Penyesuaian Saldo', () async {
        final id = await addBca(initial: 1000000);
        await db.addTransaction(
          type: TxType.expense,
          amount: 250000,
          accountId: id,
          categoryId: 'cat-exp-makan',
          date: DateTime.now(),
        );
        final diff = await db.adjustAccountBalance(
          accountId: id,
          actualBalance: 700000,
        );
        expect(diff, -50000);
        final a = await byName('BCA');
        expect((a.balance, a.initialBalance), (700000, 1000000));
        final adj = (await db.getTransactions()).firstWhere(
          (e) => e.category?.name == 'Penyesuaian Saldo',
        );
        expect((adj.tx.type, adj.tx.amount), (TxType.expense, 50000));
        expect(adj.tx.note, 'Penyesuaian saldo');
      });

      test(
        'saldo aktual lebih besar: pemasukan; kategori dipakai ulang',
        () async {
          final id = await addBca(initial: 100000);
          expect(
            await db.adjustAccountBalance(accountId: id, actualBalance: 160000),
            60000,
          );
          expect(
            await db.adjustAccountBalance(accountId: id, actualBalance: 150000),
            -10000,
          );
          expect((await byName('BCA')).balance, 150000);
          final income = await db.watchCategories(TxType.income).first;
          final expense = await db.watchCategories(TxType.expense).first;
          expect(
            [...income, ...expense].where((c) => c.name == 'Penyesuaian Saldo'),
            hasLength(2), // satu per jenis, tidak ganda
          );
        },
      );

      test(
        'tanpa selisih, saldo tidak valid, atau dompet arsip ditolak',
        () async {
          final id = await addBca(initial: 100000);
          await expectLater(
            db.adjustAccountBalance(accountId: id, actualBalance: 100000),
            throwsA(isA<AccountException>()),
          );
          await expectLater(
            db.adjustAccountBalance(accountId: id, actualBalance: -1),
            throwsA(isA<AccountException>()),
          );
          await db.setAccountArchived(id, archived: true);
          await expectLater(
            db.adjustAccountBalance(accountId: id, actualBalance: 5),
            throwsA(isA<AccountException>()),
          );
          expect(await db.getTransactions(), isEmpty);
        },
      );
    });

    test(
      'boleh menyimpan dengan nama yang sama; nama dompet lain ditolak',
      () async {
        final id = await addBca();
        await db.updateAccount(
          id: id,
          name: 'bca', // hanya beda huruf dari dirinya sendiri: boleh
          kind: AccountKind.bank,
          initialBalance: 1,
        );
        await expectLater(
          db.updateAccount(
            id: id,
            name: 'Tunai',
            kind: AccountKind.bank,
            initialBalance: 1,
          ),
          accountError(contains('Sudah ada dompet "Tunai"')),
        );
        await expectLater(
          db.updateAccount(
            id: id,
            name: '',
            kind: AccountKind.bank,
            initialBalance: 1,
          ),
          accountError(equals('Nama dompet wajib diisi.')),
        );
        await expectLater(
          db.updateAccount(
            id: id,
            name: 'BCA',
            kind: AccountKind.bank,
            initialBalance: -5,
          ),
          accountError(equals('Saldo awal tidak valid.')),
        );
        expect((await byName('bca')).initialBalance, 1); // tak berubah
      },
    );

    test('dompet yang tidak ada melempar StateError', () async {
      await expectLater(
        db.updateAccount(
          id: 'tidak-ada',
          name: 'X',
          kind: AccountKind.cash,
          initialBalance: 0,
        ),
        throwsStateError,
      );
    });
  });

  group('arsip', () {
    test('disembunyikan dari daftar dan Total Saldo, riwayat tetap ada, bisa dipulihkan', () async {
      final id = await addBca(initial: 500000);
      await db.addTransaction(
        type: TxType.income,
        amount: 100000,
        accountId: id,
        categoryId: 'cat-inc-gaji',
        date: DateTime.now(),
      );
      int total(List<AccountBalance> l) => l.fold(0, (s, a) => s + a.balance);
      expect(total(await active()), 600000);

      await db.setAccountArchived(id, archived: true);

      final visible = await active();
      expect(visible.map((a) => a.name), ['Tunai']);
      expect(total(visible), 0);
      // Riwayat transaksinya tidak hilang.
      expect(await db.getTransactions(), hasLength(1));
      // Saldonya tetap terhitung dan ditandai diarsipkan; urutannya di bawah.
      final everything = await all();
      expect(everything.map((a) => (a.name, a.archived)), [
        ('Tunai', false),
        ('BCA', true),
      ]);
      expect(everything.last.balance, 600000);

      await db.setAccountArchived(id, archived: false);
      expect(total(await active()), 600000);
      expect((await active()).map((a) => a.archived), everyElement(isFalse));
    });

    test('dompet aktif terakhir tidak boleh diarsipkan', () async {
      final id = await addBca();
      await db.setAccountArchived('acc-tunai', archived: true); // masih ada BCA
      await expectLater(
        db.setAccountArchived(id, archived: true),
        accountError(equals('Harus ada minimal satu dompet aktif.')),
      );
      expect((await active()).map((a) => a.name), ['BCA']);
    });

    test(
      'ditolak selama dipakai transaksi berulang aktif (asal maupun tujuan)',
      () async {
        final id = await addBca();
        final asal = await db.addRecurringRule(
          type: TxType.expense,
          amount: 10000,
          accountId: id,
          categoryId: 'cat-exp-tagihan',
          frequency: Frequency.monthly,
          startDate: DateTime.now().add(const Duration(days: 30)),
        );
        await expectLater(
          db.setAccountArchived(id, archived: true),
          accountError(contains('1 transaksi berulang aktif')),
        );

        // Setelah dijeda, boleh diarsipkan.
        await db.setRecurringActive(asal, active: false);
        await db.setAccountArchived(id, archived: true);
        await db.setAccountArchived(id, archived: false);
        await db.setRecurringActive(asal, active: true);

        // Sebagai dompet tujuan transfer juga dihitung.
        final tujuan = await db.addRecurringRule(
          type: TxType.transfer,
          amount: 5000,
          accountId: 'acc-tunai',
          transferToAccountId: id,
          frequency: Frequency.weekly,
          startDate: DateTime.now().add(const Duration(days: 7)),
        );
        await db.setRecurringActive(asal, active: false);
        await expectLater(
          db.setAccountArchived(id, archived: true),
          accountError(contains('1 transaksi berulang aktif')),
        );
        await db.setRecurringActive(tujuan, active: false);
        await db.setAccountArchived(id, archived: true);
        expect((await byName('BCA')).archived, isTrue);
      },
    );

    test(
      'nama dompet yang diarsipkan tetap dilindungi dari nama kembar',
      () async {
        final id = await addBca();
        await db.setAccountArchived(id, archived: true);
        await expectLater(
          db.addAccount(name: 'bca', kind: AccountKind.bank),
          accountError(contains('diarsipkan. Pulihkan saja')),
        );
      },
    );

    test('dompet yang tidak ada melempar StateError', () async {
      await expectLater(
        db.setAccountArchived('tidak-ada', archived: true),
        throwsStateError,
      );
    });

    test('status arsip ikut backup dan restore', () async {
      final id = await addBca();
      await db.setAccountArchived(id, archived: true);
      final json = await BackupService(db).export();

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).restore(BackupService.parse(json));
      final restored = await other
          .watchAccountBalances(includeArchived: true)
          .first;
      expect(restored.firstWhere((a) => a.name == 'BCA').archived, isTrue);
      expect((await other.watchAccountBalances().first).map((a) => a.name), [
        'Tunai',
      ]);
    });
  });
}
