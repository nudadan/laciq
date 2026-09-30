import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Json = Map<String, dynamic>;

/// Validasi backup: file yang lolos parse() akan MENGGANTI seluruh data, jadi
/// isinya harus konsisten dengan aturan yang dijaga aplikasi sendiri. Constraint
/// SQLite tidak menangkap ini (kolomnya nullable), sehingga tanpa validasi data
/// rusak masuk diam-diam dan baru terasa sebagai angka yang tidak cocok.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late String bcaId;
  late String baseJson;

  /// Backup sah berisi: pengeluaran, pemasukan, transfer, aturan berulang
  /// (pengeluaran dan transfer), transaksi terhapus, dan dompet diarsipkan.
  Future<String> seedAndExport() async {
    final now = DateTime.now();
    await db.addTransaction(
      type: TxType.expense,
      amount: 5000,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-makan',
      date: now,
    );
    await db.addTransaction(
      type: TxType.income,
      amount: 9000,
      accountId: bcaId,
      categoryId: 'cat-inc-gaji',
      date: now,
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: 2000,
      accountId: bcaId,
      transferToAccountId: 'acc-tunai',
      date: now,
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: 1,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-makan',
      date: now,
    );
    final gone = (await db.getTransactions()).last.tx.id;
    await db.setTransactionDeleted(gone, deleted: true);
    final future = now.add(const Duration(days: 30));
    await db.addRecurringRule(
      type: TxType.expense,
      amount: 100,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-tagihan',
      frequency: Frequency.monthly,
      startDate: future,
    );
    await db.addRecurringRule(
      type: TxType.transfer,
      amount: 100,
      accountId: bcaId,
      transferToAccountId: 'acc-tunai',
      frequency: Frequency.weekly,
      startDate: future,
    );
    await db.addAccount(name: 'Lama', kind: AccountKind.cash);
    final lama = (await db.watchAccountBalances().first).firstWhere(
      (a) => a.name == 'Lama',
    );
    await db.setAccountArchived(lama.id, archived: true);
    return BackupService(db).export();
  }

  /// Salinan baru yang bebas diubah oleh tiap kasus.
  Future<_Json> validBackup() async => jsonDecode(baseJson) as _Json;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.addAccount(
      name: 'BCA',
      kind: AccountKind.bank,
      initialBalance: 100000,
    );
    bcaId = (await db.watchAccountBalances().first)
        .firstWhere((a) => a.name == 'BCA')
        .id;
    baseJson = await seedAndExport();
  });
  tearDown(() => db.close());

  _Json tx(_Json m, int type) => (m['transactions'] as List)
      .cast<_Json>()
      .firstWhere((t) => t['type'] == type && t['deletedAt'] == null);
  _Json rule(_Json m, int type) => (m['recurringRules'] as List)
      .cast<_Json>()
      .firstWhere((r) => r['type'] == type);

  void rejects(_Json m, Matcher detail) => expect(
    () => BackupService.parse(jsonEncode(m)),
    throwsA(isA<BackupException>().having((e) => e.message, 'message', detail)),
  );

  final inconsistent = contains('tidak konsisten');

  test('backup sah yang lengkap (transfer, terhapus, arsip, berulang) tidak ditolak', () async {
    final data = BackupService.parse(jsonEncode(await validBackup()));
    expect(data.transactions, hasLength(4));
    expect(data.recurringRules, hasLength(2));
    expect(data.accounts.where((a) => a.archived), hasLength(1));
  });

  group('transaksi', () {
    test('transfer tanpa dompet tujuan', () async {
      final m = await validBackup();
      tx(m, 2)['transferToAccountId'] = null;
      rejects(m, inconsistent);
    });

    test('transfer ke dompet yang sama', () async {
      final m = await validBackup();
      final t = tx(m, 2);
      t['transferToAccountId'] = t['accountId'];
      rejects(m, inconsistent);
    });

    test('transfer yang membawa kategori', () async {
      final m = await validBackup();
      tx(m, 2)['categoryId'] = 'cat-exp-makan';
      rejects(m, inconsistent);
    });

    test('pemasukan/pengeluaran tanpa kategori', () async {
      for (final type in [0, 1]) {
        final m = await validBackup();
        tx(m, type)['categoryId'] = null;
        rejects(m, inconsistent);
      }
    });

    test('pengeluaran yang membawa dompet tujuan', () async {
      final m = await validBackup();
      tx(m, 1)['transferToAccountId'] = bcaId;
      rejects(m, inconsistent);
    });

    test(
      'kategori berjenis lain (pengeluaran dengan kategori pemasukan)',
      () async {
        final m = await validBackup();
        tx(m, 1)['categoryId'] = 'cat-inc-gaji';
        rejects(m, inconsistent);
      },
    );

    test('transaksi yang sudah dihapus pun harus konsisten', () async {
      final m = await validBackup();
      final gone = (m['transactions'] as List).cast<_Json>().firstWhere(
        (t) => t['deletedAt'] != null,
      );
      gone['categoryId'] = null;
      rejects(m, inconsistent);
    });
  });

  group('aturan berulang', () {
    test('transfer tanpa dompet tujuan / ke dompet yang sama', () async {
      final m = await validBackup();
      rule(m, 2)['transferToAccountId'] = null;
      rejects(m, inconsistent);

      final same = await validBackup();
      final r = rule(same, 2);
      r['transferToAccountId'] = r['accountId'];
      rejects(same, inconsistent);
    });

    test(
      'pengeluaran tanpa kategori, atau dengan kategori berjenis lain',
      () async {
        final none = await validBackup();
        rule(none, 1)['categoryId'] = null;
        rejects(none, inconsistent);

        final wrong = await validBackup();
        rule(wrong, 1)['categoryId'] = 'cat-inc-gaji';
        rejects(wrong, inconsistent);
      },
    );
  });

  group('isi minimum', () {
    test('tanpa dompet aktif (semua diarsipkan atau kosong)', () async {
      final m = await validBackup();
      for (final a in (m['accounts'] as List).cast<_Json>()) {
        a['archived'] = true;
      }
      rejects(m, contains('dompet aktif'));
    });

    test('tanpa kategori aktif untuk salah satu jenis', () async {
      for (final type in [0, 1]) {
        final m = await validBackup();
        for (final c in (m['categories'] as List).cast<_Json>()) {
          if (c['type'] == type) c['archived'] = true;
        }
        rejects(m, contains('kategori aktif'));
      }
    });
  });

  test('backup ditolak tidak menyentuh data yang ada', () async {
    final m = await validBackup();
    tx(m, 2)['transferToAccountId'] = null;
    final before = (await db.getTransactions()).length;
    expect(
      () => BackupService.parse(jsonEncode(m)),
      throwsA(isA<BackupException>()),
    );
    expect((await db.getTransactions()).length, before); // parse() murni
  });
}
