import 'package:intl/intl.dart';

import 'profit_loss.dart';

/// Susunan baris laporan Laba Rugi yang SAMA untuk Excel dan PDF, supaya keduanya
/// selalu cocok dengan layar (docs/RENCANA-IMPLEMENTASI-UMKM.md §4.4).
///
/// Nominal bertanda: pendapatan positif, pengurang (HPP, beban) negatif, sehingga
/// kolom nominal bisa dibaca sebagai penjumlahan. Bagian kosong disembunyikan
/// dengan aturan yang sama seperti layar: HPP/laba kotor hanya bila ada HPP, dan
/// laba operasional serta pendapatan/beban lain hanya bila ada.
enum StatementRowKind {
  /// Judul bagian dengan totalnya (mis. "Pendapatan usaha").
  section,

  /// Rincian satu kategori di bawah sebuah bagian.
  detail,

  /// Subtotal (laba kotor, laba operasional).
  subtotal,

  /// Hasil akhir (laba/rugi bersih, perubahan kas).
  total,
}

class StatementRow {
  const StatementRow(
    this.kind,
    this.label,
    this.amount, {
    this.percent,
    this.isDefaultGroup = false,
  });

  final StatementRowKind kind;
  final String label;

  /// Rupiah bertanda (pengurang negatif).
  final int amount;

  /// Persen terhadap pendapatan usaha (0-100, bisa negatif); null = tidak ada.
  final double? percent;

  /// Kelompok kategori ini berasal dari bawaan jenis, bukan pilihan pengguna.
  final bool isDefaultGroup;
}

double? _of(int part, int revenue) =>
    revenue <= 0 ? null : part * 100 / revenue;

/// Baris Laba Rugi: pendapatan sampai laba/rugi bersih.
List<StatementRow> profitLossStatement(ProfitLoss r) {
  List<StatementRow> details(ProfitLossSection s, int sign) => [
    for (final l in s.lines)
      StatementRow(
        StatementRowKind.detail,
        l.name,
        sign * l.amount,
        isDefaultGroup: l.isDefaultGroup,
      ),
  ];
  final revenue = r.revenue.total;
  return [
    StatementRow(StatementRowKind.section, 'Pendapatan usaha', revenue),
    ...details(r.revenue, 1),
    if (r.cogs.total > 0) ...[
      StatementRow(
        StatementRowKind.section,
        'Harga pokok penjualan (HPP)',
        -r.cogs.total,
      ),
      ...details(r.cogs, -1),
      StatementRow(
        StatementRowKind.subtotal,
        'Laba kotor',
        r.grossProfit,
        percent: r.grossMarginPercent,
      ),
    ],
    StatementRow(StatementRowKind.section, 'Beban operasional', -r.opex.total),
    ...details(r.opex, -1),
    if (r.otherIncome.total > 0 || r.otherExpense.total > 0) ...[
      StatementRow(
        StatementRowKind.subtotal,
        'Laba operasional',
        r.operatingProfit,
        percent: _of(r.operatingProfit, revenue),
      ),
      if (r.otherIncome.total > 0) ...[
        StatementRow(
          StatementRowKind.section,
          'Pendapatan lain',
          r.otherIncome.total,
        ),
        ...details(r.otherIncome, 1),
      ],
      if (r.otherExpense.total > 0) ...[
        StatementRow(
          StatementRowKind.section,
          'Beban lain',
          -r.otherExpense.total,
        ),
        ...details(r.otherExpense, -1),
      ],
    ],
    StatementRow(
      StatementRowKind.total,
      r.netProfit >= 0 ? 'Laba bersih' : 'Rugi bersih',
      r.netProfit,
      percent: r.netMarginPercent,
    ),
  ];
}

/// Baris "Dari laba ke kas": laba bersih, arus di luar laba rugi, perubahan kas.
List<StatementRow> cashBridgeStatement(ProfitLoss r) => [
  StatementRow(
    StatementRowKind.subtotal,
    r.netProfit >= 0 ? 'Laba bersih' : 'Rugi bersih',
    r.netProfit,
  ),
  for (final l in r.nonPnlIncome.lines)
    StatementRow(StatementRowKind.detail, l.name, l.amount),
  for (final l in r.nonPnlExpense.lines)
    StatementRow(StatementRowKind.detail, l.name, -l.amount),
  StatementRow(StatementRowKind.total, 'Perubahan kas', r.cashChange),
];

/// Akhiran nama berkas untuk rentang [from, to): "2026-10" untuk satu bulan
/// kalender utuh, selain itu "20261001_20261015" (hari terakhir yang termasuk).
String profitLossFileSuffix(DateTime from, DateTime to) {
  final oneMonth =
      from == DateTime(from.year, from.month) &&
      to == DateTime(from.year, from.month + 1);
  if (oneMonth) return DateFormat('yyyy-MM').format(from);
  final last = DateTime(to.year, to.month, to.day - 1);
  final f = DateFormat('yyyyMMdd');
  return '${f.format(from)}_${f.format(last)}';
}
