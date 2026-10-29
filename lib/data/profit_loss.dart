import 'database.dart';

/// Laporan Laba Rugi sederhana berbasis kas (docs/RENCANA-IMPLEMENTASI-UMKM.md
/// §4.3). Fungsi murni: tanpa Flutter dan tanpa database, jadi mudah diuji;
/// pola yang sama dengan `insights.dart` dan `cash_flow.dart`.
///
/// Konvensi (sama dengan kartu Pemasukan/Pengeluaran Dashboard):
/// - Rentang [from, to): `from` termasuk, `to` tidak (mis. awal bulan sampai awal
///   bulan berikutnya, lihat `AppDatabase.monthStart/monthEnd`).
/// - Transfer antar dompet diabaikan (net nol terhadap kas gabungan).
/// - Nominal selalu positif; arah ditentukan oleh bagian laporan.
/// - Sub-kategori digabung ke kategori induknya dan memakai kelompok induk.

/// Satu baris (satu kategori tingkat atas) pada sebuah bagian laporan.
class ProfitLossLine {
  const ProfitLossLine({
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.isDefaultGroup,
  });

  /// Null = transaksi tanpa kategori.
  final String? categoryId;
  final String name;
  final int amount;

  /// Kelompoknya berasal dari bawaan jenis (kolom `reportGroup` kosong),
  /// bukan pilihan pengguna atau kategori sistem. Dipakai tampilan untuk
  /// menandai "belum dikelompokkan" supaya pengguna sadar.
  final bool isDefaultGroup;
}

/// Satu bagian laporan: jumlah dan rinciannya (terbesar lebih dulu).
class ProfitLossSection {
  const ProfitLossSection(this.lines);

  static const empty = ProfitLossSection([]);

  final List<ProfitLossLine> lines;

  int get total => lines.fold(0, (sum, l) => sum + l.amount);
}

/// Hasil laporan untuk satu rentang. Semua angka turunan dihitung dari bagian,
/// kecuali [cashIn]/[cashOut] yang dihitung TERPISAH langsung dari transaksi
/// agar [reconciles] benar-benar menguji kebenaran pengelompokan.
class ProfitLoss {
  const ProfitLoss({
    required this.from,
    required this.to,
    required this.revenue,
    required this.cogs,
    required this.opex,
    required this.otherIncome,
    required this.otherExpense,
    required this.nonPnlIncome,
    required this.nonPnlExpense,
    required this.cashIn,
    required this.cashOut,
    required this.transactionCount,
  });

  final DateTime from;
  final DateTime to;

  final ProfitLossSection revenue;
  final ProfitLossSection cogs;
  final ProfitLossSection opex;
  final ProfitLossSection otherIncome;
  final ProfitLossSection otherExpense;

  /// Di luar laba rugi: tidak memengaruhi laba, tetapi mengubah kas.
  final ProfitLossSection nonPnlIncome;
  final ProfitLossSection nonPnlExpense;

  /// Total pemasukan/pengeluaran kas pada rentang (tanpa transfer), dihitung
  /// langsung dari transaksi.
  final int cashIn;
  final int cashOut;

  /// Jumlah transaksi (bukan transfer) yang masuk hitungan.
  final int transactionCount;

  int get grossProfit => revenue.total - cogs.total;
  int get operatingProfit => grossProfit - opex.total;
  int get netProfit => operatingProfit + otherIncome.total - otherExpense.total;

  /// Pemasukan dikurangi pengeluaran yang berada di luar laba rugi.
  int get nonPnlNet => nonPnlIncome.total - nonPnlExpense.total;

  /// Perubahan kas pada rentang menurut transaksi, tanpa pengelompokan.
  int get cashChange => cashIn - cashOut;

  /// Laba bersih ditambah selisih di luar laba rugi harus sama dengan perubahan
  /// kas. Selalu benar bila logika pengelompokan benar; tes menegakkannya.
  bool get reconciles => netProfit + nonPnlNet == cashChange;

  /// Persen terhadap pendapatan usaha; null bila pendapatan nol (tidak
  /// bermakna), bisa negatif bila rugi.
  double? get grossMarginPercent => _percent(grossProfit, revenue.total);
  double? get netMarginPercent => _percent(netProfit, revenue.total);

  /// Ada transaksi pada rentang ini.
  bool get isEmpty => transactionCount == 0;

  /// Baris yang kelompoknya hanya berasal dari bawaan jenis.
  Iterable<ProfitLossLine> get defaultGroupLines => [
    for (final s in [revenue, cogs, opex, otherIncome, otherExpense])
      ...s.lines.where((l) => l.isDefaultGroup),
  ];
}

double? _percent(int part, int whole) => whole <= 0 ? null : part * 100 / whole;

/// Perubahan persen dari [previous] ke [current]. Null bila [previous] nol
/// (tidak ada pembanding yang bermakna). Memakai nilai mutlak pembanding supaya
/// laba yang naik dari rugi tetap bertanda positif.
double? changePercent(int current, int previous) =>
    previous == 0 ? null : (current - previous) * 100 / previous.abs();

/// Arah perubahan untuk tampilan. Perubahan yang membulat ke 0,0% dianggap [flat]
/// supaya tidak tertulis "naik 0,0%".
enum Trend { up, down, flat }

Trend trendOf(double changePercent) => changePercent.abs() < 0.05
    ? Trend.flat
    : (changePercent > 0 ? Trend.up : Trend.down);

/// Kelompok laporan efektif [category]: pilihan pada kategori tingkat atasnya
/// (induk bila sub-kategori), atau bawaan jenisnya bila kosong. Nilai yang tidak
/// cocok dengan jenis ([ReportGroup.allowedFor]; seharusnya mustahil, dijaga
/// API dan validasi backup) jatuh ke bawaan jenis.
ReportGroup effectiveReportGroup(Category category, {Category? parent}) {
  final root = parent ?? category;
  final chosen = root.reportGroup;
  if (chosen != null && chosen.allowedFor(category.type)) return chosen;
  return ReportGroup.defaultFor(category.type);
}

/// Rentang pembanding sepanjang rentang [from, to): untuk rentang kelipatan
/// bulan utuh (awal bulan sampai awal bulan) kembali tepat sejumlah bulan itu
/// (Oktober -> September, bukan "30 hari lalu"); selain itu mundur sejumlah hari
/// yang sama. Pembanding berakhir tepat di [from].
({DateTime from, DateTime to}) previousPeriod(DateTime from, DateTime to) {
  final monthAligned =
      from.day == 1 &&
      to.day == 1 &&
      from == DateTime(from.year, from.month) &&
      to == DateTime(to.year, to.month);
  if (monthAligned) {
    final months = (to.year - from.year) * 12 + to.month - from.month;
    return (from: DateTime(from.year, from.month - months), to: from);
  }
  // Selisih hari kalender (bukan jam), supaya aman terhadap pergantian jam.
  final days = DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
  return (
    from: DateTime(
      from.year,
      from.month,
      from.day - days,
      from.hour,
      from.minute,
      from.second,
      from.millisecond,
    ),
    to: from,
  );
}

/// Menyusun laporan dari [items] (transaksi satu buku; boleh lebih luas dari
/// rentang, transaksi di luar [from, to) dilewati) dan [categories] (semua kategori
/// buku itu, untuk mencari induk sub-kategori).
ProfitLoss buildProfitLoss({
  required List<TxView> items,
  required List<Category> categories,
  required DateTime from,
  required DateTime to,
}) {
  final byId = {for (final c in categories) c.id: c};

  // (kelompok, pemasukan?) -> (kunci kategori tingkat atas -> akumulasi). Arah ikut
  // kuncinya karena kelompok "di luar laba rugi" memuat pemasukan dan pengeluaran.
  final buckets = <(ReportGroup, bool), Map<String?, _Acc>>{};
  var cashIn = 0;
  var cashOut = 0;
  var count = 0;

  for (final v in items) {
    final tx = v.tx;
    if (tx.type == TxType.transfer) continue;
    if (tx.date.isBefore(from) || !tx.date.isBefore(to)) continue;

    count++;
    final isIncome = tx.type == TxType.income;
    if (isIncome) {
      cashIn += tx.amount;
    } else {
      cashOut += tx.amount;
    }

    final leaf = v.category ?? byId[tx.categoryId];
    final Category? root;
    if (leaf == null) {
      root = null;
    } else {
      final parentId = leaf.parentId;
      root = parentId == null ? leaf : (byId[parentId] ?? leaf);
    }

    // Kelompok dihitung menurut JENIS TRANSAKSI, bukan jenis kategori, supaya
    // data menyimpang (kategori berjenis lain) tetap masuk bagian yang benar.
    final ReportGroup group;
    final bool isDefault;
    if (root == null) {
      group = ReportGroup.defaultFor(tx.type);
      isDefault = true;
    } else {
      final chosen = root.reportGroup;
      if (chosen != null && chosen.allowedFor(tx.type)) {
        group = chosen;
        isDefault = false;
      } else {
        group = ReportGroup.defaultFor(tx.type);
        isDefault = true;
      }
    }

    final acc = (buckets[(group, isIncome)] ??= {}).putIfAbsent(
      root?.id,
      () => _Acc(root?.name ?? 'Tanpa kategori', isDefault),
    );
    acc.amount += tx.amount;
  }

  ProfitLossSection section(ReportGroup g, {required bool income}) {
    final lines =
        [
          for (final e
              in (buckets[(g, income)] ?? const <String?, _Acc>{}).entries)
            ProfitLossLine(
              categoryId: e.key,
              name: e.value.name,
              amount: e.value.amount,
              isDefaultGroup: e.value.isDefault,
            ),
        ]..sort(
          (a, b) => b.amount != a.amount
              ? b.amount - a.amount
              : a.name.compareTo(b.name),
        );
    return ProfitLossSection(List.unmodifiable(lines));
  }

  return ProfitLoss(
    from: from,
    to: to,
    revenue: section(ReportGroup.revenue, income: true),
    cogs: section(ReportGroup.cogs, income: false),
    opex: section(ReportGroup.opex, income: false),
    otherIncome: section(ReportGroup.otherIncome, income: true),
    otherExpense: section(ReportGroup.otherExpense, income: false),
    nonPnlIncome: section(ReportGroup.nonPnl, income: true),
    nonPnlExpense: section(ReportGroup.nonPnl, income: false),
    cashIn: cashIn,
    cashOut: cashOut,
    transactionCount: count,
  );
}

class _Acc {
  _Acc(this.name, this.isDefault);
  final String name;
  final bool isDefault;
  int amount = 0;
}
