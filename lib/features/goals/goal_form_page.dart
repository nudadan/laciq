import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/recurrence.dart';

/// Membuat ([goal] null) atau mengubah target tabungan.
/// Menutup halaman dengan `String?` pesan konfirmasi.
class GoalFormPage extends ConsumerStatefulWidget {
  const GoalFormPage({super.key, this.goal});

  final SavingsGoal? goal;

  @override
  ConsumerState<GoalFormPage> createState() => _GoalFormPageState();
}

class _GoalFormPageState extends ConsumerState<GoalFormPage> {
  late final _nameCtrl = TextEditingController(text: widget.goal?.name);
  late final _targetCtrl = TextEditingController(
    text: widget.goal == null ? '' : groupedNumber(widget.goal!.targetAmount),
  );
  late String _icon = widget.goal?.icon ?? goalIconKeys.first;
  late int _color = widget.goal?.color ?? categoryColors[7];
  late DateTime? _deadline = widget.goal?.deadline;
  String? _error;

  bool get _isEdit => widget.goal != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final today = dateOnly(DateTime.now());
    final initial = _deadline ?? today.add(const Duration(days: 180));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 30)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final target = parseRupiah(_targetCtrl.text);
    if (target == null) {
      setState(() => _error = 'Masukkan nominal target.');
      return;
    }
    final db = ref.read(databaseProvider);
    final existing = widget.goal;
    try {
      if (existing == null) {
        await db.addGoal(
          name: _nameCtrl.text,
          ledgerId: ref.read(activeLedgerIdProvider),
          targetAmount: target,
          icon: _icon,
          color: _color,
          deadline: _deadline,
        );
      } else {
        await db.updateGoal(
          id: existing.id,
          name: _nameCtrl.text,
          targetAmount: target,
          icon: _icon,
          color: _color,
          deadline: _deadline,
        );
      }
    } on GoalException catch (e) {
      setState(() => _error = e.message);
      return;
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
      return;
    }
    if (mounted) {
      Navigator.of(context)
          .pop(_isEdit ? 'Perubahan disimpan' : 'Target dibuat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Target' : 'Target Baru')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CategoryBadge(
                icon: categoryIcon(_icon),
                color: Color(_color),
                size: 76,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama target (mis. Dana darurat)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(),
              ],
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Nominal target',
              ),
            ),
            const SizedBox(height: 16),
            FieldTile(
              leading: Icons.event_rounded,
              title: _deadline == null
                  ? 'Tanpa tenggat'
                  : 'Tenggat ${DateFormat('d MMMM yyyy', 'id_ID').format(_deadline!)}',
              subtitle: _deadline == null
                  ? 'Isi tenggat untuk melihat perkiraan setoran per bulan'
                  : null,
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      tooltip: 'Hapus tenggat',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _deadline = null),
                    ),
              onTap: _pickDeadline,
            ),
            const SizedBox(height: 20),
            Text('Ikon', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in goalIconKeys)
                  SwatchButton(
                    key: ValueKey('icon-$key'),
                    selected: _icon == key,
                    onTap: () => setState(() => _icon = key),
                    child: Icon(categoryIcon(key), size: 22),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Warna', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categoryColors)
                  SwatchButton(
                    key: ValueKey('color-${c.toRadixString(16)}'),
                    selected: _color == c,
                    onTap: () => setState(() => _color = c),
                    fill: Color(c),
                    child: _color == c
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Simpan')),
          ],
        ),
      ),
    );
  }
}
