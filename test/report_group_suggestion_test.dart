import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/report_group_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReportGroup? exp(String n) => suggestReportGroup(TxType.expense, n);
  ReportGroup? inc(String n) => suggestReportGroup(TxType.income, n);

  group('pengeluaran', () {
    test('HPP: stok dan bahan baku', () {
      for (final n in [
        'Pembelian Stok / Bahan Baku',
        'Beli stok',
        'Bahan baku',
        'Kulakan',
        'Barang dagangan',
        'Kemasan & packaging',
        'HPP',
        'Biaya produksi',
      ]) {
        expect(exp(n), ReportGroup.cogs, reason: n);
      }
    });

    test(
      'di luar laba rugi: prive, peralatan, aset, pokok cicilan, tabungan',
      () {
        for (final n in [
          'Prive',
          'Pembelian Peralatan',
          'Peralatan',
          'Beli mesin kopi',
          'Kendaraan usaha',
          'Cicilan Usaha',
          'Angsuran pokok',
          'Setor tabungan',
          'Bayar utang',
        ]) {
          expect(exp(n), ReportGroup.nonPnl, reason: n);
        }
      },
    );

    test('beban lain: bunga dan denda', () {
      for (final n in ['Bunga pinjaman', 'Denda keterlambatan', 'Kerugian']) {
        expect(exp(n), ReportGroup.otherExpense, reason: n);
      }
    });

    test('"di luar laba rugi" didahulukan: Pembelian Peralatan bukan HPP', () {
      expect(exp('Pembelian Peralatan'), ReportGroup.nonPnl);
      expect(exp('Pembelian Stok'), ReportGroup.cogs);
    });

    test('bahan bakar bukan HPP (biaya operasional, jangan ditebak)', () {
      expect(exp('Bahan bakar'), isNull);
      expect(exp('BBM motor'), isNull);
    });

    test('nama yang tidak dikenali: tidak menebak', () {
      for (final n in [
        'Sewa Tempat',
        'Gaji Karyawan',
        'Listrik',
        'Iklan',
        'Lainnya',
      ]) {
        expect(exp(n), isNull, reason: n);
      }
    });
  });

  group('pemasukan', () {
    test('di luar laba rugi: modal, pinjaman, piutang, setoran', () {
      for (final n in [
        'Modal Masuk',
        'Pinjaman bank',
        'Piutang',
        'Setoran pemilik',
      ]) {
        expect(inc(n), ReportGroup.nonPnl, reason: n);
      }
    });

    test('pendapatan lain: bunga, hadiah, cashback', () {
      for (final n in ['Pendapatan Lain', 'Bunga bank', 'Hadiah', 'Cashback']) {
        expect(inc(n), ReportGroup.otherIncome, reason: n);
      }
    });

    test('penjualan dan jasa: tidak menebak (bawaan = pendapatan usaha)', () {
      for (final n in ['Penjualan', 'Jasa', 'Omzet harian']) {
        expect(inc(n), isNull, reason: n);
      }
    });
  });

  test('tahan huruf besar, tanda baca, spasi, dan teks kosong', () {
    expect(exp('  PEMBELIAN-STOK!!  '), ReportGroup.cogs);
    expect(exp(''), isNull);
    expect(exp('   '), isNull);
    expect(suggestReportGroup(TxType.transfer, 'Stok'), isNull);
  });

  test('saran selalu cocok dengan jenisnya', () {
    for (final n in [
      'Stok',
      'Modal',
      'Prive',
      'Bunga',
      'Peralatan',
      'Hadiah',
      'Tabungan',
    ]) {
      for (final t in [TxType.income, TxType.expense]) {
        final g = suggestReportGroup(t, n);
        if (g != null) expect(g.allowedFor(t), isTrue, reason: '$n/$t');
      }
    }
  });
}
