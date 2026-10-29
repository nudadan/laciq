import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../data/database.dart' show LedgerKind;
import '../../data/providers.dart';
import '../agenda/agenda_page.dart';
import '../budget/budget_page.dart';
import '../more/more_page.dart' show GoalsPageScaffold;
import '../reports/profit_loss_page.dart';
import '../security/lock_providers.dart' show keyValueStoreProvider;
import '../settings/settings_page.dart';
import '../subscription/trial_offer.dart';
import '../transactions/open_transaction_form.dart';

/// Kartu "Mulai cepat" di Beranda: daftar langkah pertama yang tercentang
/// sendiri dari data (docs/RENCANA-IMPLEMENTASI-ONBOARDING.md butir B).

const quickStartHiddenKey = 'quickstart_hidden';
const quickStartDoneKey = 'quickstart_done';

/// Penanda backup berhasil dibuat (file atau cloud). Backup file tidak
/// meninggalkan jejak di data, jadi langkah "Cadangkan datamu" bergantung padanya.
const backupDoneKey = 'backup_done';

enum QuickStartStep {
  firstTransaction('Catat transaksi pertama'),
  budget('Atur anggaran bulanan'),
  goal('Buat target tabungan'),
  reminder('Pasang pengingat tagihan'),
  backup('Cadangkan datamu');

  const QuickStartStep(this.label);
  final String label;
}

class QuickStartItem {
  const QuickStartItem(this.step, this.done);
  final QuickStartStep step;
  final bool done;
}

class QuickStart {
  const QuickStart(this.items);
  final List<QuickStartItem> items;

  int get doneCount => items.where((i) => i.done).length;
  bool get allDone => doneCount == items.length;
}

/// Murni: tiap langkah tercentang dari data, bukan dari "pernah diketuk",
/// sehingga pengguna lama langsung melihat langkah yang sudah mereka kerjakan.
QuickStart buildQuickStart({
  required int transactionCount,
  required bool hasBudget,
  required bool hasGoal,
  required bool hasReminder,
  required bool backedUp,
}) => QuickStart([
  QuickStartItem(QuickStartStep.firstTransaction, transactionCount > 0),
  QuickStartItem(QuickStartStep.budget, hasBudget),
  QuickStartItem(QuickStartStep.goal, hasGoal),
  QuickStartItem(QuickStartStep.reminder, hasReminder),
  QuickStartItem(QuickStartStep.backup, backedUp),
]);

class QuickStartPrefs {
  const QuickStartPrefs({
    this.hidden = false,
    this.done = false,
    this.backedUp = false,
  });
  final bool hidden;
  final bool done;
  final bool backedUp;

  QuickStartPrefs copyWith({bool? hidden, bool? done, bool? backedUp}) =>
      QuickStartPrefs(
        hidden: hidden ?? this.hidden,
        done: done ?? this.done,
        backedUp: backedUp ?? this.backedUp,
      );
}

/// Preferensi kartu di [KeyValueStore]. Gagal baca/tulis tidak boleh
/// mengganggu aplikasi: kartu hanya tampil dengan nilai bawaan.
class QuickStartPrefsController extends AsyncNotifier<QuickStartPrefs> {
  @override
  Future<QuickStartPrefs> build() async {
    final store = ref.read(keyValueStoreProvider);
    try {
      return QuickStartPrefs(
        hidden: await store.read(quickStartHiddenKey) == '1',
        done: await store.read(quickStartDoneKey) == '1',
        backedUp: await store.read(backupDoneKey) == '1',
      );
    } catch (_) {
      return const QuickStartPrefs();
    }
  }

  QuickStartPrefs get _current => state.value ?? const QuickStartPrefs();

  Future<void> _set(String key, QuickStartPrefs next) async {
    state = AsyncData(next);
    try {
      await ref.read(keyValueStoreProvider).write(key, '1');
    } catch (_) {
      // Tanpa penyimpanan: perubahan berlaku sampai aplikasi ditutup.
    }
  }

  Future<void> hide() =>
      _set(quickStartHiddenKey, _current.copyWith(hidden: true));

  /// Semua langkah selesai: kartu tidak muncul lagi walau data berubah nanti.
  Future<void> markDone() =>
      _set(quickStartDoneKey, _current.copyWith(done: true));

  Future<void> markBackupDone() =>
      _set(backupDoneKey, _current.copyWith(backedUp: true));

  /// Dipakai "Lihat panduan lagi": kartu tampil kembali.
  Future<void> show() async {
    state = AsyncData(_current.copyWith(hidden: false, done: false));
    try {
      final store = ref.read(keyValueStoreProvider);
      await store.delete(quickStartHiddenKey);
      await store.delete(quickStartDoneKey);
    } catch (_) {}
  }
}

final quickStartPrefsProvider =
    AsyncNotifierProvider<QuickStartPrefsController, QuickStartPrefs>(
      QuickStartPrefsController.new,
    );

/// Status kartu; null selama data belum siap atau kartu disembunyikan, supaya
/// tidak berkedip di Beranda.
final quickStartProvider = Provider.autoDispose<QuickStart?>((ref) {
  final prefs = ref.watch(quickStartPrefsProvider).value;
  final count = ref.watch(transactionCountProvider).value;
  final budgets = ref.watch(budgetProgressProvider).value;
  final goals = ref.watch(goalsProvider).value;
  final agenda = ref.watch(agendaRemindersProvider).value;
  final rules = ref.watch(recurringRulesProvider).value;
  if (prefs == null ||
      count == null ||
      budgets == null ||
      goals == null ||
      agenda == null ||
      rules == null) {
    return null;
  }
  if (prefs.hidden || prefs.done) return null;
  return buildQuickStart(
    transactionCount: count,
    hasBudget: budgets.any((b) => b.budget != null),
    hasGoal: goals.isNotEmpty,
    hasReminder: agenda.isNotEmpty || rules.isNotEmpty,
    backedUp: prefs.backedUp,
  );
});

class QuickStartCard extends ConsumerWidget {
  const QuickStartCard({super.key});

  void _open(BuildContext context, WidgetRef ref, QuickStartStep step) {
    Future<void> push(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
    switch (step) {
      case QuickStartStep.firstTransaction:
        openTransactionForm(context);
      case QuickStartStep.budget:
        push(
          Scaffold(
            appBar: AppBar(title: const Text('Anggaran')),
            body: const BudgetPage(),
          ),
        );
      case QuickStartStep.goal:
        push(const GoalsPageScaffold());
      case QuickStartStep.reminder:
        push(const AgendaPage());
      case QuickStartStep.backup:
        push(const SettingsPage());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qs = ref.watch(quickStartProvider);
    if (qs == null) return const SizedBox.shrink();
    if (qs.allDone) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(quickStartPrefsProvider.notifier).markDone(),
      );
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ledger = ref.watch(activeLedgerProvider);
    final business = ledger?.kind == LedgerKind.business;
    final premium = ref.watch(isPremiumProvider).value ?? false;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Mulai cepat', style: theme.textTheme.titleMedium),
              ),
              Text(
                '${qs.doneCount} dari ${qs.items.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(quickStartPrefsProvider.notifier).hide(),
                child: const Text('Sembunyikan'),
              ),
            ],
          ),
          for (final item in qs.items)
            InkWell(
              key: Key('quickstart-${item.step.name}'),
              borderRadius: BorderRadius.circular(12),
              onTap: item.done ? null : () => _open(context, ref, item.step),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      item.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: item.done
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.step.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: item.done ? scheme.onSurfaceVariant : null,
                          decoration: item.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (!item.done)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (business)
            InkWell(
              key: const Key('quickstart-profitLoss'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => premium
                  ? Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfitLossPage(),
                      ),
                    )
                  : openUpgradeOrTrial(context, ref),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.assessment_outlined, color: scheme.primary),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Lihat Laba Rugi usahamu')),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
