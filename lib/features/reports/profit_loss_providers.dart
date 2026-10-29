import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/profit_loss.dart';
import '../../data/providers.dart';

/// Pilihan rentang layar Laba Rugi (docs/RENCANA-IMPLEMENTASI-UMKM.md §4.4).
/// [month], [quarter], dan [year] mengikuti bulan terpilih di [selectedMonthProvider];
/// [custom] memakai rentang yang dipilih pengguna.
enum ProfitLossRangeKind { month, quarter, year, custom }

typedef DateRange = ({DateTime from, DateTime to});

class ProfitLossRangeKindNotifier extends Notifier<ProfitLossRangeKind> {
  @override
  ProfitLossRangeKind build() => ProfitLossRangeKind.month;

  void select(ProfitLossRangeKind kind) => state = kind;
}

final profitLossRangeKindProvider =
    NotifierProvider<ProfitLossRangeKindNotifier, ProfitLossRangeKind>(
      ProfitLossRangeKindNotifier.new,
    );

/// Rentang bebas [from, to) pilihan pengguna; null sampai dipilih.
class ProfitLossCustomRange extends Notifier<DateRange?> {
  @override
  DateRange? build() => null;

  void set(DateRange? range) => state = range;
}

final profitLossCustomRangeProvider =
    NotifierProvider<ProfitLossCustomRange, DateRange?>(
      ProfitLossCustomRange.new,
    );

/// Rentang [from, to) untuk [kind] dengan bulan terpilih [month]. Rentang bebas
/// yang belum dipilih jatuh ke bulan terpilih.
DateRange profitLossRange(
  ProfitLossRangeKind kind,
  DateTime month, {
  DateRange? custom,
}) {
  final m = DateTime(month.year, month.month);
  return switch (kind) {
    ProfitLossRangeKind.month => (from: m, to: DateTime(m.year, m.month + 1)),
    ProfitLossRangeKind.quarter => (
      from: DateTime(m.year, m.month - 2),
      to: DateTime(m.year, m.month + 1),
    ),
    ProfitLossRangeKind.year => (
      from: DateTime(m.year),
      to: DateTime(m.year + 1),
    ),
    ProfitLossRangeKind.custom =>
      custom ?? (from: m, to: DateTime(m.year, m.month + 1)),
  };
}

final profitLossRangeProvider = Provider.autoDispose<DateRange>(
  (ref) => profitLossRange(
    ref.watch(profitLossRangeKindProvider),
    ref.watch(selectedMonthProvider),
    custom: ref.watch(profitLossCustomRangeProvider),
  ),
);

final _rangeTransactionsProvider = StreamProvider.autoDispose
    .family<List<TxView>, DateRange>(
      (ref, range) => ref
          .watch(databaseProvider)
          .watchTransactionsRange(
            range.from,
            range.to,
            ledgerId: ref.watch(activeLedgerIdProvider),
          ),
    );

final _ledgerCategoriesProvider = StreamProvider.autoDispose<List<Category>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchLedgerCategories(ref.watch(activeLedgerIdProvider)),
);

/// Laporan untuk rentang terpilih beserta pembandingnya (rentang sebelumnya yang
/// sama panjang, lihat [previousPeriod]). Dihitung di perangkat; tanpa jaringan.
class ProfitLossReport {
  const ProfitLossReport({required this.current, required this.previous});

  final ProfitLoss current;
  final ProfitLoss previous;
}

final profitLossProvider = Provider.autoDispose<AsyncValue<ProfitLossReport>>((
  ref,
) {
  final range = ref.watch(profitLossRangeProvider);
  final before = previousPeriod(range.from, range.to);
  final current = ref.watch(_rangeTransactionsProvider(range));
  final previous = ref.watch(_rangeTransactionsProvider(before));
  final categories = ref.watch(_ledgerCategoriesProvider);
  final error = current.error ?? previous.error ?? categories.error;
  if (error != null) return AsyncError(error, StackTrace.current);
  final c = current.value;
  final p = previous.value;
  final cats = categories.value;
  if (c == null || p == null || cats == null) return const AsyncLoading();
  return AsyncData(
    ProfitLossReport(
      current: buildProfitLoss(
        items: c,
        categories: cats,
        from: range.from,
        to: range.to,
      ),
      previous: buildProfitLoss(
        items: p,
        categories: cats,
        from: before.from,
        to: before.to,
      ),
    ),
  );
});
