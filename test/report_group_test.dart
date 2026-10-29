import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kelompok laporan kategori dan sifat buku (skema v12, backup v9). Lihat
/// docs/RENCANA-IMPLEMENTASI-UMKM.md §4.1.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Map<String, ReportGroup?>> groups() async => {
    for (final c in await db.select(db.categories).get()) c.id: c.reportGroup,
  };

  Future<String> addBiz() => db.addLedger(
    name: 'Toko',
    icon: 'business',
    color: 0xFF00897B,
    template: LedgerTemplate.business,
  );

  Matcher categoryError() => throwsA(isA<CategoryException>());

  group('ReportGroup', () {
    test('allowedFor: pemasukan, pengeluaran, dan transfer', () {
      const income = {
        ReportGroup.revenue,
        ReportGroup.otherIncome,
        ReportGroup.nonPnl,
      };
      const expense = {
        ReportGroup.cogs,
        ReportGroup.opex,
        ReportGroup.otherExpense,
        ReportGroup.nonPnl,
      };
      for (final g in ReportGroup.values) {
        expect(g.allowedFor(TxType.income), income.contains(g), reason: '$g');
        expect(g.allowedFor(TxType.expense), expense.contains(g), reason: '$g');
        expect(g.allowedFor(TxType.transfer), isFalse, reason: '$g');
      }
    });

    test(
      'bawaan jenis: pemasukan = pendapatan, pengeluaran = beban operasional',
      () {
        expect(ReportGroup.defaultFor(TxType.income), ReportGroup.revenue);
        expect(ReportGroup.defaultFor(TxType.expense), ReportGroup.opex);
      },
    );

    test('urutan enum disimpan sebagai indeks: JANGAN diubah', () {
      expect(ReportGroup.values.map((g) => g.index), [0, 1, 2, 3, 4, 5]);
      expect(ReportGroup.values.map((g) => g.name), [
        'revenue',
        'cogs',
        'opex',
        'otherIncome',
        'otherExpense',
        'nonPnl',
      ]);
      expect(LedgerKind.values.map((k) => k.name), ['personal', 'business']);
    });
  });

  group('seed', () {
    test(
      'Buku Utama (pribadi): hanya Utang/Piutang di luar laba rugi',
      () async {
        final g = await groups();
        expect(g['cat-exp-utang'], ReportGroup.nonPnl);
        expect(g['cat-inc-piutang'], ReportGroup.nonPnl);
        expect(g['cat-exp-makan'], isNull);
        expect(g['cat-inc-gaji'], isNull);
        expect(
          (await db.watchLedgers().first).single.kind,
          LedgerKind.personal,
        );
      },
    );

    test(
      'template Bisnis: HPP, di luar laba rugi, dan pendapatan lain',
      () async {
        final biz = await addBiz();
        final g = await groups();
        String e(String k) => ledgerSeedId(biz, 'cat-exp-$k');
        String i(String k) => ledgerSeedId(biz, 'cat-inc-$k');
        expect(g[e('stok')], ReportGroup.cogs);
        expect(g[e('peralatan')], ReportGroup.nonPnl);
        expect(g[e('cicilan-usaha')], ReportGroup.nonPnl);
        expect(g[e('utang')], ReportGroup.nonPnl);
        expect(g[i('modal')], ReportGroup.nonPnl);
        expect(g[i('piutang')], ReportGroup.nonPnl);
        expect(g[i('pendapatan-lain')], ReportGroup.otherIncome);
        // Sisanya mengikuti bawaan jenis (kolom kosong).
        expect(g[i('penjualan')], isNull);
        expect(g[i('jasa')], isNull);
        expect(g[e('sewa')], isNull);
        expect(g[e('gaji-karyawan')], isNull);
      },
    );

    test(
      'sifat buku mengikuti template; template lain tetap pribadi',
      () async {
        final biz = await addBiz();
        final personal = await db.addLedger(
          name: 'Rumah',
          icon: 'home',
          color: 1,
        );
        final blank = await db.addLedger(
          name: 'Kosong',
          icon: 'home',
          color: 2,
          template: LedgerTemplate.blank,
        );
        final kinds = {
          for (final l in await db.select(db.ledgers).get()) l.id: l.kind,
        };
        expect(kinds[biz], LedgerKind.business);
        expect(kinds[personal], LedgerKind.personal);
        expect(kinds[blank], LedgerKind.personal);
      },
    );

    test(
      'kategori sistem Tabungan dan Penyesuaian Saldo di luar laba rugi',
      () async {
        await db.adjustAccountBalance(
          accountId: 'acc-tunai',
          actualBalance: 5000,
        );
        await db.adjustAccountBalance(
          accountId: 'acc-tunai',
          actualBalance: 1000,
        );
        final g = await groups();
        expect(g['cat-inc-penyesuaian'], ReportGroup.nonPnl);
        expect(g['cat-exp-penyesuaian'], ReportGroup.nonPnl);
      },
    );

    test('kategori buatan pengguna bernama sistem yang dipakai ulang ikut di luar laba rugi, '
        'kecuali pengguna sudah menentukan kelompoknya', () async {
      final mine = await db.addCategory(
        type: TxType.expense,
        name: 'Penyesuaian Saldo',
        icon: 'other',
        color: 1,
      );
      // Saldo awal 0: naik dulu (pemasukan), lalu turun (pengeluaran = jenis kategori ini).
      await db.adjustAccountBalance(
        accountId: 'acc-tunai',
        actualBalance: 5000,
      );
      await db.adjustAccountBalance(accountId: 'acc-tunai', actualBalance: 1);
      expect((await groups())[mine], ReportGroup.nonPnl);

      final chosen = await db.addCategory(
        type: TxType.expense,
        name: 'Tabungan',
        icon: 'savings',
        color: 1,
        reportGroup: ReportGroup.otherExpense,
      );
      expect((await groups())[chosen], ReportGroup.otherExpense);
    });
  });

  group('API', () {
    test('setCategoryReportGroup: menetapkan, mengganti, dan mengembalikan ke bawaan', () async {
      await db.setCategoryReportGroup('cat-exp-makan', ReportGroup.cogs);
      expect((await groups())['cat-exp-makan'], ReportGroup.cogs);
      await db.setCategoryReportGroup(
        'cat-exp-makan',
        ReportGroup.otherExpense,
      );
      expect((await groups())['cat-exp-makan'], ReportGroup.otherExpense);
      await db.setCategoryReportGroup('cat-exp-makan', null);
      expect((await groups())['cat-exp-makan'], isNull);
    });

    test('kelompok yang tidak cocok dengan jenis ditolak', () async {
      await expectLater(
        db.setCategoryReportGroup('cat-exp-makan', ReportGroup.revenue),
        categoryError(),
      );
      await expectLater(
        db.setCategoryReportGroup('cat-inc-gaji', ReportGroup.cogs),
        categoryError(),
      );
      await expectLater(
        db.addCategory(
          type: TxType.income,
          name: 'X',
          icon: 'other',
          color: 1,
          reportGroup: ReportGroup.opex,
        ),
        categoryError(),
      );
      expect((await groups())['cat-exp-makan'], isNull);
    });

    test('sub-kategori tidak punya kelompok sendiri', () async {
      final sub = await db.addCategory(
        type: TxType.expense,
        name: 'Warteg',
        icon: 'food',
        color: 1,
        parentId: 'cat-exp-makan',
      );
      await expectLater(
        db.setCategoryReportGroup(sub, ReportGroup.cogs),
        categoryError(),
      );
      await expectLater(
        db.addCategory(
          type: TxType.expense,
          name: 'Bakso',
          icon: 'food',
          color: 1,
          parentId: 'cat-exp-makan',
          reportGroup: ReportGroup.cogs,
        ),
        categoryError(),
      );
    });

    test('kategori yang dijadikan sub-kategori melepas kelompoknya', () async {
      final id = await db.addCategory(
        type: TxType.expense,
        name: 'Bahan',
        icon: 'shopping',
        color: 1,
        reportGroup: ReportGroup.cogs,
      );
      await db.updateCategory(
        id: id,
        name: 'Bahan',
        icon: 'shopping',
        color: 1,
        parentId: 'cat-exp-makan',
      );
      expect((await groups())[id], isNull);
    });

    test('updateCategory: menetapkan, mengosongkan, dan menolak kelompok yang tidak cocok', () async {
      Future<void> update(Value<ReportGroup?> g) => db.updateCategory(
        id: 'cat-exp-makan',
        name: 'Makanan & Minuman',
        icon: 'food',
        color: 1,
        reportGroup: g,
      );
      await update(const Value(ReportGroup.cogs));
      expect((await groups())['cat-exp-makan'], ReportGroup.cogs);
      await update(const Value.absent()); // tidak diubah
      expect((await groups())['cat-exp-makan'], ReportGroup.cogs);
      await expectLater(
        update(const Value(ReportGroup.revenue)),
        categoryError(),
      );
      expect((await groups())['cat-exp-makan'], ReportGroup.cogs);
      await update(const Value(null)); // kembali ke bawaan
      expect((await groups())['cat-exp-makan'], isNull);
    });

    test('mengubah nama/ikon kategori tidak mengubah kelompoknya', () async {
      await db.setCategoryReportGroup('cat-exp-makan', ReportGroup.cogs);
      await db.updateCategory(
        id: 'cat-exp-makan',
        name: 'Bahan Makanan',
        icon: 'food',
        color: 1,
      );
      expect((await groups())['cat-exp-makan'], ReportGroup.cogs);
    });

    test('setLedgerKind: bolak-balik, tanpa menyentuh data; buku tak dikenal ditolak', () async {
      await db.setLedgerKind(kMainLedgerId, LedgerKind.business);
      expect((await db.watchLedgers().first).single.kind, LedgerKind.business);
      expect((await db.watchAccountBalances().first).single.id, 'acc-tunai');
      await db.setLedgerKind(kMainLedgerId, LedgerKind.personal);
      expect((await db.watchLedgers().first).single.kind, LedgerKind.personal);
      await expectLater(
        db.setLedgerKind('tidak-ada', LedgerKind.business),
        throwsA(isA<LedgerException>()),
      );
    });
  });

  group('backup v9', () {
    Future<Map<String, dynamic>> backupMap(AppDatabase from) async =>
        jsonDecode(await BackupService(from).export()) as Map<String, dynamic>;

    test('versi format 9 dan kunci baru tertulis', () async {
      await db.setCategoryReportGroup('cat-exp-makan', ReportGroup.cogs);
      await db.setLedgerKind(kMainLedgerId, LedgerKind.business);
      final map = await backupMap(db);
      expect(map['version'], 9);
      expect(BackupService.formatVersion, 9);
      final cats = (map['categories'] as List).cast<Map<String, dynamic>>();
      expect(
        cats.firstWhere((c) => c['id'] == 'cat-exp-makan')['reportGroup'],
        ReportGroup.cogs.index,
      );
      expect(
        (map['ledgers'] as List).single['kind'],
        LedgerKind.business.index,
      );
    });

    test('putaran penuh: kelompok kategori dan sifat buku pulih', () async {
      final biz = await addBiz();
      await db.setCategoryReportGroup(
        'cat-exp-makan',
        ReportGroup.otherExpense,
      );
      final json = jsonEncode(await backupMap(db));

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).restore(BackupService.parse(json));

      final g = {
        for (final c in await other.select(other.categories).get())
          c.id: c.reportGroup,
      };
      expect(g['cat-exp-makan'], ReportGroup.otherExpense);
      expect(g[ledgerSeedId(biz, 'cat-exp-stok')], ReportGroup.cogs);
      expect(g['cat-exp-utang'], ReportGroup.nonPnl);
      expect(g['cat-inc-gaji'], isNull);
      final kinds = {
        for (final l in await other.select(other.ledgers).get()) l.id: l.kind,
      };
      expect(kinds[biz], LedgerKind.business);
      expect(kinds[kMainLedgerId], LedgerKind.personal);
    });

    test('backup lama (v8) tanpa kunci baru tetap pulih: buku pribadi, kelompok kosong', () async {
      final map = await backupMap(db);
      map['version'] = 8;
      for (final l in (map['ledgers'] as List).cast<Map<String, dynamic>>()) {
        l.remove('kind');
      }
      for (final c
          in (map['categories'] as List).cast<Map<String, dynamic>>()) {
        c.remove('reportGroup');
      }
      final data = BackupService.parse(jsonEncode(map));
      expect(data.ledgers.single.kind, LedgerKind.personal);
      expect(data.categories.every((c) => c.reportGroup == null), isTrue);

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).restore(data);
      expect(
        (await other.watchLedgers().first).single.kind,
        LedgerKind.personal,
      );
    });

    test('backup lama tanpa buku kas sama sekali (v6) tetap pulih sebagai buku pribadi', () async {
      final map = await backupMap(db);
      map['version'] = 6;
      map.remove('ledgers');
      for (final c
          in (map['categories'] as List).cast<Map<String, dynamic>>()) {
        c.remove('reportGroup');
      }
      final data = BackupService.parse(jsonEncode(map));
      expect(data.ledgers.single.kind, LedgerKind.personal);
    });

    test('nilai yang menyimpang ditolak sebagai backup rusak', () async {
      final subId = await db.addCategory(
        type: TxType.expense,
        name: 'Warteg',
        icon: 'food',
        color: 1,
        parentId: 'cat-exp-makan',
      );
      final base = await backupMap(db);
      void rejects(void Function(Map<String, dynamic> m) mutate) {
        final copy = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        mutate(copy);
        expect(
          () => BackupService.parse(jsonEncode(copy)),
          throwsA(isA<BackupException>()),
        );
      }

      Map<String, dynamic> cat(Map<String, dynamic> m, String id) =>
          (m['categories'] as List).cast<Map<String, dynamic>>().firstWhere(
            (c) => c['id'] == id,
          );

      // Indeks di luar rentang.
      rejects((m) => cat(m, 'cat-exp-makan')['reportGroup'] = 99);
      rejects((m) => (m['ledgers'] as List).first['kind'] = 7);
      // Kelompok tidak cocok dengan jenis.
      rejects(
        (m) =>
            cat(m, 'cat-exp-makan')['reportGroup'] = ReportGroup.revenue.index,
      );
      rejects(
        (m) => cat(m, 'cat-inc-gaji')['reportGroup'] = ReportGroup.cogs.index,
      );
      // Sub-kategori tidak boleh punya kelompok sendiri.
      rejects((m) {
        final sub = cat(m, subId);
        sub['reportGroup'] = ReportGroup.cogs.index;
      });
    });
  });
}
