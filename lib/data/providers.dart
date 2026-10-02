import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notification_sender.dart';
import '../features/ads/ad_eligibility_service.dart';
import '../features/review/review_prompt_service.dart';
import '../features/ai/ai_extraction_service.dart';
import '../features/agenda/agenda_reminder_service.dart';
import '../features/budget/budget_notification_service.dart';
import '../features/cloud_backup/cloud_backup_reminder_service.dart';
import '../features/cloud_backup/cloud_backup_service.dart';
import '../features/recurring/recurring_reminder_service.dart';
import '../features/security/lock_providers.dart' show keyValueStoreProvider;
import '../features/subscription/subscription_plans.dart';
import '../features/subscription/subscription_status.dart';
import '../features/transactions/receipt_scanner.dart';
import '../features/trends/trend_settings.dart';
import 'cash_flow.dart';
import 'database.dart';
import 'recurrence.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void shift(int months) => state = DateTime(state.year, state.month + months);
}

final selectedMonthProvider = NotifierProvider<SelectedMonth, DateTime>(
  SelectedMonth.new,
);

// ----------------------------------------------------------- buku kas
//
// Multi buku kas adalah fitur Ultimate (lihat
// docs/RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md). Semua provider data di bawah
// membaca [activeLedgerIdProvider], jadi widget tidak perlu tahu soal buku.

/// Semua buku kas (yang diarsipkan di urutan bawah). Buku Utama selalu ada.
final ledgersProvider = StreamProvider<List<Ledger>>(
  (ref) => ref.watch(databaseProvider).watchLedgers(),
);

/// Total saldo dompet aktif per buku (id buku -> saldo), untuk pengalih buku.
final ledgerBalancesProvider = StreamProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(databaseProvider).watchLedgerBalances(),
);

const _kActiveLedgerKey = 'active_ledger_id';

/// Pilihan buku aktif pengguna, disimpan di [KeyValueStore]. Null = belum
/// dibaca / belum memilih. Jangan dipakai langsung untuk menampilkan data:
/// pakai [activeLedgerIdProvider], yang sudah memeriksa hak Ultimate dan
/// keberadaan bukunya.
class ActiveLedgerPref extends Notifier<String?> {
  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final saved = await ref
          .read(keyValueStoreProvider)
          .read(_kActiveLedgerKey);
      if (ref.mounted && state == null && saved != null) state = saved;
    } catch (_) {
      // Penyimpanan tak terbaca: tetap di Buku Utama.
    }
  }

  Future<void> select(String ledgerId) async {
    state = ledgerId;
    await ref.read(keyValueStoreProvider).write(_kActiveLedgerKey, ledgerId);
  }
}

final activeLedgerPrefProvider = NotifierProvider<ActiveLedgerPref, String?>(
  ActiveLedgerPref.new,
);

/// Buku yang tidak boleh dipakai: diarsipkan, atau semua selain Buku Utama
/// bila bukan Ultimate (datanya tetap utuh, hanya terkunci).
Set<String> lockedLedgerIds(List<Ledger> ledgers, {required bool ultimate}) => {
  for (final l in ledgers)
    if (l.archived || (!ultimate && l.id != kMainLedgerId)) l.id,
};

/// Buku yang benar-benar dipakai saat ini. Bukan Ultimate, buku yang dipilih
/// tidak ada, atau buku itu diarsipkan -> Buku Utama.
final activeLedgerIdProvider = Provider<String>((ref) {
  final ultimate = ref.watch(isUltimateProvider).value ?? false;
  if (!ultimate) return kMainLedgerId;
  final pref = ref.watch(activeLedgerPrefProvider);
  final ledgers = ref.watch(ledgersProvider).value;
  if (pref == null || ledgers == null) return kMainLedgerId;
  final usable = ledgers.any((l) => l.id == pref && !l.archived);
  return usable ? pref : kMainLedgerId;
});

/// Buku yang sedang aktif beserta datanya (nama, warna, ikon).
final activeLedgerProvider = Provider<Ledger?>((ref) {
  final id = ref.watch(activeLedgerIdProvider);
  final ledgers = ref.watch(ledgersProvider).value;
  if (ledgers == null) return null;
  return ledgers.where((l) => l.id == id).firstOrNull;
});

/// Pengalih buku dan penanda "Mencatat di" hanya tampil untuk Ultimate.
final multiLedgerEnabledProvider = Provider<bool>(
  (ref) => ref.watch(isUltimateProvider).value ?? false,
);

/// Mencatat transaksi berulang yang jatuh tempo di SEMUA buku kas yang dapat
/// dipakai; buku terkunci dijeda (lihat [AppDatabase.generateDueRecurring]).
/// Semua pemanggil memakai ini, bukan `generateDueRecurring()` langsung.
final recurringGeneratorProvider = Provider<Future<int> Function()>((ref) {
  return () async {
    final db = ref.read(databaseProvider);
    // Langsung ke sumber status (bukan isUltimateProvider.future): tidak
    // bergantung pada ada-tidaknya pendengar provider stream saat dipanggil.
    final ultimate = await ref
        .read(subscriptionStatusProvider)
        .watchIsUltimate()
        .first;
    final ledgers = await db.watchLedgers().first;
    return db.generateDueRecurring(
      pausedLedgerIds: lockedLedgerIds(ledgers, ultimate: ultimate),
    );
  };
});

final accountBalancesProvider =
    StreamProvider.autoDispose<List<AccountBalance>>(
      (ref) => ref
          .watch(databaseProvider)
          .watchAccountBalances(ledgerId: ref.watch(activeLedgerIdProvider)),
    );

/// Termasuk dompet yang diarsipkan (di urutan bawah): untuk layar Dompet dan
/// untuk mengubah transaksi yang memakai dompet yang sudah diarsipkan.
final allAccountsProvider = StreamProvider.autoDispose<List<AccountBalance>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchAccountBalances(
        includeArchived: true,
        ledgerId: ref.watch(activeLedgerIdProvider),
      ),
);

/// Termasuk yang diarsipkan (di urutan bawah): untuk layar kelola kategori dan
/// untuk mengubah transaksi yang memakai kategori yang sudah diarsipkan.
final allCategoriesProvider = StreamProvider.autoDispose
    .family<List<Category>, TxType>(
      (ref, type) => ref
          .watch(databaseProvider)
          .watchCategories(
            type,
            includeArchived: true,
            ledgerId: ref.watch(activeLedgerIdProvider),
          ),
    );

final monthTotalsProvider = StreamProvider.autoDispose<MonthTotals>(
  (ref) => ref
      .watch(databaseProvider)
      .watchTotals(
        ref.watch(selectedMonthProvider),
        ledgerId: ref.watch(activeLedgerIdProvider),
      ),
);

final monthlyTrendProvider = StreamProvider.autoDispose<List<MonthlyTotal>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchMonthlyTrend(
        ref.watch(selectedMonthProvider),
        ledgerId: ref.watch(activeLedgerIdProvider),
      ),
);

final expenseByCategoryProvider =
    StreamProvider.autoDispose<List<CategorySpend>>(
      (ref) => ref
          .watch(databaseProvider)
          .watchExpenseByCategory(
            ref.watch(selectedMonthProvider),
            ledgerId: ref.watch(activeLedgerIdProvider),
          ),
    );

final monthTransactionsProvider = StreamProvider.autoDispose<List<TxView>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchTransactions(
        ref.watch(selectedMonthProvider),
        ledgerId: ref.watch(activeLedgerIdProvider),
      ),
);

final budgetProgressProvider = StreamProvider.autoDispose<List<BudgetProgress>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchBudgetProgress(
        ref.watch(selectedMonthProvider),
        ledgerId: ref.watch(activeLedgerIdProvider),
      ),
);

/// Provider terpisah (bukan langsung di dalam [budgetNotificationServiceProvider])
/// agar tes bisa menggantinya dengan pengirim palsu tanpa menyentuh platform
/// channel notifikasi sungguhan.
final notificationSenderProvider = Provider<NotificationSender>(
  (ref) => LocalNotificationSender(),
);

final budgetNotificationServiceProvider = Provider<BudgetNotificationService>(
  (ref) => BudgetNotificationService(
    ref.watch(keyValueStoreProvider),
    ref.watch(notificationSenderProvider),
  ),
);

final recurringRulesProvider = StreamProvider.autoDispose<List<RuleView>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchRecurringRules(ledgerId: ref.watch(activeLedgerIdProvider)),
);

final goalsProvider = StreamProvider.autoDispose<List<GoalView>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchGoals(ledgerId: ref.watch(activeLedgerIdProvider)),
);

final goalContributionsProvider = StreamProvider.autoDispose
    .family<List<GoalContribution>, String>(
      (ref, goalId) => ref.watch(databaseProvider).watchContributions(goalId),
    );

final tagsProvider = StreamProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(databaseProvider).watchTags(),
);

final transactionTagsProvider = StreamProvider.autoDispose
    .family<List<Tag>, String>(
      (ref, transactionId) =>
          ref.watch(databaseProvider).watchTagsForTransaction(transactionId),
    );

final adEligibilityServiceProvider = Provider<AdEligibilityService>(
  (ref) => AdEligibilityService(ref.watch(keyValueStoreProvider)),
);

final reviewLauncherProvider = Provider<ReviewLauncher>(
  (ref) => InAppReviewLauncher(),
);

final reviewPromptServiceProvider = Provider<ReviewPromptService>(
  (ref) => ReviewPromptService(
    ref.watch(keyValueStoreProvider),
    ref.watch(reviewLauncherProvider),
  ),
);

final subscriptionStatusProvider = Provider<SubscriptionStatus>(
  (ref) => RevenueCatSubscriptionStatus(),
);

final isPremiumProvider = StreamProvider<bool>(
  (ref) => ref.watch(subscriptionStatusProvider).watchIsPremium(),
);

final isUltimateProvider = StreamProvider<bool>(
  (ref) => ref.watch(subscriptionStatusProvider).watchIsUltimate(),
);

/// Tingkat langganan pengguna saat ini, diturunkan dari stream entitlement
/// yang sudah ada (tanpa panggilan jaringan baru).
final subscriptionTierProvider = Provider<ActiveTier>(
  (ref) => ActiveTier.of(
    premium: ref.watch(isPremiumProvider).value ?? false,
    ultimate: ref.watch(isUltimateProvider).value ?? false,
  ),
);

/// Apakah paket Ultimate benar-benar ada di offering toko. Ajakan upgrade ke
/// Ultimate hanya ditampilkan bila true: jangan menawarkan produk yang belum
/// bisa dibeli. Gagal memuat (mis. offline) dianggap false.
final ultimateAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    final packages = await ref.read(subscriptionStatusProvider).fetchPackages();
    return packages.any((p) => p.tier == SubscriptionTier.ultimate);
  } catch (_) {
    return false;
  }
});

/// Ekstraksi AI struk (fitur Ultimate) — lihat backend/receipt-extraction-worker/.
final aiExtractionServiceProvider = Provider<AiExtractionService>(
  (ref) => HttpAiExtractionService(ref.watch(subscriptionStatusProvider)),
);

/// Scan struk (OCR + foto tersimpan, fitur Premium) — lihat
/// docs/RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md.
final receiptScannerProvider = Provider<ReceiptScanner>(
  (ref) => MlKitReceiptScanner(),
);

/// Apakah pengguna ini sudah lewat masa bebas iklan 30 hari DAN belum
/// berlangganan premium. Bukan autoDispose — dipakai HomeShell yang hidup
/// selama sesi app; masa-tenggang bagian dihitung ulang manual lewat
/// ref.invalidate() di _recordFirstUse (lib/app.dart), bagian premium
/// otomatis lewat isPremiumProvider (stream).
final shouldShowAdsProvider = FutureProvider<bool>((ref) async {
  final premium = await ref.watch(isPremiumProvider.future);
  if (premium) return false;
  return ref.watch(adEligibilityServiceProvider).shouldShowAds();
});

final cloudBackupServiceProvider = Provider<CloudBackupService>(
  (ref) => GoogleDriveCloudBackupService(ref.watch(keyValueStoreProvider)),
);

final cloudSignedInProvider = StreamProvider<bool>(
  (ref) => ref.watch(cloudBackupServiceProvider).watchSignedIn(),
);

final cloudBackupReminderServiceProvider = Provider<CloudBackupReminderService>(
  (ref) => CloudBackupReminderService(
    ref.watch(keyValueStoreProvider),
    ref.watch(cloudBackupServiceProvider),
    ref.watch(notificationSenderProvider),
  ),
);

/// Penjadwal pengingat (fitur premium) — dipakai bersama oleh transaksi
/// berulang dan agenda, keduanya lewat `notificationSenderProvider` yang sama.
final recurringReminderServiceProvider = Provider<RecurringReminderService>(
  (ref) => RecurringReminderService(ref.watch(notificationSenderProvider)),
);

final agendaReminderServiceProvider = Provider<AgendaReminderService>(
  (ref) => AgendaReminderService(ref.watch(notificationSenderProvider)),
);

final agendaRemindersProvider =
    StreamProvider.autoDispose<List<AgendaReminder>>(
      (ref) => ref
          .watch(databaseProvider)
          .watchAgendaReminders(ledgerId: ref.watch(activeLedgerIdProvider)),
    );

/// Utang/piutang (fitur Premium) — lihat docs/RENCANA-IMPLEMENTASI-UTANG-PIUTANG.md.
final debtsProvider = StreamProvider.autoDispose<List<Debt>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchDebts(ledgerId: ref.watch(activeLedgerIdProvider)),
);

/// 2 item Agenda terdekat jatuh temponya (aktif, belum selesai), untuk kartu
/// ringkasan di Dashboard — turunan dari [agendaRemindersProvider] yang
/// sudah ada, BUKAN query DB baru.
final upcomingAgendaProvider =
    Provider.autoDispose<AsyncValue<List<AgendaView>>>((ref) {
      final items = ref.watch(agendaRemindersProvider);
      return items.whenData((list) {
        final upcoming =
            list
                .map(AgendaView.new)
                .where((v) => v.item.active && !v.finished)
                .toList()
              ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
        return upcoming.take(2).toList();
      });
    });

class MonthlyProjection {
  const MonthlyProjection({
    required this.agendaTotal,
    required this.recurringTotal,
  });
  final int agendaTotal;
  final int recurringTotal;
  int get total => agendaTotal + recurringTotal;
}

/// Proyeksi kebutuhan pengeluaran BULAN INI (kalender berjalan, bukan bulan
/// yang sedang dilihat di [selectedMonthProvider] — proyeksi selalu tentang
/// "sekarang") dari Agenda (estimasi biaya) + transaksi berulang bertipe
/// pengeluaran — turunan dari [agendaRemindersProvider]/[recurringRulesProvider]
/// yang sudah ada, BUKAN query DB baru. Fitur premium PENUH (beda dari
/// Agenda/Analisa Tren yang "cicip") — provider ini sendiri tidak perlu tahu
/// status premium, itu urusan widget (sama pola [upcomingAgendaProvider] yang
/// juga tidak tahu soal kuota gratis).
final monthlyProjectionProvider =
    Provider.autoDispose<AsyncValue<MonthlyProjection>>((ref) {
      final agenda = ref.watch(agendaRemindersProvider);
      final rules = ref.watch(recurringRulesProvider);
      if (agenda is AsyncLoading || rules is AsyncLoading) {
        return const AsyncValue.loading();
      }
      if (agenda.hasError) {
        return AsyncValue.error(agenda.error!, agenda.stackTrace!);
      }
      if (rules.hasError) {
        return AsyncValue.error(rules.error!, rules.stackTrace!);
      }

      final now = DateTime.now();
      final from = dateOnly(now);
      final to = DateTime(
        now.year,
        now.month + 1,
      ); // awal bulan depan, eksklusif

      final agendaTotal = agenda.value!
          .where((a) => a.active)
          .fold<int>(
            0,
            (sum, a) =>
                sum +
                occurrencesTotalInRange(
                  startDate: a.startDate,
                  frequency: a.frequency,
                  nextIndex: a.nextIndex,
                  endDate: a.endDate,
                  from: from,
                  to: to,
                  amount: a.estimatedAmount ?? 0,
                ),
          );
      final recurringTotal = rules.value!
          .where((r) => r.rule.active && r.rule.type == TxType.expense)
          .fold<int>(
            0,
            (sum, r) =>
                sum +
                occurrencesTotalInRange(
                  startDate: r.rule.startDate,
                  frequency: r.rule.frequency,
                  nextIndex: r.rule.nextIndex,
                  endDate: r.rule.endDate,
                  from: from,
                  to: to,
                  amount: r.rule.amount,
                ),
          );
      return AsyncValue.data(
        MonthlyProjection(
          agendaTotal: agendaTotal,
          recurringTotal: recurringTotal,
        ),
      );
    });

/// Simulasi kecukupan dana bulan ini — turunan dari [accountBalancesProvider]
/// (saldo awal, SAMA angka dengan "Total Saldo" di `_HeroCard` Dashboard) +
/// [agendaRemindersProvider]/[recurringRulesProvider] yang sudah ada. Fitur
/// premium PENUH, sama seperti [monthlyProjectionProvider] — tapi provider
/// ini TIDAK menggantikannya: yang ini menjawab "apakah akan cukup" (ikut
/// pemasukan), yang itu menjawab "berapa yang perlu disiapkan" (cuma
/// pengeluaran).
final cashFlowProjectionProvider =
    Provider.autoDispose<AsyncValue<CashFlowProjection>>((ref) {
      final balances = ref.watch(accountBalancesProvider);
      final agenda = ref.watch(agendaRemindersProvider);
      final rules = ref.watch(recurringRulesProvider);
      if (balances is AsyncLoading ||
          agenda is AsyncLoading ||
          rules is AsyncLoading) {
        return const AsyncValue.loading();
      }
      if (balances.hasError) {
        return AsyncValue.error(balances.error!, balances.stackTrace!);
      }
      if (agenda.hasError) {
        return AsyncValue.error(agenda.error!, agenda.stackTrace!);
      }
      if (rules.hasError) {
        return AsyncValue.error(rules.error!, rules.stackTrace!);
      }

      final startingBalance = balances.value!.fold<int>(
        0,
        (s, a) => s + a.balance,
      );
      final now = DateTime.now();
      final from = dateOnly(now);
      final to = DateTime(now.year, now.month + 1);
      return AsyncValue.data(
        simulateDailyBalance(
          startingBalance: startingBalance,
          from: from,
          to: to,
          agenda: agenda.value!,
          recurringRules: rules.value!,
        ),
      );
    });

/// Analisa Tren: pengeluaran per kategori, [months] terakhir diambil dari
/// setelan pengguna (`trendWindowMonthsProvider`) — TAPI dipaksa 3 bulan
/// kalau bukan premium (jendela 6/12 bulan itu sendiri yang jadi fitur
/// premium; grafiknya sendiri gratis). Klem di sini, bukan cuma di UI, supaya
/// bekas pelanggan premium yang preferensinya masih 6/12 tidak diam-diam
/// tetap dapat data 6/12 bulan setelah berhenti berlangganan.
final categoryTrendProvider =
    StreamProvider.autoDispose<List<CategoryMonthlyTotal>>((ref) {
      final requested = ref.watch(trendWindowMonthsProvider).value ?? 6;
      final premium = ref.watch(isPremiumProvider).value ?? false;
      final months = premium ? requested : 3;
      return ref
          .watch(databaseProvider)
          .watchCategoryMonthlyTrend(
            ref.watch(selectedMonthProvider),
            months: months,
            ledgerId: ref.watch(activeLedgerIdProvider),
          );
    });
