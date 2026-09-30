import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'goal_status.dart';
import 'goals_page.dart' show openGoalForm;

class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final v = goals.value?.where((g) => g.goal.id == goalId).firstOrNull;

    if (v == null) {
      return Scaffold(
        appBar: AppBar(),
        body: goals.hasValue
            ? const EmptyState(
                icon: Icons.flag_outlined,
                message: 'Target ini sudah dihapus.',
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final goal = v.goal;
    final status = goalStatus(v, DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    final contributions = ref.watch(goalContributionsProvider(goalId));

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Ubah target',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openGoalForm(context, goal: goal),
          ),
          PopupMenuButton<String>(
            onSelected: (a) => _onMenu(context, ref, v, a),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  goal.archived ? 'Pulihkan target' : 'Arsipkan target',
                ),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Hapus target')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (goal.archived)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'Target ini diarsipkan. Pulihkan untuk menyetor atau menarik dana.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              child: Column(
                children: [
                  RingProgress(
                    value: v.fraction,
                    size: 168,
                    stroke: 14,
                    colors: [
                      v.reached ? context.palette.income : Color(goal.color),
                      Color.lerp(
                        v.reached ? context.palette.income : Color(goal.color),
                        Colors.white,
                        0.35,
                      )!,
                    ],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryIcon(goal.icon),
                          color: Color(goal.color),
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${goalPercent(v)}%',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedAmount(
                    v.saved,
                    style: Theme.of(context).textTheme.headlineMedium!,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'dari ${rupiah(v.target)}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    status.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: goalToneColor(context, status.tone),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: goal.archived
                        ? null
                        : () => _contribute(
                            context,
                            ref,
                            v,
                            ContributionKind.deposit,
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Setor'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: goal.archived || v.saved == 0
                        ? null
                        : () => _contribute(
                            context,
                            ref,
                            v,
                            ContributionKind.withdrawal,
                          ),
                    icon: const Icon(Icons.remove),
                    label: const Text('Tarik'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Riwayat', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            AsyncBody<List<GoalContribution>>(
              value: contributions,
              builder: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: EmptyState(
                        icon: Icons.history,
                        message: 'Belum ada setoran.\nKetuk "Setor" untuk mulai menabung.',
                      ),
                    )
                  : Column(
                      children: [for (final c in list) _ContributionTile(c)],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contribute(
    BuildContext context,
    WidgetRef ref,
    GoalView v,
    ContributionKind kind,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    final result = await showDialog<_ContributionInput>(
      context: context,
      builder: (context) => _ContributionDialog(
        kind: kind,
        goalName: v.goal.name,
        saved: v.saved,
      ),
    );
    if (result == null) return;
    try {
      await db.addContribution(
        goalId: v.goal.id,
        kind: kind,
        amount: result.amount,
        note: result.note,
      );
      if (kind == ContributionKind.deposit &&
          !v.reached &&
          v.saved + result.amount >= v.target) {
        notify(messenger, 'Selamat! Target "${v.goal.name}" tercapai.');
      }
    } on GoalException catch (e) {
      notify(messenger, e.message);
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    GoalView v,
    String action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final db = ref.read(databaseProvider);
    switch (action) {
      case 'archive':
        await db.setGoalArchived(v.goal.id, archived: !v.goal.archived);
        notify(
          messenger,
          v.goal.archived ? 'Target dipulihkan' : 'Target diarsipkan',
        );
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Hapus "${v.goal.name}"?'),
            content: const Text(
              'Target beserta seluruh riwayat setoran dan penarikannya '
              'dihapus permanen dan tidak bisa dikembalikan.\n\n'
              'Saldo dompet Anda tidak terpengaruh. '
              'Untuk menyimpannya tanpa menghapus, pilih Arsipkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await db.deleteGoal(v.goal.id);
        notify(messenger, 'Target dihapus');
        navigator.pop();
    }
  }
}

class _ContributionTile extends ConsumerWidget {
  const _ContributionTile(this.c);

  final GoalContribution c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeposit = c.kind == ContributionKind.deposit;
    final color = isDeposit ? context.palette.income : context.palette.expense;
    final date = DateFormat('d MMM yyyy', 'id_ID').format(c.date);

    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: context.palette.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      // Penghapusan dicoba di sini: bila ditolak (dana jadi negatif), baris
      // tidak dilepas dan pesannya ditampilkan.
      confirmDismiss: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final db = ref.read(databaseProvider);
        try {
          await db.setContributionDeleted(c.id, deleted: true);
        } on GoalException catch (e) {
          notify(messenger, e.message);
          return false;
        }
        notify(
          messenger,
          isDeposit ? 'Setoran dihapus' : 'Penarikan dihapus',
          action: SnackBarAction(
            label: 'Batal',
            onPressed: () async {
              try {
                await db.setContributionDeleted(c.id, deleted: false);
              } on GoalException catch (e) {
                notify(messenger, e.message);
              }
            },
          ),
        );
        return true;
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            isDeposit ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: color,
            size: 18,
          ),
        ),
        title: Text(isDeposit ? 'Setoran' : 'Penarikan'),
        subtitle: Text(c.note == null ? date : '$date · ${c.note}'),
        trailing: Text(
          '${isDeposit ? '+' : '-'}${rupiah(c.amount)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

typedef _ContributionInput = ({int amount, String? note});

/// Dialog memiliki controller-nya sendiri (jangan di-dispose oleh pemanggil:
/// animasi penutupan dialog masih memakainya).
class _ContributionDialog extends StatefulWidget {
  const _ContributionDialog({
    required this.kind,
    required this.goalName,
    required this.saved,
  });

  final ContributionKind kind;
  final String goalName;
  final int saved;

  @override
  State<_ContributionDialog> createState() => _ContributionDialogState();
}

class _ContributionDialogState extends State<_ContributionDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  bool get _isDeposit => widget.kind == ContributionKind.deposit;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseRupiah(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Masukkan nominal.');
      return;
    }
    if (!_isDeposit && amount > widget.saved) {
      setState(() => _error = 'Dana terkumpul hanya ${rupiah(widget.saved)}.');
      return;
    }
    final note = _note.text.trim();
    Navigator.pop<_ContributionInput>(context, (
      amount: amount,
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isDeposit
            ? 'Setor ke ${widget.goalName}'
            : 'Tarik dari ${widget.goalName}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(),
              ],
              decoration: InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Nominal',
                errorText: _error,
                helperText: _isDeposit
                    ? null
                    : 'Tersedia ${rupiah(widget.saved)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isDeposit ? 'Setor' : 'Tarik'),
        ),
      ],
    );
  }
}
