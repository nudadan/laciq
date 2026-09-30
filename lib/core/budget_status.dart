/// Status anggaran satu kategori dibandingkan batasnya.
enum BudgetStatus {
  /// Belum ada anggaran, atau pemakaian di bawah 80%.
  ok,

  /// Pemakaian 80% sampai 100% dari anggaran.
  warning,

  /// Pemakaian melebihi anggaran.
  over,
}

/// Ambang tunggal dipakai UI (warna progress bar) dan notifikasi, agar
/// keduanya tidak pernah berbeda pendapat.
BudgetStatus budgetStatusOf(int spent, int? budget) {
  if (budget == null || budget <= 0) return BudgetStatus.ok;
  final ratio = spent / budget;
  if (ratio > 1) return BudgetStatus.over;
  if (ratio >= 0.8) return BudgetStatus.warning;
  return BudgetStatus.ok;
}
