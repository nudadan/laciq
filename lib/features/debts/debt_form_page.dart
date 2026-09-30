import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Form tambah/ubah utang (pengguna berutang) atau piutang (orang lain
/// berutang ke pengguna) — lebih sederhana dari [AgendaFormPage]: tanpa
/// jadwal/frekuensi, murni pokok + pihak terkait. Tipe (utang/piutang) hanya
/// bisa dipilih saat membuat baru — sengaja tidak bisa diubah saat edit,
/// sama alasannya dengan jadwal [AgendaFormPage] (mengubahnya berarti
/// mengubah makna transaksi pembayaran yang sudah tercatat).
class DebtFormPage extends ConsumerStatefulWidget {
  const DebtFormPage({super.key, this.editing});

  final Debt? editing;

  @override
  ConsumerState<DebtFormPage> createState() => _DebtFormPageState();
}

class _DebtFormPageState extends ConsumerState<DebtFormPage> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DebtType _type = DebtType.debt;
  DateTime? _dueDate;
  String? _error;

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final item = widget.editing;
    if (item != null) {
      _nameCtrl.text = item.counterpartyName;
      _amountCtrl.text = groupedNumber(item.amount);
      _noteCtrl.text = item.note ?? '';
      _type = item.type;
      _dueDate = item.dueDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
    );
  }

  Future<void> _save() async {
    final amount = parseRupiah(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Masukkan nominal lebih dari 0.');
      return;
    }
    final db = ref.read(databaseProvider);
    try {
      if (_editing) {
        await db.updateDebt(
          id: widget.editing!.id,
          counterpartyName: _nameCtrl.text,
          amount: amount,
          note: _noteCtrl.text,
          dueDate: _dueDate,
        );
      } else {
        await db.addDebt(
          type: _type,
          ledgerId: ref.read(activeLedgerIdProvider),
          counterpartyName: _nameCtrl.text,
          amount: amount,
          note: _noteCtrl.text,
          dueDate: _dueDate,
        );
      }
      if (mounted) {
        Navigator.of(context)
            .pop(_editing ? 'Perubahan disimpan' : 'Tersimpan');
      }
    } on AccountException catch (e) {
      setState(() => _error = e.message);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Ubah' : 'Utang/Piutang Baru')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (!_editing)
              SegmentedButton<DebtType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: DebtType.debt, label: Text('Utang')),
                  ButtonSegment(
                    value: DebtType.receivable,
                    label: Text('Piutang'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              )
            else
              FieldTile(
                leading: Icons.swap_horiz_rounded,
                title: _type == DebtType.debt ? 'Utang' : 'Piutang',
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _type == DebtType.debt
                    ? 'Berutang kepada'
                    : 'Berutang dari',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(),
              ],
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Pokok',
              ),
            ),
            const SizedBox(height: 16),
            FieldTile(
              leading: Icons.event_rounded,
              title: _dueDate == null
                  ? 'Tanpa jatuh tempo'
                  : 'Jatuh tempo ${dateFmt.format(_dueDate!)}',
              trailing: _dueDate == null
                  ? null
                  : IconButton(
                      tooltip: 'Hapus jatuh tempo',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
              onTap: () async {
                final picked = await _pickDate(_dueDate ?? DateTime.now());
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
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
