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

  Future<List<Category>> active(TxType t) => db.watchCategories(t).first;
  Future<List<Category>> all(TxType t) =>
      db.watchCategories(t, includeArchived: true).first;

  Matcher categoryError(Matcher msg) => throwsA(
    isA<CategoryException>().having((e) => e.message, 'message', msg),
  );

  group('tambah', () {
    test(
      'kategori baru muncul di urutan paling akhir dengan nama dirapikan',
      () async {
        final before = await active(TxType.expense);
        final id = await db.addCategory(
          type: TxType.expense,
          name: '  Kopi   &  Camilan ',
          icon: 'coffee',
          color: 0xFF6D4C41,
        );
        final list = await active(TxType.expense);
        expect(list, hasLength(before.length + 1));
        final c = list.last;
        expect(c.id, id);
        expect(c.name, 'Kopi & Camilan');
        expect(c.icon, 'coffee');
        expect(c.color, 0xFF6D4C41);
        expect(c.sortOrder, before.last.sortOrder + 1);
        expect(c.archived, isFalse);
      },
    );

    test('jenis pemasukan dan pengeluaran terpisah', () async {
      await db.addCategory(
        type: TxType.income,
        name: 'Freelance',
        icon: 'business',
        color: 1,
      );
      expect(
        (await active(TxType.income)).map((c) => c.name),
        contains('Freelance'),
      );
      expect(
        (await active(TxType.expense)).map((c) => c.name),
        isNot(contains('Freelance')),
      );
    });

    test('nama kosong, terlalu panjang, dan transfer ditolak', () async {
      Future<String> add(String n, [TxType t = TxType.expense]) =>
          db.addCategory(type: t, name: n, icon: 'other', color: 1);
      expect(() => add('   '), categoryError(contains('wajib')));
      expect(() => add('x' * 61), categoryError(contains('maksimal')));
      expect(
        () => add('Valid', TxType.transfer),
        categoryError(contains('Transfer')),
      );
    });

    test('nama kembar ditolak tanpa membedakan huruf besar/kecil', () async {
      expect(
        () => db.addCategory(
          type: TxType.expense,
          name: 'belanja',
          icon: 'other',
          color: 1,
        ),
        categoryError(contains('Sudah ada kategori "belanja"')),
      );
      // Jenis berbeda boleh sama: "Lainnya" ada di kedua jenis.
      await db.addCategory(
        type: TxType.income,
        name: 'Belanja',
        icon: 'other',
        color: 1,
      );
    });

    test(
      'nama kembar dengan kategori yang diarsipkan diberi petunjuk',
      () async {
        await db.setCategoryArchived('cat-exp-hiburan', archived: true);
        expect(
          () => db.addCategory(
            type: TxType.expense,
            name: 'Hiburan',
            icon: 'other',
            color: 1,
          ),
          categoryError(contains('diarsipkan')),
        );
      },
    );
  });

  group('ubah', () {
    test('mengganti nama, ikon, dan warna; jenis dan id tetap', () async {
      await db.updateCategory(
        id: 'cat-exp-belanja',
        name: 'Belanja Bulanan',
        icon: 'shopping',
        color: 0xFF1E88E5,
      );
      final c = (await all(TxType.expense))
          .firstWhere((c) => c.id == 'cat-exp-belanja');
      expect(c.name, 'Belanja Bulanan');
      expect(c.color, 0xFF1E88E5);
      expect(c.type, TxType.expense);
    });

    test(
      'boleh mengubah huruf besar/kecil nama sendiri, tidak boleh nama lain',
      () async {
        await db.updateCategory(
          id: 'cat-exp-belanja',
          name: 'BELANJA',
          icon: 'shopping',
          color: 1,
        );
        expect(
          () => db.updateCategory(
            id: 'cat-exp-belanja',
            name: 'Transportasi',
            icon: 'shopping',
            color: 1,
          ),
          categoryError(contains('Sudah ada')),
        );
      },
    );

    test('transaksi lama otomatis menampilkan nama baru', () async {
      await db.addTransaction(
        type: TxType.expense,
        amount: 1000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-belanja',
        date: DateTime(2026, 9, 2),
      );
      await db.updateCategory(
        id: 'cat-exp-belanja',
        name: 'Groceries',
        icon: 'shopping',
        color: 1,
      );
      final v = (await db.getTransactions()).single;
      expect(v.category!.name, 'Groceries');
    });

    test('id tidak ada melempar error', () {
      expect(
        () => db.updateCategory(id: 'nope', name: 'X', icon: 'other', color: 1),
        throwsStateError,
      );
    });
  });

  group('arsip', () {
    test(
      'disembunyikan dari pilihan dan anggaran, tetap ada di transaksi lama',
      () async {
        await db.addTransaction(
          type: TxType.expense,
          amount: 5000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-hiburan',
          date: DateTime(2026, 9, 2),
        );
        await db.setBudget('cat-exp-hiburan', 100000);
        await db.setCategoryArchived('cat-exp-hiburan', archived: true);

        expect(
          (await active(TxType.expense)).map((c) => c.id),
          isNot(contains('cat-exp-hiburan')),
        );
        expect(
          (await all(TxType.expense)).last.id,
          'cat-exp-hiburan',
        ); // di bawah
        final budgets = await db.watchBudgetProgress(DateTime(2026, 9)).first;
        expect(
          budgets.map((b) => b.category.id),
          isNot(contains('cat-exp-hiburan')),
        );

        // Riwayat dan laporan tidak terpengaruh.
        final v = (await db.getTransactions()).single;
        expect(v.category!.name, 'Hiburan');
        expect((await db.watchTotals(DateTime(2026, 9)).first).expense, 5000);
        expect(
          (await db.watchExpenseByCategory(DateTime(2026, 9)).first)
              .single
              .name,
          'Hiburan',
        );
      },
    );

    test('dipulihkan: kembali ke pilihan beserta anggarannya', () async {
      await db.setBudget('cat-exp-hiburan', 100000);
      await db.setCategoryArchived('cat-exp-hiburan', archived: true);
      await db.setCategoryArchived('cat-exp-hiburan', archived: false);
      expect(
        (await active(TxType.expense)).map((c) => c.id),
        contains('cat-exp-hiburan'),
      );
      final b = (await db.watchBudgetProgress(DateTime(2026, 9)).first)
          .firstWhere((p) => p.category.id == 'cat-exp-hiburan');
      expect(b.budget, 100000);
    });

    test(
      'kategori aktif terakhir suatu jenis tidak boleh diarsipkan',
      () async {
        final incomes = await active(TxType.income);
        for (final c in incomes.skip(1)) {
          await db.setCategoryArchived(c.id, archived: true);
        }
        expect(
          () => db.setCategoryArchived(incomes.first.id, archived: true),
          categoryError(contains('minimal satu')),
        );
        // Jenis lain tidak ikut terhitung.
        expect(await active(TxType.expense), isNotEmpty);
      },
    );

    test(
      'mengarsipkan yang sudah diarsipkan tidak dianggap kategori terakhir',
      () async {
        await db.setCategoryArchived('cat-exp-hiburan', archived: true);
        await db.setCategoryArchived(
          'cat-exp-hiburan',
          archived: true,
        ); // idempoten
      },
    );
  });

  test(
    'categoryUsage menghitung transaksi aktif, aturan aktif, dan anggaran',
    () async {
      await db.addTransaction(
        type: TxType.expense,
        amount: 1,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime(2026, 9, 2),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: 2,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime(2026, 9, 3),
      );
      final gone = (await db.getTransactions()).last.tx.id;
      await db.setTransactionDeleted(gone, deleted: true);
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 1,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        frequency: Frequency.monthly,
        startDate: DateTime(2030, 1, 1),
      );
      final paused = await db.addRecurringRule(
        type: TxType.expense,
        amount: 1,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        frequency: Frequency.monthly,
        startDate: DateTime(2030, 1, 1),
      );
      await db.setRecurringActive(paused, active: false);
      await db.setBudget('cat-exp-makan', 1000);

      final u = await db.categoryUsage('cat-exp-makan');
      expect(u.transactions, 1); // yang dihapus tidak dihitung
      expect(u.activeRules, 1); // yang dijeda tidak dihitung
      expect(u.hasBudget, isTrue);
      final none = await db.categoryUsage('cat-exp-rumah');
      expect(
        (none.transactions, none.activeRules, none.hasBudget),
        (0, 0, false),
      );
    },
  );

  test(
    'aturan berulang tetap berjalan untuk kategori yang diarsipkan',
    () async {
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 5000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-hiburan',
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 1, 1),
      );
      await db.setCategoryArchived('cat-exp-hiburan', archived: true);
      expect(await db.generateDueRecurring(now: DateTime(2026, 2, 2)), 2);
    },
  );

  test('kategori kustom dan status arsip ikut backup dan pulih', () async {
    final id = await db.addCategory(
      type: TxType.expense,
      name: 'Hobi',
      icon: 'gaming',
      color: 0xFF8E24AA,
    );
    await db.setCategoryArchived(id, archived: true);
    final json = await BackupService(db).export();

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await BackupService(other).restore(BackupService.parse(json));

    final c =
        (await other
                .watchCategories(TxType.expense, includeArchived: true)
                .first)
            .firstWhere((c) => c.id == id);
    expect(
      (c.name, c.icon, c.color, c.archived),
      ('Hobi', 'gaming', 0xFF8E24AA, true),
    );
  });

  group('sub-kategori', () {
    test('bisa dibuat dengan induk sejenis', () async {
      final sub = await db.addCategory(
        type: TxType.expense,
        name: 'Kopi',
        icon: 'coffee',
        color: 1,
        parentId: 'cat-exp-makan',
      );
      final c = (await all(TxType.expense)).firstWhere((c) => c.id == sub);
      expect(c.parentId, 'cat-exp-makan');
    });

    test('induk beda jenis ditolak', () async {
      expect(
        () => db.addCategory(
          type: TxType.expense,
          name: 'Kopi',
          icon: 'coffee',
          color: 1,
          parentId: 'cat-inc-gaji', // kategori pemasukan
        ),
        categoryError(contains('sejenis')),
      );
    });

    test('induk yang tidak ada ditolak', () async {
      expect(
        () => db.addCategory(
          type: TxType.expense,
          name: 'Kopi',
          icon: 'coffee',
          color: 1,
          parentId: 'tidak-ada',
        ),
        categoryError(contains('tidak ditemukan')),
      );
    });

    test('tidak bisa jadi induk dirinya sendiri (saat ubah)', () async {
      final id = await db.addCategory(
        type: TxType.expense,
        name: 'Kopi',
        icon: 'coffee',
        color: 1,
      );
      expect(
        () => db.updateCategory(
          id: id,
          name: 'Kopi',
          icon: 'coffee',
          color: 1,
          parentId: id,
        ),
        categoryError(contains('dirinya sendiri')),
      );
    });

    test('cucu (induk dari sub-kategori) ditolak', () async {
      final sub = await db.addCategory(
        type: TxType.expense,
        name: 'Kopi',
        icon: 'coffee',
        color: 1,
        parentId: 'cat-exp-makan',
      );
      expect(
        () => db.addCategory(
          type: TxType.expense,
          name: 'Kopi Susu',
          icon: 'coffee',
          color: 1,
          parentId: sub,
        ),
        categoryError(contains('sub-kategori lagi')),
      );
    });

    test(
      'kategori dengan sub-kategori sendiri tidak bisa dijadikan sub-kategori',
      () async {
        await db.addCategory(
          type: TxType.expense,
          name: 'Kopi',
          icon: 'coffee',
          color: 1,
          parentId: 'cat-exp-makan',
        );
        expect(
          () => db.updateCategory(
            id: 'cat-exp-makan',
            name: 'Makanan & Minuman',
            icon: 'food',
            color: 1,
            parentId: 'cat-exp-transport',
          ),
          categoryError(contains('punya sub-kategori sendiri')),
        );
      },
    );

    test('mengarsipkan induk dengan sub-kategori aktif ditolak', () async {
      await db.addCategory(
        type: TxType.expense,
        name: 'Kopi',
        icon: 'coffee',
        color: 1,
        parentId: 'cat-exp-makan',
      );
      expect(
        () => db.setCategoryArchived('cat-exp-makan', archived: true),
        categoryError(contains('sub-kategori aktif')),
      );
    });

    test(
      'sub-kategori yang sudah diarsipkan tidak menghalangi induk diarsipkan',
      () async {
        final sub = await db.addCategory(
          type: TxType.expense,
          name: 'Kopi',
          icon: 'coffee',
          color: 1,
          parentId: 'cat-exp-makan',
        );
        await db.setCategoryArchived(sub, archived: true);
        await db.setCategoryArchived('cat-exp-makan', archived: true);
        final c = (await all(TxType.expense))
            .firstWhere((c) => c.id == 'cat-exp-makan');
        expect(c.archived, isTrue);
      },
    );

    test('sub-kategori dan induknya ikut backup dan pulih', () async {
      final sub = await db.addCategory(
        type: TxType.expense,
        name: 'Kopi',
        icon: 'coffee',
        color: 1,
        parentId: 'cat-exp-makan',
      );
      final json = await BackupService(db).export();

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).restore(BackupService.parse(json));

      final c =
          (await other
                  .watchCategories(TxType.expense, includeArchived: true)
                  .first)
              .firstWhere((c) => c.id == sub);
      expect(c.parentId, 'cat-exp-makan');
    });
  });

  group('anggaran dengan sub-kategori (rollup)', () {
    test('pemakaian sub-kategori masuk ke anggaran induk, sub-kategori tanpa baris sendiri', () async {
      final sub = await db.addCategory(
        type: TxType.expense,
        name: 'Kopi',
        icon: 'coffee',
        color: 1,
        parentId: 'cat-exp-makan',
      );
      await db.setBudget('cat-exp-makan', 100000);
      await db.addTransaction(
        type: TxType.expense,
        amount: 30000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime(2026, 9, 5),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: 20000,
        accountId: 'acc-tunai',
        categoryId: sub,
        date: DateTime(2026, 9, 6),
      );

      final progress = await db.watchBudgetProgress(DateTime(2026, 9)).first;
      expect(progress.where((p) => p.category.id == sub), isEmpty);
      final makan = progress.firstWhere(
        (p) => p.category.id == 'cat-exp-makan',
      );
      expect(makan.spent, 30000 + 20000);
      expect(makan.budget, 100000);
    });
  });
}
