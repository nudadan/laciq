import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/budget_status.dart';
import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetProgressProvider);
    return Column(
      children: [
        const MonthSelector(),
        Expanded(
          child: AsyncBody<List<BudgetProgress>>(
            value: progress,
            builder: (list) => ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, kBottomPad),
              itemCount: list.length,
              itemBuilder: (context, i) => _BudgetTile(list[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetTile extends ConsumerWidget {
  const _BudgetTile(this.p);

  final BudgetProgress p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final budget = p.budget;
    final ratio = budget == null ? 0.0 : p.spent / budget;
    final status = budgetStatusOf(p.spent, budget);
    final over = status == BudgetStatus.over;
    // Hemat: warna kategori. Mendekati batas: kuning. Melewati: merah.
    final barColor = switch (status) {
      BudgetStatus.over => palette.expense,
      BudgetStatus.warning => palette.warning,
      BudgetStatus.ok => Color(p.category.color),
    };

    if (budget == null) {
      // Belum ada anggaran: baris ringkas satu garis agar daftar tidak menjemukan.
      return GlassCard(
        onTap: () => _editBudget(context, ref),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CategoryBadge(
              icon: categoryIcon(p.category.icon),
              color: Color(p.category.color),
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.category.name,
                    style: text.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.spent > 0
                        ? 'Terpakai ${rupiah(p.spent)} · Belum ada anggaran'
                        : 'Belum ada anggaran',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12), // teks panjang membungkus, tak menempel
            Icon(
              Icons.add_circle_outline_rounded,
              size: 22,
              color: scheme.primary,
            ),
          ],
        ),
      );
    }

    return GlassCard(
      onTap: () => _editBudget(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBadge(
                icon: categoryIcon(p.category.icon),
                color: Color(p.category.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  p.category.name,
                  style: text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(ratio * 100).floor()}%',
                style: text.titleMedium?.copyWith(color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GradientBar(value: ratio, color: barColor),
          const SizedBox(height: 10),
          Text(
            over
                ? 'Melebihi ${rupiah(p.spent - budget)} dari ${rupiah(budget)}'
                : '${rupiah(p.spent)} dari ${rupiah(budget)} · sisa ${rupiah(budget - p.spent)}',
            style: text.bodySmall?.copyWith(
              color: over ? palette.expense : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final result = await showDialog<_BudgetResult>(
      context: context,
      builder: (context) => _BudgetDialog(
        title: 'Anggaran ${p.category.name}',
        current: p.budget,
      ),
    );
    if (result == null) return; // dibatalkan
    await db.setBudget(p.category.id, result.amount);
  }
}

/// `amount` null = hapus anggaran.
typedef _BudgetResult = ({int? amount});

/// Dialog memiliki controller-nya sendiri (lihat catatan di _AddAccountDialog).
class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.title, required this.current});

  final String title;
  final int? current;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final _ctrl = TextEditingController(
    text: widget.current == null ? '' : groupedNumber(widget.current!),
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseRupiah(_ctrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Masukkan nominal anggaran.');
      return;
    }
    Navigator.pop<_BudgetResult>(context, (amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
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
          labelText: 'Batas per bulan',
          errorText: _error,
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () =>
                Navigator.pop<_BudgetResult>(context, (amount: null)),
            child: const Text('Hapus'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
