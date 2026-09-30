import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/goals.dart';

enum GoalTone { neutral, good, bad }

class GoalStatus {
  const GoalStatus(this.text, this.tone);
  final String text;
  final GoalTone tone;
}

int goalPercent(GoalView v) => v.reached ? 100 : (v.fraction * 100).floor();

Color goalToneColor(BuildContext context, GoalTone tone) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    GoalTone.good => context.palette.income,
    GoalTone.bad => context.palette.expense,
    GoalTone.neutral => scheme.onSurfaceVariant,
  };
}

/// Ringkasan satu baris tentang posisi target terhadap sisa dana dan tenggat.
GoalStatus goalStatus(GoalView v, DateTime today) {
  final fmt = DateFormat('d MMM yyyy', 'id_ID');
  final deadline = v.goal.deadline;

  if (v.reached) {
    final extra = v.saved - v.target;
    return GoalStatus(
      extra > 0 ? 'Tercapai · lebih ${rupiah(extra)}' : 'Tercapai',
      GoalTone.good,
    );
  }
  if (deadline == null) {
    return GoalStatus('Sisa ${rupiah(v.remaining)}', GoalTone.neutral);
  }
  if (daysUntil(deadline, today) < 0) {
    return GoalStatus(
      'Lewat tenggat ${fmt.format(deadline)} · sisa ${rupiah(v.remaining)}',
      GoalTone.bad,
    );
  }
  final need = monthlyNeed(
    remaining: v.remaining,
    deadline: deadline,
    today: today,
  );
  return GoalStatus(
    'Sisa ${rupiah(v.remaining)} · perlu ±${rupiah(need!)}/bulan '
    'hingga ${fmt.format(deadline)}',
    GoalTone.neutral,
  );
}
