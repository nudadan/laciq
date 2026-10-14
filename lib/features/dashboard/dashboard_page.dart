import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/recurrence.dart';
import '../agenda/agenda_page.dart';
import '../subscription/trial_offer.dart';
import '../subscription/trial_status.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountBalancesProvider);
    final totals = ref.watch(monthTotalsProvider);
    final spending = ref.watch(expenseByCategoryProvider);
    final trend = ref.watch(monthlyTrendProvider);
    final palette = context.palette;

    final list = accounts.value ?? const <AccountBalance>[];
    final totalBalance = list.fold<int>(0, (s, a) => s + a.balance);
    final t = totals.value ?? (income: 0, expense: 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, kBottomPad),
      children: [
        const MonthSelector(),
        const SizedBox(height: 16),
        _HeroCard(
          total: totalBalance,
          net: t.income - t.expense,
          walletCount: list.length,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _FlowCard(
                label: 'Pemasukan',
                amount: t.income,
                icon: Icons.south_west_rounded,
                color: palette.income,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FlowCard(
                label: 'Pengeluaran',
                amount: t.expense,
                icon: Icons.north_east_rounded,
                color: palette.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const TrialStatusCard(),
        const TrialOfferCard(),
        const _AgendaCard(),
        const _ProjectionCard(),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pengeluaran per Kategori',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              AsyncBody<List<CategorySpend>>(
                value: spending,
                builder: (items) => items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: EmptyState(
                          icon: Icons.donut_large_rounded,
                          message: 'Belum ada pengeluaran bulan ini.',
                        ),
                      )
                    : _SpendingChart(items),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tren 6 Bulan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              AsyncBody<List<MonthlyTotal>>(
                value: trend,
                builder: (items) =>
                    items.every((m) => m.income == 0 && m.expense == 0)
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: EmptyState(
                          icon: Icons.show_chart_rounded,
                          message: 'Belum ada transaksi 6 bulan terakhir.',
                        ),
                      )
                    : _TrendChart(items),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartu saldo utama: gradien elektrik, orb transparan untuk kedalaman, dan
/// cahaya di bawahnya.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.total,
    required this.net,
    required this.walletCount,
  });

  final int total;
  final int net; // pemasukan - pengeluaran bulan ini
  final int walletCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    const radius = 32.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: p.heroGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: p.glow.withValues(alpha: 0.42),
            blurRadius: 44,
            spreadRadius: -8,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            const Positioned(right: -46, top: -50, child: _Orb(170, 0.13)),
            const Positioned(left: -40, bottom: -70, child: _Orb(190, 0.09)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Total Saldo',
                        style: text.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const Spacer(),
                      _Pill(
                        icon: Icons.account_balance_wallet_rounded,
                        label: '$walletCount dompet',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AnimatedAmount(
                    total,
                    style: text.displaySmall!.copyWith(
                      color: Colors.white,
                      fontSize: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Pill(
                    icon: net >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    label:
                        'Bulan ini ${net >= 0 ? '+' : '-'}${rupiah(net.abs())}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb(this.size, this.alpha);

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          Colors.white.withValues(alpha: alpha),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Colors.white),
        ),
      ],
    ),
  );
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final int amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedAmount(
            amount,
            style: text.titleLarge!.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _SpendingChart extends StatelessWidget {
  const _SpendingChart(this.items);

  final List<CategorySpend> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = items.fold<int>(0, (s, i) => s + i.total);

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 4,
                  centerSpaceRadius: 74,
                  sections: [
                    for (final i in items)
                      PieChartSectionData(
                        value: i.total.toDouble(),
                        color: Color(i.color),
                        radius: 22,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(rupiah(total), style: text.titleMedium),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                CategoryBadge(
                  icon: categoryIcon(i.icon),
                  color: Color(i.color),
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              i.name,
                              style: text.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(rupiah(i.total), style: text.labelLarge),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: i.total / total,
                                minHeight: 5,
                                color: Color(i.color),
                                backgroundColor: scheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(i.total * 100 / total).toStringAsFixed(0)}%',
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pembulatan ke atas ke angka "rapi" untuk batas atas sumbu grafik:
/// 1/2/2,5/5/10 dikali pangkat 10 (mis. 220 -> 250, 15400 -> 20000).
double _niceCeil(double v) {
  if (v <= 0) return 1;
  final magnitude = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final step in [1.0, 2.0, 2.5, 5.0, 10.0]) {
    final candidate = magnitude * step;
    if (candidate >= v) return candidate;
  }
  return magnitude * 10;
}

/// Grafik batang pemasukan/pengeluaran 6 bulan terakhir (berakhir di bulan
/// yang sedang dipilih), agar arus kas bisa dibaca lebih dari satu bulan.
class _TrendChart extends StatelessWidget {
  const _TrendChart(this.items);

  final List<MonthlyTotal> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final labelStyle = text.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final peak = items.fold<int>(
      0,
      (m, i) => [m, i.income, i.expense].reduce((a, b) => a > b ? a : b),
    );
    // Dibulatkan ke atas ke angka "rapi" (1/2/2,5/5/10 × 10^n) supaya label
    // sumbu-Y teratas tidak jadi angka aneh yang pecah dua baris (mis. 16,8 rb).
    final maxY = peak == 0 ? 1.0 : _niceCeil(peak * 1.1);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
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
                    reservedSize: 64,
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
                      if (i < 0 || i >= items.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('MMM', 'id_ID').format(items[i].month),
                          style: labelStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (final (i, m) in items.indexed)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: m.income.toDouble(),
                        color: palette.income,
                        width: 8,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: m.expense.toDouble(),
                        color: palette.expense,
                        width: 8,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: palette.income, label: 'Pemasukan'),
            const SizedBox(width: 20),
            _LegendDot(color: palette.expense, label: 'Pengeluaran'),
          ],
        ),
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

/// Kartu ringkasan Agenda — jalan penemuan fitur dari halaman depan, tanpa
/// perlu masuk Pengaturan. Tidak ada cabang premium/gratis: Agenda gratis
/// sampai 3 item (lihat `agenda_reminder_service.dart`), jadi siapa pun bisa
/// punya item sungguhan di sini.
class _AgendaCard extends ConsumerWidget {
  const _AgendaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingAgendaProvider);
    return GlassCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const AgendaPage())),
      child: AsyncBody<List<AgendaView>>(
        value: upcoming,
        builder: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 20,
                  color: context.palette.transfer,
                ),
                const SizedBox(width: 8),
                Text('Agenda', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                'Belum ada agenda. Tambah pengingat servis, tagihan, dll.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final v in items) _AgendaRow(v),
          ],
        ),
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow(this.v);

  final AgendaView v;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            v.item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          _relativeDue(v.nextDue),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

/// "Hari ini" / "Besok" / "N hari lagi" untuk ≤30 hari, tanggal biasa untuk
/// yang lebih jauh — lebih glanceable daripada tanggal penuh untuk kartu
/// ringkas begini (beda dari `agenda_page.dart` yang selalu tampilkan
/// tanggal lengkap karena itu daftar detail, bukan ringkasan).
String _relativeDue(DateTime nextDue) {
  final days = dateOnly(nextDue).difference(dateOnly(DateTime.now())).inDays;
  if (days <= 0) return 'Hari ini';
  if (days == 1) return 'Besok';
  if (days <= 30) return '$days hari lagi';
  return DateFormat('d MMM', 'id_ID').format(nextDue);
}

/// Kartu proyeksi kebutuhan pengeluaran bulan ini dari Agenda + transaksi
/// berulang — fitur premium PENUH (beda dari Agenda/Analisa Tren). Tetap
/// SELALU tampil (bukan disembunyikan) supaya jadi permukaan penemuan fitur;
/// yang belum premium lihat ajakan upgrade, bukan angka.
class _ProjectionCard extends ConsumerWidget {
  const _ProjectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPremiumProvider).value ?? false;
    if (!premium) {
      return GlassCard(
        onTap: () => openUpgradeOrTrial(context, ref),
        child: Row(
          children: [
            Icon(
              Icons.insights_rounded,
              size: 20,
              color: context.palette.transfer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Proyeksi Bulan Ini',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Fitur Premium — prediksi kebutuhan dari Agenda & '
                    'transaksi berulang',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
    }
    final projection = ref.watch(monthlyProjectionProvider);
    final cashFlow = ref.watch(cashFlowProjectionProvider).value;
    return GlassCard(
      child: AsyncBody<MonthlyProjection>(
        value: projection,
        builder: (p) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 20,
                  color: context.palette.transfer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Proyeksi Bulan Ini',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              rupiah(p.total),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            _ProjectionRow('Dari Agenda', p.agendaTotal),
            _ProjectionRow('Dari transaksi berulang', p.recurringTotal),
            if (cashFlow != null) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    cashFlow.hasShortfall
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                    color: cashFlow.hasShortfall
                        ? context.palette.expense
                        : context.palette.income,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cashFlow.hasShortfall
                          ? 'Berpotensi kurang ${rupiah(cashFlow.minBalance.abs())} '
                                'pada ${DateFormat('d MMM', 'id_ID').format(cashFlow.minBalanceDate)}'
                          : 'Dana diproyeksikan cukup sepanjang bulan ini',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectionRow extends StatelessWidget {
  const _ProjectionRow(this.label, this.amount);

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Text(rupiah(amount), style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
