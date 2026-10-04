import 'package:intl/intl.dart';

import '../core/money.dart';
import 'database.dart';

/// Laporan bulanan berbasis aturan. Seluruhnya dihitung di perangkat dari data
/// yang sudah ada: tidak ada AI, tidak ada jaringan, tidak ada data yang keluar.
///
/// Transfer antar dompet tidak dihitung (bukan pemasukan/pengeluaran), sama
/// seperti kartu Dashboard.

enum InsightTone { good, warning, info }

class Insight {
  const Insight(this.tone, this.text);
  final InsightTone tone;
  final String text;
}

class CategoryLine {
  const CategoryLine({
    required this.name,
    required this.icon,
    required this.color,
    required this.total,
    required this.share,
    required this.previousTotal,
  });
  final String name;
  final String icon;
  final int color;
  final int total;

  /// 0..1 dari total pengeluaran bulan ini.
  final double share;

  /// Pengeluaran kategori yang sama pada periode pembanding (lihat
  /// [MonthlyReport.comparisonLabel]).
  final int previousTotal;
}

class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.income,
    required this.expense,
    required this.previousExpense,
    required this.transactionCount,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.comparisonLabel,
    required this.categories,
    required this.insights,
    this.projectedExpense,
  });

  final DateTime month;
  final int income;
  final int expense;

  /// Pengeluaran periode pembanding: bulan lalu penuh, atau bulan lalu sampai
  /// tanggal yang sama bila bulan ini belum selesai.
  final int previousExpense;
  final int transactionCount;
  final int daysElapsed;
  final int daysInMonth;
  final String comparisonLabel;
  final List<CategoryLine> categories;
  final List<Insight> insights;

  /// Perkiraan pengeluaran akhir bulan; null bila bulan sudah lewat atau data
  /// terlalu sedikit untuk ditaksir.
  final int? projectedExpense;

  int get net => income - expense;
  bool get isEmpty => transactionCount == 0;

  /// Porsi pemasukan yang tersisa (negatif bila defisit); null tanpa pemasukan.
  double? get savingsRate => income > 0 ? net / income : null;

  /// Rata-rata pengeluaran per hari yang sudah berjalan.
  int get dailyAverage =>
      daysElapsed == 0 ? 0 : (expense / daysElapsed).round();
}

/// Ambang agar perubahan kecil tidak dilaporkan sebagai "tren".
const _minChangeRatio = 0.10;
const _minCategoryDelta = 50000;
const _minCategoryRatio = 0.25;
const _minDaysForProjection = 7;
const _nearBudgetRatio = 0.8;
const _maxInsights = 8;

MonthlyReport buildMonthlyReport({
  required DateTime month,
  required List<TxView> current,
  required List<TxView> previous,
  required List<BudgetProgress> budgets,
  required DateTime today,
}) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final monthKey = month.year * 12 + month.month;
  final todayKey = today.year * 12 + today.month;
  final inProgress = monthKey == todayKey;
  final daysElapsed = monthKey > todayKey
      ? 0
      : inProgress
      ? today.day
      : daysInMonth;
  final partial = inProgress && daysElapsed < daysInMonth;

  // Bandingkan dengan periode yang sebanding: bulan berjalan dengan bulan lalu
  // sampai tanggal yang sama (bukan seluruh bulan lalu, yang pasti lebih besar).
  final comparable = partial
      ? previous.where((v) => v.tx.date.day <= daysElapsed).toList()
      : previous;
  final comparisonLabel = partial
      ? 'periode yang sama bulan lalu'
      : 'bulan lalu';

  int sum(Iterable<TxView> l, TxType t) =>
      l.where((v) => v.tx.type == t).fold<int>(0, (s, v) => s + v.tx.amount);

  final income = sum(current, TxType.income);
  final expense = sum(current, TxType.expense);
  final previousExpense = sum(comparable, TxType.expense);
  final count = current.where((v) => v.tx.type != TxType.transfer).length;

  final categories = _categoryLines(current, comparable, expense);
  final projected = partial && daysElapsed >= _minDaysForProjection
      ? (expense / daysElapsed * daysInMonth).round()
      : null;

  final insights = <Insight>[];
  if (count > 0) {
    _addInsights(
      insights,
      income: income,
      expense: expense,
      previousExpense: previousExpense,
      comparisonLabel: comparisonLabel,
      categories: categories,
      budgets: budgets,
      current: current,
      projected: projected,
      daysElapsed: daysElapsed,
    );
  }

  return MonthlyReport(
    month: month,
    income: income,
    expense: expense,
    previousExpense: previousExpense,
    transactionCount: count,
    daysElapsed: daysElapsed,
    daysInMonth: daysInMonth,
    comparisonLabel: comparisonLabel,
    categories: categories,
    insights: insights.take(_maxInsights).toList(),
    projectedExpense: projected,
  );
}

List<CategoryLine> _categoryLines(
  List<TxView> current,
  List<TxView> comparable,
  int totalExpense,
) {
  final prev = <String, int>{};
  for (final v in comparable.where((v) => v.tx.type == TxType.expense)) {
    final k = v.category?.id ?? '';
    prev[k] = (prev[k] ?? 0) + v.tx.amount;
  }
  final totals = <String, int>{};
  final meta = <String, ({String name, String icon, int color})>{};
  for (final v in current.where((v) => v.tx.type == TxType.expense)) {
    final k = v.category?.id ?? '';
    totals[k] = (totals[k] ?? 0) + v.tx.amount;
    meta.putIfAbsent(
      k,
      () => (
        name: v.category?.name ?? 'Tanpa kategori',
        icon: v.category?.icon ?? 'other',
        color: v.category?.color ?? 0xFF9E9E9E,
      ),
    );
  }
  final keys = totals.keys.toList()
    ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
  return [
    for (final k in keys)
      CategoryLine(
        name: meta[k]!.name,
        icon: meta[k]!.icon,
        color: meta[k]!.color,
        total: totals[k]!,
        share: totalExpense == 0 ? 0 : totals[k]! / totalExpense,
        previousTotal: prev[k] ?? 0,
      ),
  ];
}

int _pct(double ratio) => (ratio * 100).round();

void _addInsights(
  List<Insight> out, {
  required int income,
  required int expense,
  required int previousExpense,
  required String comparisonLabel,
  required List<CategoryLine> categories,
  required List<BudgetProgress> budgets,
  required List<TxView> current,
  required int? projected,
  required int daysElapsed,
}) {
  // 1. Selisih pemasukan dan pengeluaran.
  if (income > 0 || expense > 0) {
    final net = income - expense;
    if (income > 0 && net >= 0) {
      out.add(
        Insight(
          InsightTone.good,
          net == 0
              ? 'Pemasukan dan pengeluaran bulan ini seimbang.'
              : 'Sisa ${rupiah(net)} dari pemasukan (${_pct(net / income)}%).',
        ),
      );
    } else if (net < 0) {
      out.add(
        Insight(
          InsightTone.warning,
          income == 0
              ? 'Belum ada pemasukan tercatat; pengeluaran ${rupiah(expense)}.'
              : 'Pengeluaran melebihi pemasukan sebesar ${rupiah(-net)}.',
        ),
      );
    }
  }

  // 2. Dibanding periode pembanding.
  if (previousExpense > 0 && expense > 0) {
    final delta = expense - previousExpense;
    final ratio = delta / previousExpense;
    if (ratio.abs() < _minChangeRatio) {
      out.add(
        Insight(
          InsightTone.info,
          'Pengeluaran relatif stabil dibanding $comparisonLabel '
          '(${rupiah(expense)} vs ${rupiah(previousExpense)}).',
        ),
      );
    } else if (delta > 0) {
      out.add(
        Insight(
          InsightTone.warning,
          'Pengeluaran naik ${_pct(ratio)}% dibanding $comparisonLabel '
          '(${rupiah(expense)} vs ${rupiah(previousExpense)}).',
        ),
      );
    } else {
      out.add(
        Insight(
          InsightTone.good,
          'Pengeluaran turun ${_pct(-ratio)}% dibanding $comparisonLabel '
          '(${rupiah(expense)} vs ${rupiah(previousExpense)}).',
        ),
      );
    }
  }

  // 3. Taksiran akhir bulan.
  if (projected != null) {
    final over = income > 0 && projected > income;
    out.add(
      Insight(
        over ? InsightTone.warning : InsightTone.info,
        over
            ? 'Dengan laju saat ini, pengeluaran akhir bulan sekitar '
                  '${rupiah(projected)}, melebihi pemasukan bulan ini.'
            : 'Dengan laju saat ini, pengeluaran akhir bulan sekitar '
                  '${rupiah(projected)}.',
      ),
    );
  }

  // 4. Anggaran.
  final overs = <(String, int, double)>[];
  final nears = <(String, double)>[];
  for (final b in budgets) {
    final limit = b.budget;
    if (limit == null || limit <= 0) continue;
    final ratio = b.spent / limit;
    if (ratio > 1) {
      overs.add((b.category.name, b.spent - limit, ratio));
    } else if (ratio >= _nearBudgetRatio) {
      nears.add((b.category.name, ratio));
    }
  }
  overs.sort((a, b) => b.$2.compareTo(a.$2));
  for (final o in overs.take(2)) {
    out.add(
      Insight(
        InsightTone.warning,
        'Anggaran ${o.$1} terlampaui ${rupiah(o.$2)} (${_pct(o.$3)}% dari batas).',
      ),
    );
  }
  nears.sort((a, b) => b.$2.compareTo(a.$2));
  for (final n in nears.take(2)) {
    out.add(
      Insight(
        InsightTone.warning,
        'Anggaran ${n.$1} sudah ${_pct(n.$2)}% terpakai.',
      ),
    );
  }

  // 5. Kategori terbesar.
  if (categories.isNotEmpty && expense > 0) {
    final top = categories.first;
    out.add(
      Insight(
        InsightTone.info,
        'Pengeluaran terbesar: ${top.name}, ${rupiah(top.total)} '
        '(${_pct(top.share)}% dari total).',
      ),
    );
  }

  // 6. Kategori yang paling naik / paling turun dibanding periode pembanding.
  CategoryLine? rise;
  CategoryLine? fall;
  for (final c in categories) {
    if (c.previousTotal <= 0) continue;
    final delta = c.total - c.previousTotal;
    if (delta >= _minCategoryDelta &&
        delta / c.previousTotal >= _minCategoryRatio &&
        (rise == null || delta > rise.total - rise.previousTotal)) {
      rise = c;
    }
    if (-delta >= _minCategoryDelta &&
        -delta / c.previousTotal >= _minCategoryRatio &&
        (fall == null || -delta > fall.previousTotal - fall.total)) {
      fall = c;
    }
  }
  if (rise != null) {
    out.add(
      Insight(
        InsightTone.warning,
        '${rise.name} naik ${rupiah(rise.total - rise.previousTotal)} '
        '(${_pct((rise.total - rise.previousTotal) / rise.previousTotal)}%) '
        'dibanding $comparisonLabel.',
      ),
    );
  }
  if (fall != null) {
    out.add(
      Insight(
        InsightTone.good,
        '${fall.name} turun ${rupiah(fall.previousTotal - fall.total)} '
        'dibanding $comparisonLabel.',
      ),
    );
  }

  // 7. Satu pengeluaran paling besar.
  final expenses = current.where((v) => v.tx.type == TxType.expense).toList();
  if (expenses.length >= 3) {
    final big = expenses.reduce((a, b) => b.tx.amount > a.tx.amount ? b : a);
    final note = big.tx.note?.trim();
    final what = note != null && note.isNotEmpty
        ? note
        : (big.category?.name ?? 'tanpa kategori');
    final on = DateFormat('d MMM', 'id_ID').format(big.tx.date);
    out.add(
      Insight(
        InsightTone.info,
        'Satu pengeluaran terbesar: ${rupiah(big.tx.amount)} untuk $what '
        '($on).',
      ),
    );
  }

  // 8. Hari tanpa pengeluaran.
  if (daysElapsed >= _minDaysForProjection) {
    final spendDays = {for (final v in expenses) v.tx.date.day}
        .where((d) => d <= daysElapsed)
        .length;
    final noSpend = daysElapsed - spendDays;
    if (noSpend >= 3) {
      out.add(
        Insight(
          InsightTone.good,
          '$noSpend hari tanpa pengeluaran dari $daysElapsed hari berjalan.',
        ),
      );
    }
  }

  // 9. Rata-rata harian (selalu di akhir, sebagai konteks).
  if (daysElapsed > 0 && expense > 0) {
    out.add(
      Insight(
        InsightTone.info,
        'Rata-rata pengeluaran ${rupiah((expense / daysElapsed).round())} '
        'per hari.',
      ),
    );
  }
}
