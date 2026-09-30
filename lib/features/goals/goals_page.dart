import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'goal_detail_page.dart';
import 'goal_form_page.dart';
import 'goal_status.dart';

/// Membuka formulir target dan menampilkan pesan hasilnya di halaman pemanggil.
Future<void> openGoalForm(BuildContext context, {SavingsGoal? goal}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await Navigator.of(
    context,
  ).push<String>(MaterialPageRoute(builder: (_) => GoalFormPage(goal: goal)));
  if (message != null) notify(messenger, message);
}

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return AsyncBody<List<GoalView>>(
      value: goals,
      builder: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.flag_outlined,
            message:
                'Belum ada target tabungan.\n'
                'Contoh: dana darurat, liburan, atau HP baru.\n'
                'Ketuk "Target Baru" untuk mulai.',
          );
        }
        final active = list.where((g) => !g.goal.archived).toList();
        final archived = list.where((g) => g.goal.archived).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, kBottomPad),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Target hanya penanda dana yang Anda sisihkan. '
                'Saldo dompet tidak berubah.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final g in active) _GoalCard(g),
            if (archived.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
                child: Text(
                  'Diarsipkan',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              for (final g in archived) _GoalCard(g),
            ],
          ],
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard(this.v);

  final GoalView v;

  @override
  Widget build(BuildContext context) {
    final goal = v.goal;
    final base = Color(goal.color);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final status = goalStatus(v, DateTime.now());
    final ringColor = v.reached ? palette.income : base;

    return Opacity(
      opacity: goal.archived ? 0.55 : 1,
      child: GlassCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GoalDetailPage(goalId: goal.id),
          ),
        ),
        child: Row(
          children: [
            RingProgress(
              value: v.fraction,
              size: 72,
              stroke: 8,
              colors: [ringColor, Color.lerp(ringColor, Colors.white, 0.35)!],
              child: Icon(categoryIcon(goal.icon), color: ringColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.name,
                          style: text.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${goalPercent(v)}%',
                        style: text.titleMedium?.copyWith(color: ringColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rupiah(v.saved)} dari ${rupiah(v.target)}',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.text,
                    style: text.bodySmall?.copyWith(
                      color: goalToneColor(context, status.tone),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
