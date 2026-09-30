import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> jsonDecodeMap(String s) =>
    jsonDecode(s) as Map<String, dynamic>;
String jsonEncodeMap(Map<String, dynamic> m) => jsonEncode(m);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> rule({
    Frequency frequency = Frequency.monthly,
    DateTime? start,
    DateTime? end,
    int amount = 100000,
    String? note = 'Sewa',
  }) => db.addRecurringRule(
    type: TxType.expense,
    amount: amount,
    accountId: 'acc-tunai',
    categoryId: 'cat-exp-rumah',
    frequency: frequency,
    startDate: start ?? DateTime(2026, 1, 25),
    endDate: end,
    note: note,
  );

  Future<List<TxEntry>> txs() async => [
    for (final v in await db.getTransactions()) v.tx,
  ];

  group('generateDueRecurring', () {
    test(
      'mencatat semua kejadian yang terlewat, dengan tanggal yang benar',
      () async {
        await rule();
        final n = await db.generateDueRecurring(now: DateTime(2026, 4, 10));
        expect(n, 3); // 25 Jan, 25 Feb, 25 Mar
        final list = await txs();
        expect(list.map((t) => t.date), [
          DateTime(2026, 1, 25),
          DateTime(2026, 2, 25),
          DateTime(2026, 3, 25),
        ]);
        expect(
          list.every((t) => t.recurringId != null && t.amount == 100000),
          isTrue,
        );
        expect(list.first.note, 'Sewa');
      },
    );

    test('kejadian tepat pada hari ini ikut dicatat, besok belum', () async {
      await rule(start: DateTime(2026, 6, 10));
      expect(
        await db.generateDueRecurring(now: DateTime(2026, 6, 9, 23, 59)),
        0,
      );
      expect(
        await db.generateDueRecurring(now: DateTime(2026, 6, 10, 0, 1)),
        1,
      );
    });

    test(
      'idempoten: dijalankan berulang tidak menggandakan transaksi',
      () async {
        await rule();
        final now = DateTime(2026, 4, 10);
        expect(await db.generateDueRecurring(now: now), 3);
        expect(await db.generateDueRecurring(now: now), 0);
        expect(await db.generateDueRecurring(now: now), 0);
        expect(await txs(), hasLength(3));
      },
    );

    test(
      'ID deterministik mencegah duplikat walau indeks aturan hilang',
      () async {
        final id = await rule();
        await db.generateDueRecurring(now: DateTime(2026, 3, 1));
        // Simulasikan kegagalan/pemulihan: indeks aturan kembali ke 0.
        await (db.update(db.recurringRules)..where((r) => r.id.equals(id)))
            .write(const RecurringRulesCompanion(nextIndex: Value(0)));
        await db.generateDueRecurring(now: DateTime(2026, 3, 1));
        expect(await txs(), hasLength(2)); // 25 Jan & 25 Feb, tanpa duplikat
      },
    );

    test('transaksi hasil generate yang dihapus tidak dibuat ulang', () async {
      await rule();
      await db.generateDueRecurring(now: DateTime(2026, 2, 26));
      final first = (await txs()).first;
      await db.setTransactionDeleted(first.id, deleted: true);
      await db.generateDueRecurring(now: DateTime(2026, 2, 27));
      expect(await txs(), hasLength(1));
    });

    test(
      'tanggal akhir bersifat inklusif dan menghentikan pembuatan',
      () async {
        await rule(end: DateTime(2026, 3, 25));
        expect(await db.generateDueRecurring(now: DateTime(2027, 1, 1)), 3);
        final view = (await db.watchRecurringRules().first).single;
        expect(view.finished, isTrue);
      },
    );

    test('aturan dijeda tidak menghasilkan transaksi', () async {
      final id = await rule();
      await db.setRecurringActive(id, active: false);
      expect(await db.generateDueRecurring(now: DateTime(2026, 6, 1)), 0);
    });

    test(
      'dilanjutkan setelah dijeda: periode yang terlewat dilewati',
      () async {
        final id = await rule(); // tiap tanggal 25 mulai Jan
        await db.generateDueRecurring(now: DateTime(2026, 2, 26)); // Jan, Feb
        await db.setRecurringActive(id, active: false);
        await db.setRecurringActive(
          id,
          active: true,
          now: DateTime(2026, 6, 1),
        );
        expect(await db.generateDueRecurring(now: DateTime(2026, 6, 1)), 0);
        // Kejadian berikutnya adalah 25 Juni, bukan Mar-Mei.
        expect(await db.generateDueRecurring(now: DateTime(2026, 6, 25)), 1);
        expect((await txs()).last.date, DateTime(2026, 6, 25));
      },
    );

    test(
      'melanjutkan aturan yang sudah aktif tidak menggeser jadwal',
      () async {
        final id = await rule();
        await db.setRecurringActive(
          id,
          active: true,
          now: DateTime(2026, 6, 1),
        );
        expect(await db.generateDueRecurring(now: DateTime(2026, 3, 1)), 2);
      },
    );

    test('transfer berulang memengaruhi kedua saldo', () async {
      await db.addAccount(name: 'Tabungan', kind: AccountKind.bank);
      final tab = (await db.watchAccountBalances().first).firstWhere(
        (a) => a.name == 'Tabungan',
      );
      await db.addRecurringRule(
        type: TxType.transfer,
        amount: 500000,
        accountId: 'acc-tunai',
        transferToAccountId: tab.id,
        frequency: Frequency.weekly,
        startDate: DateTime(2026, 5, 1),
      );
      expect(await db.generateDueRecurring(now: DateTime(2026, 5, 15)), 3);
      final b = await db.watchAccountBalances().first;
      expect(b.firstWhere((a) => a.id == tab.id).balance, 1500000);
      expect(b.firstWhere((a) => a.id == 'acc-tunai').balance, -1500000);
    });

    test(
      'batas maxPerRule: sisanya dilanjutkan pada pemanggilan berikutnya',
      () async {
        await rule(frequency: Frequency.weekly, start: DateTime(2026, 1, 1));
        final now = DateTime(2026, 12, 31); // 52 kejadian
        expect(await db.generateDueRecurring(now: now, maxPerRule: 10), 10);
        expect(await db.generateDueRecurring(now: now, maxPerRule: 100), 43);
        expect(await txs(), hasLength(53));
      },
    );
  });

  group('aturan', () {
    test('mengubah aturan hanya berdampak pada transaksi berikutnya', () async {
      final id = await rule(amount: 100000);
      await db.generateDueRecurring(now: DateTime(2026, 2, 26));
      await db.updateRecurringRule(
        id: id,
        type: TxType.expense,
        amount: 150000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-rumah',
        note: 'Sewa naik',
      );
      await db.generateDueRecurring(now: DateTime(2026, 3, 26));
      final list = await txs();
      expect(list.map((t) => t.amount), [100000, 100000, 150000]);
      expect(list.last.note, 'Sewa naik');
    });

    test(
      'menghapus aturan tidak menghapus transaksi yang sudah tercatat',
      () async {
        final id = await rule();
        await db.generateDueRecurring(now: DateTime(2026, 3, 1));
        await db.deleteRecurringRule(id);
        expect(await txs(), hasLength(2));
        expect(await db.generateDueRecurring(now: DateTime(2027, 1, 1)), 0);
      },
    );

    test('data tidak valid ditolak', () {
      expect(() => rule(amount: 0), throwsArgumentError);
      expect(
        () => db.addRecurringRule(
          type: TxType.expense,
          amount: 1,
          accountId: 'acc-tunai',
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 1, 1),
        ),
        throwsArgumentError, // kategori wajib
      );
    });
  });

  group('updateTransaction', () {
    Future<TxEntry> one() async => (await txs()).single;

    test(
      'mengubah field, mempertahankan createdAt, dan memperbarui saldo',
      () async {
        await db.addTransaction(
          type: TxType.expense,
          amount: 30000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-makan',
          date: DateTime(2026, 9, 2),
          note: 'awal',
        );
        final before = await one();

        await db.updateTransaction(
          id: before.id,
          type: TxType.expense,
          amount: 45000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-transport',
          date: DateTime(2026, 9, 3),
          note: '  ubah  ',
        );
        final after = await one();
        expect(after.amount, 45000);
        expect(after.categoryId, 'cat-exp-transport');
        expect(after.date, DateTime(2026, 9, 3));
        expect(after.note, 'ubah'); // dipangkas
        expect(after.createdAt, before.createdAt);
        // Drift menyimpan waktu dalam detik: cukup pastikan tidak mundur.
        expect(after.updatedAt.isBefore(before.updatedAt), isFalse);
        expect((await db.watchAccountBalances().first).single.balance, -45000);
      },
    );

    test('mengganti jenis ke transfer membersihkan kategori', () async {
      await db.addAccount(name: 'Dana', kind: AccountKind.ewallet);
      final dana = (await db.watchAccountBalances().first).firstWhere(
        (a) => a.name == 'Dana',
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: 10000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime(2026, 9, 2),
      );
      final tx = await one();
      await db.updateTransaction(
        id: tx.id,
        type: TxType.transfer,
        amount: 10000,
        accountId: 'acc-tunai',
        transferToAccountId: dana.id,
        categoryId: 'cat-exp-makan', // harus diabaikan
        date: DateTime(2026, 9, 2),
      );
      final after = await one();
      expect(after.categoryId, isNull);
      expect(after.transferToAccountId, dana.id);
      final totals = await db.watchTotals(DateTime(2026, 9)).first;
      expect(totals.expense, 0);
    });

    test('transaksi hasil generate tetap terhubung ke aturannya', () async {
      await rule();
      await db.generateDueRecurring(now: DateTime(2026, 1, 26));
      final tx = await one();
      await db.updateTransaction(
        id: tx.id,
        type: TxType.expense,
        amount: 1,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-rumah',
        date: tx.date,
      );
      expect((await one()).recurringId, tx.recurringId);
    });

    test('id tidak ada atau data tidak valid melempar error', () async {
      expect(
        () => db.updateTransaction(
          id: 'nope',
          type: TxType.expense,
          amount: 1,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-makan',
          date: DateTime(2026, 1, 1),
        ),
        throwsStateError,
      );
      expect(
        () => db.updateTransaction(
          id: 'x',
          type: TxType.expense,
          amount: 0,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-makan',
          date: DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('backup', () {
    test('aturan berulang ikut di backup dan pulih utuh', () async {
      final id = await rule(end: DateTime(2026, 12, 25));
      await db.generateDueRecurring(now: DateTime(2026, 2, 26));
      final json = await BackupService(db).export();

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).restore(BackupService.parse(json));

      final view = (await other.watchRecurringRules().first).single;
      expect(view.rule.id, id);
      expect(view.rule.nextIndex, 2);
      expect(view.rule.endDate, DateTime(2026, 12, 25));
      // Jadwal berlanjut dari tempat terakhir, tanpa duplikat.
      expect(await other.generateDueRecurring(now: DateTime(2026, 2, 26)), 0);
      expect(await other.generateDueRecurring(now: DateTime(2026, 3, 26)), 1);
    });

    test(
      'backup versi 1 (tanpa aturan berulang) masih bisa dipulihkan',
      () async {
        await db.addTransaction(
          type: TxType.expense,
          amount: 5000,
          accountId: 'acc-tunai',
          categoryId: 'cat-exp-makan',
          date: DateTime(2026, 9, 2),
        );
        final v1 = (jsonDecodeMap(await BackupService(db).export()))
          ..['version'] = 1
          ..remove('recurringRules');
        for (final t in v1['transactions'] as List) {
          (t as Map).remove('recurringId');
        }

        final data = BackupService.parse(jsonEncodeMap(v1));
        expect(data.recurringRules, isEmpty);
        expect(data.activeTransactionCount, 1);
        await BackupService(db).restore(data);
        expect(await txs(), hasLength(1));
      },
    );

    test('aturan yang menunjuk dompet tidak ada ditolak', () async {
      await rule();
      final map = jsonDecodeMap(await BackupService(db).export());
      ((map['recurringRules'] as List).first as Map)['accountId'] = 'hilang';
      expect(
        () => BackupService.parse(jsonEncodeMap(map)),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
