import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/recurrence.dart';
import '../transactions/transaction_form_page.dart';

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringRulesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Berulang')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(
          context,
          const TransactionFormPage(initialFrequency: Frequency.monthly),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        top: false,
        child: AsyncBody<List<RuleView>>(
          value: rules,
          builder: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.repeat,
                message:
                    'Belum ada transaksi berulang.\n'
                    'Cocok untuk gaji, sewa, cicilan, atau langganan:\n'
                    'dicatat otomatis sesuai jadwal.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: list.length,
              itemBuilder: (context, i) => _RuleTile(list[i]),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _open(BuildContext context, Widget page) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => page));
  if (message != null) notify(messenger, message);
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile(this.v);

  final RuleView v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule = v.rule;
    final isTransfer = rule.type == TxType.transfer;
    final dimmed = !rule.active || v.finished;
    final title = isTransfer ? 'Transfer' : (v.category?.name ?? '-');
    final account = isTransfer
        ? '${v.account.name} → ${v.transferTo?.name ?? '-'}'
        : v.account.name;
    final status = !rule.active
        ? 'Dijeda'
        : v.finished
        ? 'Selesai'
        : 'Berikutnya ${DateFormat('d MMM yyyy', 'id_ID').format(v.nextDue)}';
    final color = switch (rule.type) {
      TxType.income => context.palette.income,
      TxType.expense => context.palette.expense,
      TxType.transfer => context.palette.transfer,
    };

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: GlassCard(
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: ListTile(
          onTap: () => _open(context, TransactionFormPage(editingRule: rule)),
          leading: isTransfer
              ? CategoryBadge(
                  icon: Icons.swap_horiz_rounded,
                  color: context.palette.transfer,
                )
              : CategoryBadge(
                  icon: categoryIcon(v.category!.icon),
                  color: Color(v.category!.color),
                ),
          title: Text(
            rule.note == null ? title : '$title · ${rule.note}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${scheduleDescription(rule.frequency, rule.startDate)}\n'
            '$account · $status',
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rupiah(rule.amount),
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              PopupMenuButton<String>(
                onSelected: (a) => _onAction(context, ref, a),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                  if (!v.finished)
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(rule.active ? 'Jeda' : 'Lanjutkan'),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String a) async {
    final db = ref.read(databaseProvider);
    switch (a) {
      case 'edit':
        await _open(context, TransactionFormPage(editingRule: v.rule));
      case 'toggle':
        await db.setRecurringActive(v.rule.id, active: !v.rule.active);
        if (v.rule.active) return; // baru dijeda; tidak ada yang dicatat
        // Baru dilanjutkan: catat yang jatuh tempo hari ini bila ada.
        await ref.read(recurringGeneratorProvider)();
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus transaksi berulang?'),
            content: const Text(
              'Transaksi yang sudah tercatat tetap ada. '
              'Hanya jadwal ke depan yang dihentikan.',
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
        if (ok == true) {
          await db.deleteRecurringRule(v.rule.id);
          await ref.read(recurringReminderServiceProvider).cancelFor(v.rule.id);
        }
    }
  }
}
