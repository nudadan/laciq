import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/csv_export.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tes restore sengaja memakai dua database in-memory yang terpisah.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> expense(int amount, {String? note, DateTime? date}) =>
      db.addTransaction(
        type: TxType.expense,
        amount: amount,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: date ?? DateTime(2026, 9, 2),
        note: note,
      );

  group('CSV', () {
    test('header, BOM, pemisah titik koma, dan nominal murni', () async {
      await expense(1250000, note: 'Makan siang');
      final csv = buildTransactionsCsv(await db.getTransactions());
      expect(csv.startsWith('﻿'), isTrue);
      final lines = csv.substring(1).trimRight().split('\r\n');
      expect(
        lines[0],
        'Tanggal;Jenis;Kategori;Dompet;Dompet Tujuan;Nominal;Catatan',
      );
      expect(
        lines[1],
        '2026-09-02;Pengeluaran;Makanan & Minuman;Tunai;;1250000;Makan siang',
      );
    });

    test('mengutip sel berisi pemisah, tanda kutip, dan baris baru', () async {
      await expense(1000, note: 'a;b "c"\nbaris2');
      final csv = buildTransactionsCsv(await db.getTransactions());
      expect(csv, contains('"a;b ""c""\nbaris2"'));
    });

    test('menetralkan formula injection pada sel teks', () async {
      await expense(1000, note: '=HYPERLINK("http://evil")');
      await expense(2000, note: '+62 811');
      final csv = buildTransactionsCsv(await db.getTransactions());
      expect(csv, contains('''"'=HYPERLINK(""http://evil"")"'''));
      expect(csv, contains("'+62 811"));
      // Nominal tetap angka biasa, tidak diberi awalan.
      expect(csv, contains(';1000;'));
    });

    test(
      'transfer menampilkan dompet tujuan; transaksi terhapus tidak ikut',
      () async {
        await db.addAccount(name: 'Dana', kind: AccountKind.ewallet);
        final dana = (await db.watchAccountBalances().first).firstWhere(
          (a) => a.name == 'Dana',
        );
        await db.addTransaction(
          type: TxType.transfer,
          amount: 5000,
          accountId: 'acc-tunai',
          transferToAccountId: dana.id,
          date: DateTime(2026, 9, 3),
        );
        await expense(9999);
        final id = (await db.getTransactions())
            .firstWhere((v) => v.tx.amount == 9999)
            .tx
            .id;
        await db.setTransactionDeleted(id, deleted: true);

        final csv = buildTransactionsCsv(await db.getTransactions());
        expect(csv, contains('Transfer;;Tunai;Dana;5000;'));
        expect(csv, isNot(contains('9999')));
      },
    );

    test(
      'getTransactions menghormati rentang dan urut dari yang terlama',
      () async {
        await expense(1, date: DateTime(2026, 9, 5));
        await expense(2, date: DateTime(2026, 8, 5));
        await expense(3, date: DateTime(2026, 10, 5));
        final all = await db.getTransactions();
        expect(all.map((v) => v.tx.amount), [2, 1, 3]);
        final sep = await db.getTransactions(
          from: DateTime(2026, 9),
          to: DateTime(2026, 10),
        );
        expect(sep.map((v) => v.tx.amount), [1]);
      },
    );
  });

  group('Backup', () {
    Future<String> seededBackup() async {
      await db.addAccount(
        name: 'BCA',
        kind: AccountKind.bank,
        initialBalance: 1000000,
      );
      await expense(50000, note: 'kopi');
      await db.setBudget('cat-exp-makan', 300000);
      await db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: DateTime(2026, 10, 1),
        estimatedAmount: 350000,
      );
      return BackupService(db).export();
    }

    test(
      'export lalu restore ke database lain menghasilkan data identik',
      () async {
        final json = await seededBackup();
        final before = await db.watchAccountBalances().first;

        final other = AppDatabase(NativeDatabase.memory());
        addTearDown(other.close);
        // Data lain di tujuan harus tergantikan sepenuhnya.
        await other.addAccount(name: 'Akan Hilang', kind: AccountKind.cash);

        final data = BackupService.parse(json);
        expect(data.activeTransactionCount, 1);
        await BackupService(other).restore(data);

        final after = await other.watchAccountBalances().first;
        expect(
          after.map((a) => (a.id, a.name, a.balance)),
          before.map((a) => (a.id, a.name, a.balance)),
        );
        expect(after.any((a) => a.name == 'Akan Hilang'), isFalse);
        final tx = await other.getTransactions();
        expect(tx.single.tx.note, 'kopi');
        expect(tx.single.tx.date, DateTime(2026, 9, 2));
        final budgets = await other
            .watchBudgetProgress(DateTime(2026, 9))
            .first;
        expect(
          budgets.firstWhere((p) => p.category.id == 'cat-exp-makan').budget,
          300000,
        );
        final agenda = (await other.watchAgendaReminders().first).single;
        expect((agenda.title, agenda.estimatedAmount), ('Servis AC', 350000));
      },
    );

    test('backup versi lama (tanpa kunci agendaReminders sama sekali) tetap '
        'bisa dipulihkan, agenda kosong bukan error', () async {
      final map = jsonDecode(await seededBackup()) as Map<String, dynamic>;
      map.remove('agendaReminders');
      map['version'] = 4;

      final data = BackupService.parse(jsonEncode(map));
      expect(data.agendaReminders, isEmpty);

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).restore(data);
      expect(await other.watchAgendaReminders().first, isEmpty);
    });

    test('file tidak valid ditolak dengan pesan yang jelas', () {
      void rejects(String source, Matcher message) => expect(
        () => BackupService.parse(source),
        throwsA(
          isA<BackupException>().having((e) => e.message, 'message', message),
        ),
      );

      rejects('bukan json {', contains('bukan backup'));
      rejects('[1,2]', contains('bukan backup'));
      rejects('{"format":"lain","version":1}', contains('bukan backup'));
      rejects(
        jsonEncode({'format': BackupService.formatName, 'version': 99}),
        contains('lebih baru'),
      );
      rejects(
        jsonEncode({'format': BackupService.formatName, 'version': 1}),
        contains('rusak'), // daftar wajib tidak ada
      );
    });

    test('referensi menggantung dan ID ganda ditolak', () async {
      final map = jsonDecode(await seededBackup()) as Map<String, dynamic>;

      final dangling = jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
      ((dangling['transactions'] as List).first as Map)['accountId'] =
          'tidak-ada';
      expect(
        () => BackupService.parse(jsonEncode(dangling)),
        throwsA(isA<BackupException>()),
      );

      final dup = jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
      (dup['accounts'] as List).add((dup['accounts'] as List).first);
      expect(
        () => BackupService.parse(jsonEncode(dup)),
        throwsA(isA<BackupException>()),
      );
    });

    test(
      'restore yang gagal membatalkan semuanya, data lama tetap utuh',
      () async {
        await expense(75000, note: 'data lama');
        final oldBalance =
            (await db.watchAccountBalances().first).single.balance;

        final now = DateTime.now();
        // Sengaja melewati parse(): transaksi menunjuk dompet yang tidak ada,
        // sehingga foreign key gagal di tengah restore.
        final bad = BackupData(
          exportedAt: now,
          accounts: [
            Account(
              id: 'a1',
              name: 'Baru',
              kind: AccountKind.cash,
              ledgerId: kMainLedgerId,
              initialBalance: 0,
              archived: false,
              updatedAt: now,
            ),
          ],
          categories: const [],
          transactions: [
            TxEntry(
              id: 't1',
              type: TxType.expense,
              amount: 1,
              accountId: 'tidak-ada',
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          budgets: const [],
        );

        await expectLater(BackupService(db).restore(bad), throwsA(anything));

        final accounts = await db.watchAccountBalances().first;
        expect(accounts.single.id, 'acc-tunai');
        expect(accounts.single.balance, oldBalance);
        expect((await db.getTransactions()).single.tx.note, 'data lama');
        expect(await db.watchCategories(TxType.expense).first, isNotEmpty);
      },
    );
  });
}
