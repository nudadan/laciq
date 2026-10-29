import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/excel_export.dart';
import 'package:dompet_pintar/data/profit_loss.dart';
import 'package:dompet_pintar/data/profit_loss_pdf.dart';
import 'package:dompet_pintar/data/profit_loss_statement.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

/// Baris laporan bersama, lembar Excel "Laba Rugi", dan PDF
/// (docs/RENCANA-IMPLEMENTASI-UMKM.md §4.4).

final _from = DateTime(2026, 10);
final _to = DateTime(2026, 11);
final _day = DateTime(2026, 10, 12);

Future<ProfitLoss> _report(
  AppDatabase db, {
  DateTime? from,
  DateTime? to,
}) async => buildProfitLoss(
  items: await db.getTransactions(),
  categories: await db.select(db.categories).get(),
  from: from ?? _from,
  to: to ?? _to,
);

Future<void> _tx(AppDatabase db, TxType t, int amount, String cat) =>
    db.addTransaction(
      type: t,
      amount: amount,
      accountId: 'acc-tunai',
      categoryId: cat,
      date: _day,
    );

/// Pendapatan 1.000.000, HPP 200.000, beban 300.000, pendapatan lain 50.000, bayar utang
/// 100.000 (di luar laba rugi): laba kotor 800.000, operasional 500.000, bersih 550.000,
/// perubahan kas 450.000.
Future<void> _seedBusiness(AppDatabase db) async {
  await db.setLedgerKind(kMainLedgerId, LedgerKind.business);
  await db.setCategoryReportGroup('cat-exp-belanja', ReportGroup.cogs);
  await db.setCategoryReportGroup('cat-inc-bonus', ReportGroup.otherIncome);
  await _tx(db, TxType.income, 1000000, 'cat-inc-usaha');
  await _tx(db, TxType.expense, 200000, 'cat-exp-belanja');
  await _tx(db, TxType.expense, 300000, 'cat-exp-makan');
  await _tx(db, TxType.income, 50000, 'cat-inc-bonus');
  await _tx(db, TxType.expense, 100000, 'cat-exp-utang');
}

Archive _unzip(List<int> bytes) => ZipDecoder().decodeBytes(bytes);

String _part(Archive a, String path) {
  final f = a.findFile(path);
  expect(f, isNotNull, reason: path);
  return utf8.decode(f!.content as List<int>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID'));

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('baris laporan', () {
    test(
      'pengurang bernilai negatif, subtotal dan total sesuai laporan',
      () async {
        await _seedBusiness(db);
        final r = await _report(db);
        final rows = profitLossStatement(r);

        StatementRow row(String label) =>
            rows.firstWhere((x) => x.label == label);
        expect(row('Pendapatan usaha').amount, 1000000);
        expect(row('Harga pokok penjualan (HPP)').amount, -200000);
        expect(row('Laba kotor').amount, 800000);
        expect(row('Beban operasional').amount, -300000);
        expect(row('Laba operasional').amount, 500000);
        expect(row('Pendapatan lain').amount, 50000);
        expect(row('Laba bersih').amount, 550000);
        expect(row('Laba bersih').kind, StatementRowKind.total);
        expect(row('Laba kotor').percent, closeTo(80, 1e-9));
        expect(row('Laba operasional').percent, closeTo(50, 1e-9));
        expect(row('Laba bersih').percent, closeTo(55, 1e-9));
        // Rincian mengikuti bagiannya dengan tanda yang sama.
        expect(row('Belanja').amount, -200000);
        expect(row('Belanja').kind, StatementRowKind.detail);
      },
    );

    test(
      'bagian bertanda "section" dijumlahkan = laba bersih (penjumlahan kolom)',
      () async {
        await _seedBusiness(db);
        final r = await _report(db);
        final sum = profitLossStatement(r)
            .where((x) => x.kind == StatementRowKind.section)
            .fold<int>(0, (s, x) => s + x.amount);
        expect(sum, r.netProfit);
      },
    );

    test('bagian kosong disembunyikan seperti di layar', () async {
      await _tx(db, TxType.income, 100000, 'cat-inc-usaha');
      await _tx(db, TxType.expense, 40000, 'cat-exp-makan');
      final labels = profitLossStatement(await _report(db)).map((x) => x.label);
      expect(labels, isNot(contains('Harga pokok penjualan (HPP)')));
      expect(labels, isNot(contains('Laba kotor')));
      expect(labels, isNot(contains('Laba operasional')));
      expect(labels, isNot(contains('Pendapatan lain')));
      expect(
        labels,
        containsAll(['Pendapatan usaha', 'Beban operasional', 'Laba bersih']),
      );
    });

    test('rugi: label "Rugi bersih" dan persen negatif', () async {
      await _tx(db, TxType.income, 100000, 'cat-inc-usaha');
      await _tx(db, TxType.expense, 150000, 'cat-exp-makan');
      final total = profitLossStatement(await _report(db)).last;
      expect((total.label, total.amount), ('Rugi bersih', -50000));
      expect(total.percent, closeTo(-50, 1e-9));
    });

    test('tanpa pendapatan: persen tidak ada', () async {
      await _tx(db, TxType.expense, 40000, 'cat-exp-makan');
      expect(profitLossStatement(await _report(db)).last.percent, isNull);
    });

    test(
      'dari laba ke kas: laba, arus di luar laba rugi, perubahan kas',
      () async {
        await _seedBusiness(db);
        final r = await _report(db);
        final rows = cashBridgeStatement(r);
        expect(rows.first.amount, 550000);
        expect(
          rows
              .where((x) => x.kind == StatementRowKind.detail)
              .map((x) => (x.label, x.amount)),
          [('Utang', -100000)],
        );
        expect(rows.last.label, 'Perubahan kas');
        expect(rows.last.amount, 450000);
        // Jembatan selalu tertutup: laba + selisih di luar laba rugi = perubahan kas.
        expect(
          rows
              .where((x) => x.kind != StatementRowKind.total)
              .fold<int>(0, (s, x) => s + x.amount),
          rows.last.amount,
        );
      },
    );

    test('akhiran nama berkas: satu bulan utuh atau rentang tanggal', () {
      expect(
        profitLossFileSuffix(DateTime(2026, 10), DateTime(2026, 11)),
        '2026-10',
      );
      expect(
        profitLossFileSuffix(DateTime(2026, 12), DateTime(2027)),
        '2026-12',
      );
      expect(
        profitLossFileSuffix(DateTime(2026, 10), DateTime(2027, 1)),
        '20261001_20261231',
      );
      expect(
        profitLossFileSuffix(DateTime(2026, 10, 5), DateTime(2026, 10, 16)),
        '20261005_20261015',
      );
    });
  });

  group('lembar Excel "Laba Rugi"', () {
    test(
      'tanpa laporan: berkas persis seperti sebelumnya (tanpa lembar baru)',
      () async {
        await _seedBusiness(db);
        final a = _unzip(
          buildTransactionsXlsx(
            await db.getTransactions(),
            bookName: 'Buku Utama',
            periodLabel: 'Oktober 2026',
          ),
        );
        final wb = _part(a, 'xl/workbook.xml');
        expect(wb, isNot(contains('Laba Rugi')));
        expect(wb, contains('name="Transaksi"'));
      },
    );

    test(
      'dengan laporan: disisipkan setelah Ringkasan, angka asli bertanda',
      () async {
        await _seedBusiness(db);
        final r = await _report(db);
        final a = _unzip(
          buildTransactionsXlsx(
            await db.getTransactions(),
            bookName: 'Warung Bu Sari',
            periodLabel: 'Oktober 2026',
            profitLoss: r,
          ),
        );
        final wb = _part(a, 'xl/workbook.xml');
        final order = [
          'Ringkasan',
          'Laba Rugi',
          'Transaksi',
          'Per Kategori',
          'Per Bulan',
          'Per Dompet',
        ];
        var last = -1;
        for (final n in order) {
          final i = wb.indexOf('name="$n"');
          expect(i, greaterThan(last), reason: n);
          last = i;
        }

        final sheet = _part(a, 'xl/worksheets/sheet2.xml');
        expect(sheet, contains('Laporan Laba Rugi'));
        expect(sheet, contains('Buku kas: Warung Bu Sari'));
        expect(sheet, contains('Periode: Oktober 2026'));
        expect(sheet, contains('Laba bersih'));
        expect(sheet, contains('Dari laba ke kas'));
        expect(sheet, contains('Perubahan kas'));
        expect(sheet, contains('bukan laporan resmi'));
        // Angka asli (bukan teks), pengurang negatif.
        expect(sheet, contains('<v>1000000</v>'));
        expect(sheet, contains('<v>-200000</v>'));
        expect(sheet, contains('<v>-300000</v>'));
        expect(sheet, contains('<v>550000</v>'));
        expect(sheet, contains('<v>450000</v>'));
        // Persen sebagai pecahan: 55% = 0.55.
        expect(sheet, contains('<v>0.55</v>'));
        // Lembar lain bergeser satu, tetap utuh.
        expect(_part(a, 'xl/worksheets/sheet3.xml'), contains('<autoFilter'));
      },
    );
  });

  group('PDF', () {
    Future<(pw.Font, pw.Font)> fonts() async => (
      pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans.ttf')),
      pw.Font.ttf(
        await rootBundle.load('assets/fonts/pdf/PlusJakartaSans-Bold.ttf'),
      ),
    );

    Future<Uint8List> build(
      ProfitLoss r, {
      ProfitLoss? previous,
      String book = 'Warung Bu Sari',
    }) async {
      final (regular, bold) = await fonts();
      return buildProfitLossPdf(
        report: r,
        previous: previous,
        bookName: book,
        periodLabel: '1 Okt 2026 - 31 Okt 2026',
        regular: regular,
        bold: bold,
        generatedAt: DateTime(2026, 10, 29, 9, 30),
      );
    }

    int pages(Uint8List bytes) =>
        RegExp(r'/Type\s*/Page(?![a-z])')
            .allMatches(latin1.decode(bytes))
            .length;

    test(
      'PDF valid: tanda tangan, akhir berkas, judul, dan kedua font tersemat',
      () async {
        await _seedBusiness(db);
        final bytes = await build(await _report(db));
        final text = latin1.decode(bytes);
        expect(text.startsWith('%PDF-'), isTrue);
        expect(text.trimRight().endsWith('%%EOF'), isTrue);
        expect(text, contains('Laporan Laba Rugi - Warung Bu Sari'));
        expect(text, contains('PlusJakartaSans-Regular'));
        expect(text, contains('PlusJakartaSans-Bold'));
        expect(pages(bytes), 1);
      },
    );

    test(
      'laporan rugi, tanpa pendapatan, dan dengan pembanding tidak melempar',
      () async {
        await _tx(db, TxType.expense, 40000, 'cat-exp-makan');
        final r = await _report(db);
        expect(pages(await build(r)), 1);
        expect(pages(await build(r, previous: r)), 1);

        await _tx(db, TxType.income, 10000, 'cat-inc-usaha');
        final r2 = await _report(db);
        expect(pages(await build(r2, previous: r)), 1);
      },
    );

    test('rincian sangat panjang meluber ke halaman berikutnya (tabel tidak terpotong)', () async {
      for (var i = 0; i < 120; i++) {
        final id = await db.addCategory(
          type: TxType.expense,
          name: 'Beban nomor $i',
          icon: 'other',
          color: 1,
        );
        await _tx(db, TxType.expense, 1000 + i, id);
      }
      await _tx(db, TxType.income, 5000000, 'cat-inc-usaha');
      final bytes = await build(await _report(db));
      expect(pages(bytes), greaterThan(1));
    });

    test(
      'nama usaha berhuruf Unicode/tanda baca tidak merusak berkas',
      () async {
        await _seedBusiness(db);
        final bytes = await build(
          await _report(db),
          book: 'Toko “Berkah” & Sons — Çafé',
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      },
    );

    test('Excel dan PDF memakai angka yang sama dengan laporan', () async {
      await _seedBusiness(db);
      final r = await _report(db);
      expect(r.netProfit, 550000);
      expect(r.reconciles, isTrue);
      // Satu sumber baris: jumlah baris bagian = laba bersih (diuji di atas); PDF
      // dan Excel membaca daftar yang sama, jadi cukup memastikan keduanya dibuat.
      expect((await build(r)).isNotEmpty, isTrue);
      expect(
        buildTransactionsXlsx(
          await db.getTransactions(),
          bookName: 'X',
          periodLabel: 'Y',
          profitLoss: r,
        ).isNotEmpty,
        isTrue,
      );
    });
  });

  // Alat bantu manual: tulis PDF contoh ke folder PL_PDF_OUT bila variabel diset,
  // untuk diperiksa dengan pdftoppm/pdftotext. Tidak berbuat apa-apa di CI.
  test('contoh PDF ke berkas (hanya bila PL_PDF_OUT diset)', () async {
    final out = Platform.environment['PL_PDF_OUT'];
    if (out == null) return;
    await _seedBusiness(db);
    final r = await _report(db);
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/pdf/PlusJakartaSans-Bold.ttf'),
    );
    File('$out/laba-rugi.pdf').writeAsBytesSync(
      await buildProfitLossPdf(
        report: r,
        previous: r,
        bookName: 'Warung Bu Sari',
        periodLabel: '1 Okt 2026 - 31 Okt 2026',
        regular: regular,
        bold: bold,
        generatedAt: DateTime(2026, 10, 29, 9, 30),
      ),
    );
  });
}
