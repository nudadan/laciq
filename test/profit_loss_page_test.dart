import 'package:dompet_pintar/core/money.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Layar Laba Rugi (docs/RENCANA-IMPLEMENTASI-UMKM.md §4.4-§4.5).

Future<void> _openProfitLoss(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Laba Rugi'));
  await settle(tester);
}

final _now = DateTime.now();
final _thisMonth = DateTime(_now.year, _now.month, 1, 12);
final _lastMonth = DateTime(_now.year, _now.month - 1, 15, 12);

Future<void> _tx(
  AppDatabase db,
  TxType type,
  int amount,
  String category,
  DateTime date,
) => db.addTransaction(
  type: type,
  amount: amount,
  accountId: 'acc-tunai',
  categoryId: category,
  date: date,
);

/// Buku usaha dengan angka yang mudah dihitung:
/// pendapatan 1.000.000, HPP 200.000, beban operasional 300.000, pendapatan lain 50.000,
/// bayar utang 100.000 (di luar laba rugi). Laba kotor 800.000, operasional 500.000,
/// bersih 550.000, perubahan kas 450.000.
Future<void> _seedBusiness(AppDatabase db) async {
  await db.setLedgerKind(kMainLedgerId, LedgerKind.business);
  await db.setCategoryReportGroup('cat-exp-belanja', ReportGroup.cogs);
  await db.setCategoryReportGroup('cat-inc-bonus', ReportGroup.otherIncome);
  await _tx(db, TxType.income, 1000000, 'cat-inc-usaha', _thisMonth);
  await _tx(db, TxType.expense, 200000, 'cat-exp-belanja', _thisMonth);
  await _tx(db, TxType.expense, 300000, 'cat-exp-makan', _thisMonth);
  await _tx(db, TxType.income, 50000, 'cat-inc-bonus', _thisMonth);
  await _tx(db, TxType.expense, 100000, 'cat-exp-utang', _thisMonth);
}

/// Nominal (teks terakhir) pada baris [_Row] bertanda [key].
String _rowAmount(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
    )
    .last
    .data!;

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('akses paket', () {
    appTest('Gratis: Laba Rugi menawarkan upgrade, tidak membuka laporan', (
      tester,
      h,
    ) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Lainnya'),
        ),
      );
      await settle(tester);
      expect(find.text('Laba Rugi'), findsOneWidget);
      await tester.tap(find.text('Laba Rugi'));
      await settle(tester);
      expect(find.text('LaciQ Premium'), findsOneWidget);
      expect(find.byKey(const Key('pl-net')), findsNothing);
    }, subscription: FakeSubscriptionStatus());

    appTest('Premium: membuka laporan', (tester, h) async {
      await _openProfitLoss(tester);
      expect(find.text('Laba Rugi'), findsOneWidget); // judul AppBar
    }, subscription: FakeSubscriptionStatus(premium: true));
  });

  group('perhitungan di layar', () {
    appTest(
      'buku usaha: laba kotor, operasional, bersih, margin, dan kas',
      (tester, h) async {
        await _openProfitLoss(tester);
        expect(_text(tester, 'pl-net'), rupiah(550000));
        expect(find.text('Laba bersih'), findsWidgets);
        expect(_text(tester, 'pl-margin'), '55,0% dari pendapatan usaha');

        // Rincian bertingkat.
        expect(find.text('Pendapatan usaha'), findsOneWidget);
        expect(find.text('Harga pokok penjualan (HPP)'), findsOneWidget);
        expect(find.text('Beban operasional'), findsOneWidget);
        expect(find.text('Pendapatan lain'), findsOneWidget);
        expect(find.text('Laba kotor'), findsOneWidget);
        expect(find.text('Laba operasional'), findsOneWidget);
        expect(find.text('- ${rupiah(200000)}'), findsWidgets);
        expect(find.text(rupiah(800000)), findsOneWidget); // laba kotor
        expect(find.text(rupiah(500000)), findsOneWidget); // laba operasional

        // Dari laba ke kas: bayar utang di luar laba rugi; kas = 450.000.
        expect(find.text('Utang'), findsOneWidget);
        expect(find.text('- ${rupiah(100000)}'), findsOneWidget);
        expect(_rowAmount(tester, 'pl-cash'), rupiah(450000));

        // Kartu ringkas.
        expect(find.text(rupiah(1000000)), findsWidgets); // pendapatan
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: _seedBusiness,
    );

    appTest(
      'kategori berkelompok otomatis ditandai dan dijelaskan',
      (tester, h) async {
        await _openProfitLoss(tester);
        // "Usaha" (pendapatan) dan "Makanan & Minuman" (beban) memakai bawaan jenis.
        expect(find.text('otomatis'), findsNWidgets(2));
        expect(
          find.textContaining('2 kategori memakai pengelompokan otomatis'),
          findsOneWidget,
        );
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: _seedBusiness,
    );

    appTest(
      'rugi bersih ditampilkan sebagai "Rugi bersih" dengan nilai positif',
      (tester, h) async {
        await _openProfitLoss(tester);
        expect(find.text('Rugi bersih'), findsWidgets);
        expect(_text(tester, 'pl-net'), rupiah(150000));
        expect(_text(tester, 'pl-margin'), '-50,0% dari pendapatan usaha');
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: (db) async {
        await db.setLedgerKind(kMainLedgerId, LedgerKind.business);
        await _tx(db, TxType.income, 300000, 'cat-inc-usaha', _thisMonth);
        await _tx(db, TxType.expense, 450000, 'cat-exp-makan', _thisMonth);
      },
    );

    appTest(
      'tanpa pendapatan: margin tidak dihitung',
      (tester, h) async {
        await _openProfitLoss(tester);
        expect(
          _text(tester, 'pl-margin'),
          'Belum ada pendapatan usaha pada periode ini',
        );
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: (db) async {
        await db.setLedgerKind(kMainLedgerId, LedgerKind.business);
        await _tx(db, TxType.expense, 100000, 'cat-exp-makan', _thisMonth);
      },
    );

    appTest('periode kosong: keadaan kosong', (tester, h) async {
      await _openProfitLoss(tester);
      expect(
        find.textContaining('Belum ada transaksi pada periode ini'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pl-net')), findsNothing);
    }, subscription: FakeSubscriptionStatus(premium: true));
  });

  group('pembanding dan periode', () {
    appTest(
      'dibanding periode sebelumnya: naik dan turun',
      (tester, h) async {
        await _openProfitLoss(tester);
        // Bulan ini bersih 550.000; bulan lalu 500.000 -> naik 10,0%.
        expect(
          _text(tester, 'pl-change'),
          '▲ 10,0% dibanding periode sebelumnya (${rupiah(500000)})',
        );
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: (db) async {
        await _seedBusiness(db);
        await _tx(db, TxType.income, 500000, 'cat-inc-usaha', _lastMonth);
      },
    );

    appTest(
      'tanpa pembanding: baris perubahan tidak tampil',
      (tester, h) async {
        await _openProfitLoss(tester);
        expect(find.byKey(const Key('pl-change')), findsNothing);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: _seedBusiness,
    );

    appTest(
      'pilihan 3 Bulan memasukkan bulan lalu; Bulan hanya bulan ini',
      (tester, h) async {
        await _openProfitLoss(tester);
        expect(_text(tester, 'pl-net'), rupiah(550000));
        await tester.tap(find.text('3 Bulan'));
        await settle(tester);
        expect(_text(tester, 'pl-net'), rupiah(1050000));
        await tester.tap(find.text('Bulan'));
        await settle(tester);
        expect(_text(tester, 'pl-net'), rupiah(550000));
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: (db) async {
        await _seedBusiness(db);
        await _tx(db, TxType.income, 500000, 'cat-inc-usaha', _lastMonth);
      },
    );

    appTest(
      'pilihan Tahun: label rentang setahun penuh dan bisa mundur setahun',
      (tester, h) async {
        await _openProfitLoss(tester);
        await tester.tap(find.text('Tahun'));
        await settle(tester);
        expect(
          _text(tester, 'pl-range'),
          startsWith('1 Jan ${_now.year} - 31 Des ${_now.year}'),
        );
        await tester.tap(find.byTooltip('Tahun sebelumnya'));
        await settle(tester);
        expect(
          _text(tester, 'pl-range'),
          startsWith('1 Jan ${_now.year - 1} - 31 Des ${_now.year - 1}'),
        );
        // Tahun lalu kosong.
        expect(
          find.textContaining('Belum ada transaksi pada periode ini'),
          findsOneWidget,
        );
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: _seedBusiness,
    );

    appTest(
      'label rentang bulan: hari terakhir bulan, bukan awal bulan berikutnya',
      (tester, h) async {
        await _openProfitLoss(tester);
        final last = DateTime(_now.year, _now.month + 1, 0).day;
        expect(
          _text(tester, 'pl-range'),
          allOf(startsWith('1 '), contains(' - $last ')),
        );
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: _seedBusiness,
    );
  });

  group('mode usaha', () {
    appTest(
      'buku pribadi: ajakan menyalakan Mode usaha; laporan tetap terbaca',
      (tester, h) async {
        await _openProfitLoss(tester);
        expect(find.text('Buku ini belum Mode usaha'), findsOneWidget);
        // Pengelompokan bawaan: pemasukan = pendapatan, pengeluaran = beban.
        expect(_text(tester, 'pl-net'), rupiah(700000));
        expect(find.byKey(const Key('pl-default-note')), findsNothing);

        await tester.tap(find.text('Nyalakan Mode usaha'));
        await settle(tester);
        expect(find.text('Buku ini belum Mode usaha'), findsNothing);
        final ledger = (await tester.runAsync(() => h.db.watchLedgers().first))!
            .firstWhere((l) => l.id == kMainLedgerId);
        expect(ledger.kind, LedgerKind.business);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: (db) async {
        await _tx(db, TxType.income, 1000000, 'cat-inc-usaha', _thisMonth);
        await _tx(db, TxType.expense, 300000, 'cat-exp-makan', _thisMonth);
      },
    );

    appTest(
      'mengubah kelompok kategori mengubah laporan seketika',
      (tester, h) async {
        await _openProfitLoss(tester);
        expect(
          _text(tester, 'pl-net'),
          rupiah(700000),
        ); // belanja = beban (bawaan)

        // Belanja dipindah ke "di luar laba rugi": laba naik.
        await tester.runAsync(
          () => h.db.setCategoryReportGroup(
            'cat-exp-belanja',
            ReportGroup.nonPnl,
          ),
        );
        await settle(tester);
        expect(_text(tester, 'pl-net'), rupiah(1000000));
        expect(
          find.text('Belanja'),
          findsOneWidget,
        ); // kini di "Dari laba ke kas"
        expect(_rowAmount(tester, 'pl-cash'), rupiah(700000));
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: (db) async {
        await db.setLedgerKind(kMainLedgerId, LedgerKind.business);
        await _tx(db, TxType.income, 1000000, 'cat-inc-usaha', _thisMonth);
        await _tx(db, TxType.expense, 300000, 'cat-exp-belanja', _thisMonth);
      },
    );

    appTest(
      'transaksi baru muncul tanpa membuka ulang layar',
      (tester, h) async {
        await _openProfitLoss(tester);
        expect(_text(tester, 'pl-net'), rupiah(100000));
        await tester.runAsync(
          () => _tx(h.db, TxType.income, 250000, 'cat-inc-usaha', _thisMonth),
        );
        await settle(tester);
        expect(_text(tester, 'pl-net'), rupiah(350000));
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: (db) async {
        await db.setLedgerKind(kMainLedgerId, LedgerKind.business);
        await _tx(db, TxType.income, 100000, 'cat-inc-usaha', _thisMonth);
      },
    );
  });

  appTest(
    'catatan: bukan laporan resmi dan penjualan kredit',
    (tester, h) async {
      await _openProfitLoss(tester);
      expect(find.textContaining('bukan laporan resmi'), findsOneWidget);
      expect(find.textContaining('Penjualan secara kredit'), findsOneWidget);
    },
    subscription: FakeSubscriptionStatus(premium: true),
    seed: _seedBusiness,
  );
}
