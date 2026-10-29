import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/money.dart';
import 'profit_loss.dart';
import 'profit_loss_statement.dart';

/// PDF laporan Laba Rugi, A4 tegak (docs/RENCANA-IMPLEMENTASI-UMKM.md §4.4).
/// Dibuat sepenuhnya di perangkat dan dibagikan lewat lembar bagikan; tidak ada
/// data yang dikirim ke server.
///
/// Font diberikan pemanggil (bukan dimuat di sini) agar fungsi ini murni dan mudah
/// diuji. [regular] boleh font variabel bawaan (terbaca pada bobot 400), [bold]
/// harus instans statis: paket `pdf` tidak bisa memilih bobot sumbu variabel
/// (lihat assets/fonts/pdf/ dan test/pdf_fonts_test.dart).
Future<Uint8List> buildProfitLossPdf({
  required ProfitLoss report,
  required String bookName,
  required String periodLabel,
  required pw.Font regular,
  required pw.Font bold,

  /// Periode pembanding (rentang sebelumnya yang sama panjang); null = tanpa pembanding.
  ProfitLoss? previous,
  DateTime? generatedAt,
}) async {
  final now = generatedAt ?? DateTime.now();
  final generated = DateFormat('d MMMM yyyy HH:mm', 'id_ID').format(now);

  pw.TextStyle style(double size, {bool strong = false, PdfColor? color}) =>
      pw.TextStyle(
        font: strong ? bold : regular,
        fontSize: size,
        color: color ?? PdfColors.grey900,
      );

  const muted = PdfColors.grey600;
  const profitColor = PdfColor.fromInt(0xFF2E7D32);
  const lossColor = PdfColor.fromInt(0xFFC62828);

  String money(int v) => rupiah(v);
  String pct(double v) => '${NumberFormat('0.0', 'id_ID').format(v)}%';

  pw.Widget statementRow(StatementRow row) {
    final isDetail = row.kind == StatementRowKind.detail;
    final strong = !isDetail;
    final big = row.kind == StatementRowKind.total;
    final border = switch (row.kind) {
      StatementRowKind.subtotal => const pw.Border(
        top: pw.BorderSide(width: 0.5, color: PdfColors.grey500),
      ),
      StatementRowKind.total => const pw.Border(
        top: pw.BorderSide(width: 0.8, color: PdfColors.grey700),
        bottom: pw.BorderSide(width: 0.8, color: PdfColors.grey700),
      ),
      _ => null,
    };
    final color = row.kind == StatementRowKind.total
        ? (row.amount >= 0 ? profitColor : lossColor)
        : null;
    return pw.Container(
      padding: pw.EdgeInsets.only(
        left: isDetail ? 14 : 0,
        top: strong ? 5 : 2.5,
        bottom: strong ? 5 : 2.5,
      ),
      margin: pw.EdgeInsets.only(
        top: row.kind == StatementRowKind.section ? 4 : 0,
      ),
      decoration: border == null ? null : pw.BoxDecoration(border: border),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              row.label,
              style: style(big ? 12 : 10, strong: strong, color: color),
            ),
          ),
          if (row.percent != null)
            pw.SizedBox(
              width: 52,
              child: pw.Text(
                pct(row.percent!),
                textAlign: pw.TextAlign.right,
                style: style(9, color: muted),
              ),
            ),
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              money(row.amount),
              textAlign: pw.TextAlign.right,
              style: style(big ? 12 : 10, strong: strong, color: color),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
    child: pw.Text(text, style: style(12, strong: true)),
  );

  final net = report.netProfit;
  final change = previous == null || previous.isEmpty
      ? null
      : changePercent(net, previous.netProfit);

  final doc = pw.Document(
    title: 'Laporan Laba Rugi - $bookName',
    author: 'LaciQ',
    creator: 'LaciQ',
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 48),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              'Dibuat oleh LaciQ, $generated. Catatan manajemen berbasis kas, '
              'bukan laporan resmi atau laporan pajak.',
              style: style(7.5, color: muted),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: style(7.5, color: muted),
          ),
        ],
      ),
      build: (context) => [
        pw.Text(
          'LAPORAN LABA RUGI',
          style: style(9, strong: true, color: muted),
        ),
        pw.SizedBox(height: 2),
        pw.Text(bookName, style: style(22, strong: true)),
        pw.SizedBox(height: 2),
        pw.Text('Periode: $periodLabel', style: style(10.5, color: muted)),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                net >= 0 ? 'Laba bersih' : 'Rugi bersih',
                style: style(10, color: muted),
              ),
              pw.Text(
                money(net.abs()),
                style: style(
                  24,
                  strong: true,
                  color: net >= 0 ? profitColor : lossColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                report.netMarginPercent == null
                    ? 'Belum ada pendapatan usaha pada periode ini'
                    : '${pct(report.netMarginPercent!)} dari pendapatan usaha',
                style: style(10),
              ),
              if (change != null)
                pw.Text(switch (trendOf(change)) {
                  Trend.flat =>
                    'Sama dengan periode sebelumnya (${money(previous!.netProfit)})',
                  Trend.up =>
                    'Naik ${pct(change.abs())} dibanding periode sebelumnya '
                        '(${money(previous!.netProfit)})',
                  Trend.down =>
                    'Turun ${pct(change.abs())} dibanding periode sebelumnya '
                        '(${money(previous!.netProfit)})',
                }, style: style(10)),
            ],
          ),
        ),
        heading('Rincian'),
        ...profitLossStatement(report).map(statementRow),
        heading('Dari laba ke kas'),
        ...cashBridgeStatement(report).map(statementRow),
        pw.SizedBox(height: 4),
        pw.Text(
          'Perubahan kas sama dengan total pemasukan dikurangi total pengeluaran '
          'pada periode ini (tanpa transfer antar dompet). Penjualan secara kredit '
          'baru terhitung saat uangnya diterima.',
          style: style(8.5, color: muted),
        ),
      ],
    ),
  );
  return doc.save();
}
