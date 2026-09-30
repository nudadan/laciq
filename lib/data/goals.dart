/// Selisih hari kalender (tidak terpengaruh pergantian jam/DST).
int daysUntil(DateTime deadline, DateTime today) {
  final a = DateTime.utc(today.year, today.month, today.day);
  final b = DateTime.utc(deadline.year, deadline.month, deadline.day);
  return b.difference(a).inDays;
}

/// Perkiraan setoran per bulan agar target tercapai tepat pada [deadline]:
/// sisa dibagi jumlah bulan (hari / 30,4375, dibulatkan ke atas, minimal 1),
/// dibulatkan ke atas ke Rupiah utuh.
///
/// null bila sudah tercapai ([remaining] <= 0) atau tenggat sudah lewat.
/// Ini perkiraan kasar untuk memberi gambaran, bukan jadwal yang mengikat.
int? monthlyNeed({
  required int remaining,
  required DateTime deadline,
  required DateTime today,
}) {
  if (remaining <= 0) return null;
  final days = daysUntil(deadline, today);
  if (days < 0) return null;
  final months = (days / 30.4375).ceil().clamp(1, 1 << 20);
  return (remaining + months - 1) ~/ months;
}
