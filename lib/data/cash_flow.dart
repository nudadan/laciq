import 'database.dart';
import 'recurrence.dart';

/// Hasil simulasi saldo harian bulan berjalan dari [startingBalance] +
/// kejadian Agenda/transaksi berulang (pengeluaran DAN pemasukan — beda dari
/// `MonthlyProjection` di `lib/data/providers.dart` yang sengaja cuma
/// pengeluaran, karena tujuannya beda: itu menjawab "berapa yang perlu
/// disiapkan", ini menjawab "apakah akan cukup") yang jatuh tempo sampai
/// akhir bulan.
class CashFlowProjection {
  const CashFlowProjection({
    required this.startingBalance,
    required this.endingBalance,
    required this.minBalance,
    required this.minBalanceDate,
  });

  final int startingBalance;
  final int endingBalance;
  final int minBalance; // titik terendah saldo sepanjang simulasi
  final DateTime minBalanceDate;

  /// Saldo diproyeksikan pernah minus sebelum akhir bulan.
  bool get hasShortfall => minBalance < 0;
}

/// Simulasi saldo harian dari [startingBalance] mengikuti tanggal jatuh
/// tempo Agenda (selalu pengeluaran, dari `estimatedAmount` — null dianggap
/// 0) dan [recurringRules] aktif bertipe pengeluaran/pemasukan (transfer
/// diabaikan — net nol terhadap saldo gabungan semua dompet, sama seperti
/// kartu Pemasukan/Pengeluaran Dashboard) dalam rentang [from, to).
CashFlowProjection simulateDailyBalance({
  required int startingBalance,
  required DateTime from,
  required DateTime to,
  required List<AgendaReminder> agenda,
  required List<RuleView> recurringRules,
}) {
  // amount bertanda: pengeluaran negatif, pemasukan positif.
  final byDate = <DateTime, int>{};
  void addEvent(DateTime date, int signedAmount) =>
      byDate[date] = (byDate[date] ?? 0) + signedAmount;

  for (final a in agenda.where((a) => a.active)) {
    for (final date in occurrenceDatesInRange(
      startDate: a.startDate,
      frequency: a.frequency,
      nextIndex: a.nextIndex,
      endDate: a.endDate,
      from: from,
      to: to,
    )) {
      addEvent(date, -(a.estimatedAmount ?? 0));
    }
  }
  for (final r in recurringRules.where(
    (r) => r.rule.active && r.rule.type != TxType.transfer,
  )) {
    final sign = r.rule.type == TxType.income ? 1 : -1;
    for (final date in occurrenceDatesInRange(
      startDate: r.rule.startDate,
      frequency: r.rule.frequency,
      nextIndex: r.rule.nextIndex,
      endDate: r.rule.endDate,
      from: from,
      to: to,
    )) {
      addEvent(date, sign * r.rule.amount);
    }
  }

  var running = startingBalance;
  var minBalance = startingBalance;
  var minDate = from;
  for (final date in byDate.keys.toList()..sort()) {
    running += byDate[date]!;
    if (running < minBalance) {
      minBalance = running;
      minDate = date;
    }
  }
  return CashFlowProjection(
    startingBalance: startingBalance,
    endingBalance: running,
    minBalance: minBalance,
    minBalanceDate: minDate,
  );
}
