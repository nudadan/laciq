import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/insights.dart';
import '../../data/providers.dart';

/// Laporan bulanan berbasis aturan (fitur Premium). Semua angka dan kalimat
/// dihitung di perangkat dari data yang sudah ada; tidak ada AI dan tidak ada
/// data yang dikirim ke mana pun.
class MonthlyReportPage extends ConsumerWidget {
  const MonthlyReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(monthlyReportProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Bulanan')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            const MonthSelector(),
            const SizedBox(height: 12),
            AsyncBody<MonthlyReport>(
              value: report,
              builder: (r) => r.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: EmptyState(
                        icon: Icons.insights_rounded,
                        message:
                            'Belum ada transaksi di bulan ini. Catat beberapa '
                            'transaksi untuk melihat laporan.',
                      ),
                    )
                  : _ReportBody(r),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody(this.r);
  final MonthlyReport r;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final rate = r.savingsRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pengeluaran', style: text.labelLarge),
              const SizedBox(height: 2),
              Text(
                rupiah(r.expense),
                key: const Key('report-expense'),
                style: text.headlineMedium?.copyWith(color: palette.expense),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Figure(
                      label: 'Pemasukan',
                      value: rupiah(r.income),
                      color: palette.income,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: r.net >= 0 ? 'Sisa' : 'Defisit',
                      value: rupiah(r.net.abs()),
                      color: r.net >= 0 ? palette.income : palette.expense,
                    ),
                  ),
                  if (rate != null && rate >= 0)
                    Expanded(
                      child: _Figure(
                        label: 'Tersisa',
                        value: '${(rate * 100).round()}%',
                        color: palette.income,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (r.insights.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text('Sorotan', style: text.titleMedium),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              children: [for (final i in r.insights) _InsightRow(i)],
            ),
          ),
        ],
        if (r.categories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text('Pengeluaran per kategori', style: text.titleMedium),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              children: [
                for (final c in r.categories.take(6)) _CategoryRow(c, r),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          child: Text(
            'Ringkasan ini dihitung otomatis di perangkat Anda dari catatan '
            'transaksi. Tidak ada data yang dikirim ke mana pun. Ini gambaran '
            'kebiasaan belanja, bukan nasihat keuangan.',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: text.titleSmall?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow(this.insight);
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, color) = switch (insight.tone) {
      InsightTone.good => (Icons.trending_down_rounded, palette.income),
      InsightTone.warning => (Icons.warning_amber_rounded, palette.warning),
      InsightTone.info => (
        Icons.info_outline_rounded,
        Theme.of(context).colorScheme.primary,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(insight.text)),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow(this.line, this.report);
  final CategoryLine line;
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = Color(line.color);
    final delta = line.previousTotal > 0
        ? line.total - line.previousTotal
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(categoryIcon(line.icon), size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(rupiah(line.total), style: text.titleSmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: line.share.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${(line.share * 100).round()}% dari pengeluaran',
              if (delta != null && delta != 0)
                '${delta > 0 ? 'naik' : 'turun'} ${rupiah(delta.abs())} '
                    'dibanding ${report.comparisonLabel}',
            ].join(' · '),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
