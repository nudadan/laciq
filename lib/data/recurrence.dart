import 'package:intl/intl.dart';

import 'database.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Tanggal kejadian ke-[k] (mulai dari 0 = [start] sendiri).
///
/// Selalu dihitung dari [start], bukan dari kejadian sebelumnya, sehingga
/// tidak ada drift: tagihan tiap tanggal 31 jatuh pada 28 Feb lalu kembali ke
/// 31 Mar (bukan 28 Mar). Bulan yang lebih pendek dijepit ke hari terakhirnya;
/// 29 Feb menjadi 28 Feb di tahun bukan kabisat.
DateTime occurrenceAt(DateTime start, Frequency frequency, int k) {
  final s = dateOnly(start);
  return switch (frequency) {
    Frequency.weekly => DateTime(s.year, s.month, s.day + 7 * k),
    Frequency.monthly => _addMonths(s, k),
    Frequency.yearly => _addMonths(s, 12 * k),
    Frequency.once => s, // cuma ada satu kejadian, k diabaikan
  };
}

DateTime _addMonths(DateTime s, int months) {
  final total = s.month - 1 + months;
  final year = s.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, s.day <= lastDay ? s.day : lastDay);
}

/// Indeks kejadian pertama yang jatuh pada atau setelah [from].
int firstIndexOnOrAfter(DateTime start, Frequency frequency, DateTime from) {
  // Tidak ada "kejadian berikutnya" untuk dilewati pada agenda sekali —
  // occurrenceAt konstan untuk `once`, jadi loop di bawah akan hang.
  if (frequency == Frequency.once) return 0;
  final target = dateOnly(from);
  var k = 0;
  while (occurrenceAt(start, frequency, k).isBefore(target)) {
    k++;
  }
  return k;
}

/// Daftar TANGGAL kejadian [frequency] (mulai [startDate], indeks berikutnya
/// [nextIndex], berakhir opsional [endDate]) yang jatuh dalam rentang
/// [from, to) — primitif dasar untuk proyeksi total (lihat
/// [occurrencesTotalInRange]) maupun simulasi arus kas harian
/// (`lib/data/cash_flow.dart`). Pure (tidak mengubah `nextIndex` sungguhan di
/// DB), aman dipanggil berulang tiap render. [Frequency.once] ditangani
/// terpisah (bukan lewat loop) karena `occurrenceAt` mengembalikan tanggal
/// KONSTAN untuknya — kalau disamakan dengan loop biasa, kejadiannya akan
/// dobel-hitung berkali-kali sampai batas iterasi.
List<DateTime> occurrenceDatesInRange({
  required DateTime startDate,
  required Frequency frequency,
  required int nextIndex,
  required DateTime? endDate,
  required DateTime from,
  required DateTime to,
}) {
  if (frequency == Frequency.once) {
    if (nextIndex > 0) return const []; // sudah dieksekusi/selesai
    final due = occurrenceAt(startDate, frequency, 0);
    return (!due.isBefore(from) && due.isBefore(to)) ? [due] : const [];
  }
  var index = nextIndex;
  final dates = <DateTime>[];
  // Guard iterasi, semangat sama `maxPerRule` di generateDueRecurring.
  for (var n = 0; n < 60; n++) {
    final due = occurrenceAt(startDate, frequency, index);
    if (!due.isBefore(to)) break;
    if (endDate != null && due.isAfter(endDate)) break;
    if (!due.isBefore(from)) dates.add(due);
    index++;
  }
  return dates;
}

/// Total nominal dari kejadian yang jatuh dalam rentang [from, to) — dipakai
/// untuk proyeksi bulanan Agenda + transaksi berulang. Lihat
/// [occurrenceDatesInRange] untuk penjelasan parameter & penanganan
/// [Frequency.once].
int occurrencesTotalInRange({
  required DateTime startDate,
  required Frequency frequency,
  required int nextIndex,
  required DateTime? endDate,
  required DateTime from,
  required DateTime to,
  required int amount,
}) =>
    occurrenceDatesInRange(
      startDate: startDate,
      frequency: frequency,
      nextIndex: nextIndex,
      endDate: endDate,
      from: from,
      to: to,
    ).length *
    amount;

String frequencyLabel(Frequency f) => switch (f) {
  Frequency.weekly => 'Mingguan',
  Frequency.monthly => 'Bulanan',
  Frequency.yearly => 'Tahunan',
  Frequency.once => 'Sekali',
};

/// Contoh: "Setiap bulan, tanggal 25".
String scheduleDescription(Frequency f, DateTime start) => switch (f) {
  Frequency.weekly =>
    'Setiap minggu, hari ${DateFormat('EEEE', 'id_ID').format(start)}',
  Frequency.monthly => 'Setiap bulan, tanggal ${start.day}',
  Frequency.yearly =>
    'Setiap tahun, ${DateFormat('d MMMM', 'id_ID').format(start)}',
  Frequency.once =>
    'Sekali, ${DateFormat('d MMMM yyyy', 'id_ID').format(start)}',
};
