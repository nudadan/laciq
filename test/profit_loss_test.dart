import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/profit_loss.dart';
import 'package:flutter_test/flutter_test.dart';

/// Laporan Laba Rugi berbasis kas (docs/RENCANA-IMPLEMENTASI-UMKM.md §4.3).
/// Yang terpenting: rekonsiliasi kas selalu cocok, apa pun pengelompokannya.

final _stamp = DateTime(2026, 9, 1);
final _acc = Account(
  id: 'a',
  name: 'Kas Usaha',
  kind: AccountKind.cash,
  ledgerId: kMainLedgerId,
  initialBalance: 0,
  archived: false,
  updatedAt: _stamp,
);

Category _cat(
  String id,
  String name,
  TxType type, {
  ReportGroup? group,
  String? parentId,
}) => Category(
  id: id,
  name: name,
  type: type,
  icon: 'other',
  color: 0xFF112233,
  sortOrder: 0,
  archived: false,
  ledgerId: kMainLedgerId,
  parentId: parentId,
  reportGroup: group,
  updatedAt: _stamp,
);

var _seq = 0;
TxView _tx(TxType type, int amount, DateTime date, {Category? category}) =>
    TxView(
      tx: TxEntry(
        id: 't${_seq++}',
        type: type,
        amount: amount,
        accountId: 'a',
        categoryId: category?.id,
        date: date,
        createdAt: _stamp,
        updatedAt: _stamp,
      ),
      account: _acc,
      category: category,
    );

final _oct = DateTime(2026, 10);
final _nov = DateTime(2026, 11);
final _day = DateTime(2026, 10, 10);

// Kategori contoh (bentuk template Bisnis).
final _penjualan = _cat('penjualan', 'Penjualan', TxType.income);
final _jasa = _cat('jasa', 'Jasa', TxType.income);
final _lainPendapatan = _cat(
  'p-lain',
  'Pendapatan Lain',
  TxType.income,
  group: ReportGroup.otherIncome,
);
final _modal = _cat(
  'modal',
  'Modal Masuk',
  TxType.income,
  group: ReportGroup.nonPnl,
);
final _stok = _cat(
  'stok',
  'Pembelian Stok',
  TxType.expense,
  group: ReportGroup.cogs,
);
final _sewa = _cat('sewa', 'Sewa Tempat', TxType.expense);
final _gaji = _cat('gaji', 'Gaji Karyawan', TxType.expense);
final _bungaDenda = _cat(
  'bunga',
  'Bunga & Denda',
  TxType.expense,
  group: ReportGroup.otherExpense,
);
final _peralatan = _cat(
  'alat',
  'Peralatan',
  TxType.expense,
  group: ReportGroup.nonPnl,
);

final _all = [
  _penjualan,
  _jasa,
  _lainPendapatan,
  _modal,
  _stok,
  _sewa,
  _gaji,
  _bungaDenda,
  _peralatan,
];

ProfitLoss _report(List<TxView> items, {List<Category>? categories}) =>
    buildProfitLoss(
      items: items,
      categories: categories ?? _all,
      from: _oct,
      to: _nov,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('perhitungan inti', () {
    final items = [
      _tx(TxType.income, 1000000, _day, category: _penjualan),
      _tx(TxType.income, 300000, _day, category: _jasa),
      _tx(TxType.income, 50000, _day, category: _lainPendapatan),
      _tx(TxType.income, 5000000, _day, category: _modal),
      _tx(TxType.expense, 400000, _day, category: _stok),
      _tx(TxType.expense, 100000, _day, category: _sewa),
      _tx(TxType.expense, 200000, _day, category: _gaji),
      _tx(TxType.expense, 20000, _day, category: _bungaDenda),
      _tx(TxType.expense, 700000, _day, category: _peralatan),
    ];

    test('laba kotor, operasional, dan bersih', () {
      final r = _report(items);
      expect(r.revenue.total, 1300000);
      expect(r.cogs.total, 400000);
      expect(r.grossProfit, 900000);
      expect(r.opex.total, 300000);
      expect(r.operatingProfit, 600000);
      expect(r.otherIncome.total, 50000);
      expect(r.otherExpense.total, 20000);
      expect(r.netProfit, 630000);
    });

    test('modal dan pembelian peralatan tidak memengaruhi laba, tetapi mengubah kas', () {
      final r = _report(items);
      expect(r.nonPnlIncome.total, 5000000);
      expect(r.nonPnlExpense.total, 700000);
      expect(r.nonPnlNet, 4300000);
      expect(r.cashIn, 6350000);
      expect(r.cashOut, 1420000);
      expect(r.cashChange, 4930000);
      expect(r.netProfit + r.nonPnlNet, r.cashChange);
      expect(r.reconciles, isTrue);
    });

    test('rincian per kategori, terbesar lebih dulu', () {
      final r = _report(items);
      expect(r.revenue.lines.map((l) => (l.name, l.amount)), [
        ('Penjualan', 1000000),
        ('Jasa', 300000),
      ]);
      expect(r.opex.lines.map((l) => l.name), ['Gaji Karyawan', 'Sewa Tempat']);
    });

    test('margin dalam persen terhadap pendapatan usaha', () {
      final r = _report(items);
      expect(r.grossMarginPercent, closeTo(900000 * 100 / 1300000, 1e-9));
      expect(r.netMarginPercent, closeTo(630000 * 100 / 1300000, 1e-9));
    });

    test('margin null bila tidak ada pendapatan; rugi tampil negatif', () {
      final onlyCost = _report([
        _tx(TxType.expense, 100000, _day, category: _sewa),
      ]);
      expect(onlyCost.revenue.total, 0);
      expect(onlyCost.netProfit, -100000);
      expect(onlyCost.netMarginPercent, isNull);
      expect(onlyCost.grossMarginPercent, isNull);

      final loss = _report([
        _tx(TxType.income, 100000, _day, category: _penjualan),
        _tx(TxType.expense, 150000, _day, category: _stok),
      ]);
      expect(loss.netProfit, -50000);
      expect(loss.netMarginPercent, closeTo(-50, 1e-9));
      expect(loss.reconciles, isTrue);
    });

    test('rentang kosong: semua nol dan tetap cocok', () {
      final r = _report([]);
      expect(r.isEmpty, isTrue);
      expect((r.netProfit, r.cashChange, r.transactionCount), (0, 0, 0));
      expect(r.reconciles, isTrue);
    });

    test('urutan sama besar diurutkan menurut nama', () {
      final r = _report([
        _tx(TxType.expense, 100, _day, category: _sewa),
        _tx(TxType.expense, 100, _day, category: _gaji),
      ]);
      expect(r.opex.lines.map((l) => l.name), ['Gaji Karyawan', 'Sewa Tempat']);
    });
  });

  group('rentang dan transfer', () {
    test('awal rentang termasuk, akhir rentang tidak', () {
      final r = _report([
        _tx(
          TxType.income,
          1,
          DateTime(2026, 9, 30, 23, 59),
          category: _penjualan,
        ),
        _tx(TxType.income, 10, _oct, category: _penjualan),
        _tx(
          TxType.income,
          100,
          DateTime(2026, 10, 31, 23, 59),
          category: _penjualan,
        ),
        _tx(TxType.income, 1000, _nov, category: _penjualan),
      ]);
      expect(r.revenue.total, 110);
      expect(r.transactionCount, 2);
      expect(r.reconciles, isTrue);
    });

    test('transfer antar dompet diabaikan sepenuhnya', () {
      final r = _report([
        _tx(TxType.transfer, 999999, _day),
        _tx(TxType.income, 100, _day, category: _penjualan),
      ]);
      expect(r.cashIn, 100);
      expect(r.cashOut, 0);
      expect(r.transactionCount, 1);
    });
  });

  group('kategori', () {
    test('sub-kategori digabung ke induk dan memakai kelompok induk', () {
      final bahan = _cat(
        'bahan',
        'Bahan Baku',
        TxType.expense,
        group: ReportGroup.cogs,
      );
      final tepung = _cat(
        'tepung',
        'Tepung',
        TxType.expense,
        parentId: 'bahan',
      );
      final gula = _cat('gula', 'Gula', TxType.expense, parentId: 'bahan');
      final r = _report(
        [
          _tx(TxType.expense, 40000, _day, category: tepung),
          _tx(TxType.expense, 10000, _day, category: gula),
          _tx(TxType.expense, 5000, _day, category: bahan),
        ],
        categories: [bahan, tepung, gula],
      );
      expect(r.cogs.lines.single.name, 'Bahan Baku');
      expect(r.cogs.lines.single.amount, 55000);
      expect(r.opex.total, 0);
      expect(r.reconciles, isTrue);
    });

    test('sub-kategori yang induknya tidak ditemukan tetap terhitung (sebagai dirinya)', () {
      final orphan = _cat('o', 'Yatim', TxType.expense, parentId: 'hilang');
      final r = _report(
        [_tx(TxType.expense, 7, _day, category: orphan)],
        categories: [orphan],
      );
      expect(r.opex.total, 7);
      expect(r.reconciles, isTrue);
    });

    test('tanpa kategori: bawaan jenis, ditandai belum dikelompokkan', () {
      final r = _report([
        _tx(TxType.income, 500, _day),
        _tx(TxType.expense, 200, _day),
      ]);
      expect(r.revenue.lines.single.name, 'Tanpa kategori');
      expect(r.revenue.lines.single.categoryId, isNull);
      expect(r.opex.lines.single.name, 'Tanpa kategori');
      expect(r.defaultGroupLines.length, 2);
      expect(r.reconciles, isTrue);
    });

    test(
      'isDefaultGroup: pilihan pengguna/sistem = false, kolom kosong = true',
      () {
        final r = _report([
          _tx(TxType.income, 1, _day, category: _penjualan), // kosong
          _tx(TxType.income, 1, _day, category: _lainPendapatan), // dipilih
          _tx(TxType.expense, 1, _day, category: _stok), // dipilih
          _tx(TxType.expense, 1, _day, category: _sewa), // kosong
        ]);
        bool def(ProfitLossSection s, String name) =>
            s.lines.firstWhere((l) => l.name == name).isDefaultGroup;
        expect(def(r.revenue, 'Penjualan'), isTrue);
        expect(def(r.otherIncome, 'Pendapatan Lain'), isFalse);
        expect(def(r.cogs, 'Pembelian Stok'), isFalse);
        expect(def(r.opex, 'Sewa Tempat'), isTrue);
        expect(r.defaultGroupLines.map((l) => l.name).toSet(), {
          'Penjualan',
          'Sewa Tempat',
        });
      },
    );

    test('kelompok yang tidak cocok dengan jenis transaksi jatuh ke bawaan, tidak hilang', () {
      // Data menyimpang (mustahil lewat API/backup, tetapi laporan tidak boleh
      // menghilangkan uang): kategori berkelompok HPP dipakai transaksi pemasukan.
      final odd = _cat('odd', 'Aneh', TxType.expense, group: ReportGroup.cogs);
      final r = _report(
        [_tx(TxType.income, 300, _day, category: odd)],
        categories: [odd],
      );
      expect(r.revenue.total, 300);
      expect(r.cogs.total, 0);
      expect(r.reconciles, isTrue);
    });

    test('kategori dicari dari daftar bila TxView tidak membawanya', () {
      final item = TxView(
        tx: TxEntry(
          id: 'x',
          type: TxType.expense,
          amount: 90,
          accountId: 'a',
          categoryId: 'stok',
          date: _day,
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
        account: _acc,
      );
      expect(_report([item]).cogs.total, 90);
    });

    test(
      'kategori di luar laba rugi dipisah menurut arah (modal masuk vs prive)',
      () {
        final prive = _cat(
          'prive',
          'Prive',
          TxType.expense,
          group: ReportGroup.nonPnl,
        );
        final r = _report(
          [
            _tx(TxType.income, 1000, _day, category: _modal),
            _tx(TxType.expense, 300, _day, category: prive),
          ],
          categories: [_modal, prive],
        );
        expect(r.nonPnlIncome.lines.single.name, 'Modal Masuk');
        expect(r.nonPnlExpense.lines.single.name, 'Prive');
        expect(r.netProfit, 0);
        expect(r.cashChange, 700);
        expect(r.reconciles, isTrue);
      },
    );
  });

  group('effectiveReportGroup', () {
    test('bawaan jenis bila kosong', () {
      expect(effectiveReportGroup(_penjualan), ReportGroup.revenue);
      expect(effectiveReportGroup(_sewa), ReportGroup.opex);
    });

    test('pilihan pada kategori, dan induk menentukan bagi sub-kategori', () {
      expect(effectiveReportGroup(_stok), ReportGroup.cogs);
      final sub = _cat('s', 'Sub', TxType.expense, parentId: 'stok');
      expect(effectiveReportGroup(sub, parent: _stok), ReportGroup.cogs);
    });

    test('nilai yang tidak cocok dengan jenis jatuh ke bawaan', () {
      final odd = _cat('odd', 'Aneh', TxType.income, group: ReportGroup.cogs);
      expect(effectiveReportGroup(odd), ReportGroup.revenue);
    });
  });

  group('pembanding', () {
    test('changePercent', () {
      expect(changePercent(150, 100), closeTo(50, 1e-9));
      expect(changePercent(50, 100), closeTo(-50, 1e-9));
      expect(changePercent(10, 0), isNull);
      // Dari rugi ke laba tetap positif (pembagi mutlak).
      expect(changePercent(50, -100), closeTo(150, 1e-9));
    });

    test('rentang satu bulan penuh -> bulan sebelumnya yang tepat', () {
      final p = previousPeriod(DateTime(2026, 10), DateTime(2026, 11));
      expect((p.from, p.to), (DateTime(2026, 9), DateTime(2026, 10)));
      final mar = previousPeriod(DateTime(2026, 3), DateTime(2026, 4));
      expect((mar.from, mar.to), (DateTime(2026, 2), DateTime(2026, 3)));
    });

    test(
      'kelipatan bulan: tiga bulan -> tiga bulan sebelumnya, lintas tahun',
      () {
        final p = previousPeriod(DateTime(2026, 7), DateTime(2026, 10));
        expect((p.from, p.to), (DateTime(2026, 4), DateTime(2026, 7)));
        final y = previousPeriod(DateTime(2026, 1), DateTime(2026, 2));
        expect((y.from, y.to), (DateTime(2025, 12), DateTime(2026, 1)));
        final year = previousPeriod(DateTime(2026), DateTime(2027));
        expect((year.from, year.to), (DateTime(2025), DateTime(2026)));
      },
    );

    test('rentang bebas: mundur sejumlah hari yang sama', () {
      final p = previousPeriod(DateTime(2026, 10, 10), DateTime(2026, 10, 20));
      expect((p.from, p.to), (DateTime(2026, 9, 30), DateTime(2026, 10, 10)));
    });

    test('tidak terpengaruh pergantian jam (selisih hari kalender)', () {
      final p = previousPeriod(
        DateTime(2026, 3, 1, 12),
        DateTime(2026, 3, 8, 12),
      );
      expect(p.to, DateTime(2026, 3, 1, 12));
      expect(p.from, DateTime(2026, 2, 22, 12));
    });
  });

  group('rekonsiliasi (uji properti, seed tetap)', () {
    test(
      'laba + selisih di luar laba rugi = perubahan kas, untuk data acak',
      () {
        for (var seed = 0; seed < 60; seed++) {
          final rnd = Random(seed);
          // Kategori acak: pemasukan/pengeluaran, kelompok acak yang sah (atau kosong),
          // sebagian sub-kategori.
          final cats = <Category>[];
          for (var i = 0; i < 12; i++) {
            final type = rnd.nextBool() ? TxType.income : TxType.expense;
            final allowed = ReportGroup.values
                .where((g) => g.allowedFor(type))
                .toList();
            final group = rnd.nextInt(4) == 0
                ? null
                : allowed[rnd.nextInt(allowed.length)];
            final tops = cats
                .where((c) => c.parentId == null && c.type == type)
                .toList();
            final makeSub = tops.isNotEmpty && rnd.nextInt(3) == 0;
            cats.add(
              makeSub
                  ? _cat(
                      'c$i',
                      'K$i',
                      type,
                      parentId: tops[rnd.nextInt(tops.length)].id,
                    )
                  : _cat('c$i', 'K$i', type, group: group),
            );
          }
          final items = <TxView>[];
          for (var i = 0; i < 300; i++) {
            final kind = rnd.nextInt(10);
            final type = kind == 0
                ? TxType.transfer
                : (kind < 5 ? TxType.income : TxType.expense);
            final sameType = cats.where((c) => c.type == type).toList();
            final category =
                type == TxType.transfer ||
                    sameType.isEmpty ||
                    rnd.nextInt(8) == 0
                ? null
                : sameType[rnd.nextInt(sameType.length)];
            // Tersebar di sekitar rentang (sebagian di luar).
            final date = DateTime(
              2026,
              9,
              20,
            ).add(Duration(days: rnd.nextInt(50)));
            items.add(
              _tx(type, 1 + rnd.nextInt(5000000), date, category: category),
            );
          }
          final r = _report(items, categories: cats);
          expect(r.reconciles, isTrue, reason: 'seed $seed');
          expect(r.netProfit + r.nonPnlNet, r.cashChange, reason: 'seed $seed');

          // Oracle terpisah: jumlah mentah dari transaksi dalam rentang.
          var inSum = 0;
          var outSum = 0;
          for (final v in items) {
            final t = v.tx;
            if (t.type == TxType.transfer) continue;
            if (t.date.isBefore(_oct) || !t.date.isBefore(_nov)) continue;
            if (t.type == TxType.income) {
              inSum += t.amount;
            } else {
              outSum += t.amount;
            }
          }
          expect(r.cashIn, inSum, reason: 'seed $seed');
          expect(r.cashOut, outSum, reason: 'seed $seed');
          // Seluruh pemasukan/pengeluaran terbagi habis ke bagian laporan.
          expect(
            r.revenue.total + r.otherIncome.total + r.nonPnlIncome.total,
            inSum,
            reason: 'seed $seed',
          );
          expect(
            r.cogs.total +
                r.opex.total +
                r.otherExpense.total +
                r.nonPnlExpense.total,
            outSum,
            reason: 'seed $seed',
          );
        }
      },
    );
  });

  group('dengan database nyata (template Bisnis)', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('semua jenis arus kas: laba benar dan selisih saldo dompet cocok dengan perubahan kas', () async {
      final biz = await db.addLedger(
        name: 'Warung',
        icon: 'business',
        color: 1,
        template: LedgerTemplate.business,
      );
      String cat(String t, String k) => ledgerSeedId(biz, 'cat-$t-$k');
      final acc = ledgerSeedId(biz, 'acc-tunai');
      final d = DateTime(2026, 10, 12);

      Future<void> add(TxType type, int amount, String category) =>
          db.addTransaction(
            type: type,
            amount: amount,
            accountId: acc,
            categoryId: category,
            date: d,
          );

      await add(
        TxType.income,
        5000000,
        cat('inc', 'modal'),
      ); // modal: di luar laba
      await add(TxType.income, 2000000, cat('inc', 'penjualan'));
      await add(TxType.income, 500000, cat('inc', 'jasa'));
      await add(TxType.income, 40000, cat('inc', 'pendapatan-lain'));
      await add(TxType.expense, 900000, cat('exp', 'stok')); // HPP
      await add(TxType.expense, 300000, cat('exp', 'sewa'));
      await add(TxType.expense, 150000, cat('exp', 'utilitas'));
      await add(TxType.expense, 1200000, cat('exp', 'peralatan')); // aset
      await add(
        TxType.expense,
        250000,
        cat('exp', 'cicilan-usaha'),
      ); // pokok pinjaman
      await add(
        TxType.income,
        100000,
        cat('inc', 'piutang'),
      ); // pelunasan piutang
      await add(TxType.expense, 80000, cat('exp', 'utang')); // bayar utang
      // Koreksi saldo (kategori sistem) juga di luar laba rugi.
      await db.adjustAccountBalance(
        accountId: acc,
        actualBalance:
            5000000 +
            2000000 +
            500000 +
            40000 +
            100000 -
            (900000 + 300000 + 150000 + 1200000 + 250000 + 80000) -
            25000,
        date: d,
      );

      final r = buildProfitLoss(
        items: await db.getTransactions(ledgerId: biz),
        categories: await db.select(db.categories).get(),
        from: DateTime(2026, 10),
        to: DateTime(2026, 11),
      );

      expect(r.revenue.total, 2500000);
      expect(r.cogs.total, 900000);
      expect(r.grossProfit, 1600000);
      expect(r.opex.total, 450000);
      expect(r.operatingProfit, 1150000);
      expect(r.otherIncome.total, 40000);
      expect(r.netProfit, 1190000);
      // Modal, piutang masuk, penyesuaian (selisih -25.000) | aset, cicilan, utang.
      expect(r.nonPnlIncome.total, 5000000 + 100000);
      expect(r.nonPnlExpense.total, 1200000 + 250000 + 80000 + 25000);
      expect(r.reconciles, isTrue);

      final balance = (await db.watchAccountBalances(ledgerId: biz).first)
          .firstWhere((b) => b.id == acc)
          .balance;
      expect(r.cashChange, balance); // saldo awal dompet baru = 0
    });
  });
}
