import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../subscription/trial_offer.dart';
import 'trend_settings.dart';

/// Analisa tren pengeluaran per kategori — beda dari grafik tren gratis di
/// Dashboard yang hanya membandingkan total pemasukan vs pengeluaran per
/// bulan (`lib/features/dashboard/dashboard_page.dart`). Gratis untuk jendela
/// 3 bulan; 6/12 bulan perlu premium (lihat `categoryTrendProvider`).
class TrendPage extends ConsumerWidget {
  const TrendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(categoryTrendProvider);
    final premium = ref.watch(isPremiumProvider).value ?? false;
    final requestedMonths = ref.watch(trendWindowMonthsProvider).value ?? 6;
    final months = premium ? requestedMonths : 3;
    final endMonth = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analisa Tren')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Center(
              child: SegmentedButton<int>(
                segments: [
                  for (final m in trendWindowOptions)
                    ButtonSegment(value: m, label: Text('$m bln')),
                ],
                selected: {months},
                onSelectionChanged: (s) {
                  final selected = s.first;
                  if (!premium && selected != 3) {
                    openUpgradeOrTrial(context, ref);
                    return;
                  }
                  ref.read(trendWindowMonthsProvider.notifier).set(selected);
                },
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: AsyncBody<List<CategoryMonthlyTotal>>(
                value: trend,
                builder: (rows) {
                  final data = _TrendData.from(
                    rows,
                    endMonth: endMonth,
                    months: months,
                  );
                  if (data.monthsWithData < 2) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: EmptyState(
                        icon: Icons.insights_rounded,
                        message:
                            'Butuh minimal 2 bulan data pengeluaran '
                            'untuk melihat tren.',
                      ),
                    );
                  }
                  return _TrendBody(data);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySeries {
  const _CategorySeries({
    required this.name,
    required this.color,
    required this.values,
  });
  final String name;
  final int color;

  /// Sejajar dengan [_TrendData.months] — 0 untuk bulan tanpa pengeluaran
  /// kategori ini.
  final List<int> values;
}

class _TrendData {
  const _TrendData({
    required this.months,
    required this.series,
    required this.monthsWithData,
    required this.insight,
  });

  final List<DateTime> months;

  /// Top 5 kategori berdasar total pengeluaran di jendela waktu ini.
  final List<_CategorySeries> series;
  final int monthsWithData;
  final String? insight;

  static String _key(DateTime m) => '${m.year}-${m.month}';

  factory _TrendData.from(
    List<CategoryMonthlyTotal> rows, {
    required DateTime endMonth,
    required int months,
  }) {
    final start = DateTime(endMonth.year, endMonth.month - months + 1);
    final monthList = [
      for (var i = 0; i < months; i++) DateTime(start.year, start.month + i),
    ];
    final monthIndex = {for (final (i, m) in monthList.indexed) _key(m): i};

    final byCategory = <String, ({String name, int color, List<int> values})>{};
    final monthsWithAnyData = <String>{};
    for (final r in rows) {
      final idx = monthIndex[_key(r.month)];
      if (idx == null) continue;
      monthsWithAnyData.add(_key(r.month));
      final entry = byCategory.putIfAbsent(
        r.categoryId,
        () => (
          name: r.categoryName,
          color: r.color,
          values: List.filled(months, 0),
        ),
      );
      entry.values[idx] += r.total;
    }

    final ranked = byCategory.values.toList()
      ..sort(
        (a, b) => b.values
            .reduce((x, y) => x + y)
            .compareTo(a.values.reduce((x, y) => x + y)),
      );
    final top = [
      for (final c in ranked.take(5))
        _CategorySeries(name: c.name, color: c.color, values: c.values),
    ];

    return _TrendData(
      months: monthList,
      series: top,
      monthsWithData: monthsWithAnyData.length,
      insight: _biggestIncrease(top),
    );
  }

  /// Kategori dengan kenaikan % terbesar bulan terakhir vs rata-rata bulan
  /// sebelumnya di jendela ini. Bukan ML — murni perbandingan aritmetika
  /// dari data yang sudah diambil, tanpa query tambahan.
  static String? _biggestIncrease(List<_CategorySeries> series) {
    String? bestName;
    var bestPct = 0.0;
    for (final s in series) {
      if (s.values.length < 2) continue;
      final last = s.values.last;
      final prev = s.values.sublist(0, s.values.length - 1);
      final avgPrev = prev.reduce((a, b) => a + b) / prev.length;
      if (avgPrev <= 0) continue;
      final pct = (last - avgPrev) / avgPrev * 100;
      if (pct > bestPct) {
        bestPct = pct;
        bestName = s.name;
      }
    }
    if (bestName == null) return null;
    return '$bestName naik ${bestPct.toStringAsFixed(0)}% '
        'dibanding rata-rata bulan sebelumnya.';
  }
}

class _TrendBody extends StatelessWidget {
  const _TrendBody(this.data);

  final _TrendData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final peak = data.series.fold<int>(
      0,
      (m, s) => [m, ...s.values].reduce((a, b) => a > b ? a : b),
    );
    final maxY = peak == 0 ? 1.0 : peak * 1.15;
    final labelStyle = text.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tren Pengeluaran per Kategori', style: text.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              maxY: maxY,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        compactRupiah(value.toInt()),
                        style: labelStyle,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= data.months.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('MMM', 'id_ID').format(data.months[i]),
                          style: labelStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                for (final s in data.series)
                  LineChartBarData(
                    spots: [
                      for (final (i, v) in s.values.indexed)
                        FlSpot(i.toDouble(), v.toDouble()),
                    ],
                    color: Color(s.color),
                    barWidth: 3,
                    isCurved: true,
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final s in data.series)
              _LegendDot(color: Color(s.color), label: s.name),
          ],
        ),
        if (data.insight != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(data.insight!, style: text.bodySmall)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}
