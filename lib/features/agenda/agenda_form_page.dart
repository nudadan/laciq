import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/recurrence.dart';

/// Form tambah/ubah agenda pribadi — lebih sederhana dari
/// [TransactionFormPage]: tanpa akun/kategori, cuma estimasi biaya opsional
/// (servis kendaraan, servis AC, biaya pendidikan, dll). Transaksi nyata
/// baru tercatat saat agenda dieksekusi (lihat `agenda_page.dart`).
class AgendaFormPage extends ConsumerStatefulWidget {
  const AgendaFormPage({super.key, this.editing});

  final AgendaReminder? editing;

  @override
  ConsumerState<AgendaFormPage> createState() => _AgendaFormPageState();
}

class _AgendaFormPageState extends ConsumerState<AgendaFormPage> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _estimateCtrl = TextEditingController();
  late Frequency _frequency;
  late DateTime _startDate;
  DateTime? _endDate;
  int _reminderDaysBefore = 1;
  String? _error;

  static const _leadOptions = [1, 3, 7];

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final item = widget.editing;
    if (item != null) {
      _titleCtrl.text = item.title;
      _noteCtrl.text = item.note ?? '';
      _frequency = item.frequency;
      _startDate = item.startDate;
      _endDate = item.endDate;
      _reminderDaysBefore = item.reminderDaysBefore;
      if (item.estimatedAmount != null) {
        _estimateCtrl.text = groupedNumber(item.estimatedAmount!);
      }
    } else {
      _frequency = Frequency.monthly;
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _estimateCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Judul tidak boleh kosong.');
      return;
    }
    final end = _endDate;
    if (end != null && dateOnly(end).isBefore(dateOnly(_startDate))) {
      setState(
        () => _error = 'Tanggal berakhir tidak boleh sebelum tanggal mulai.',
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final estimatedAmount = parseRupiah(_estimateCtrl.text);
    try {
      if (_editing) {
        await db.updateAgenda(
          id: widget.editing!.id,
          title: _titleCtrl.text,
          note: _noteCtrl.text,
          endDate: _endDate,
          reminderDaysBefore: _reminderDaysBefore,
          estimatedAmount: estimatedAmount,
        );
      } else {
        await db.addAgenda(
          title: _titleCtrl.text,
          ledgerId: ref.read(activeLedgerIdProvider),
          frequency: _frequency,
          startDate: _startDate,
          note: _noteCtrl.text,
          endDate: _endDate,
          reminderDaysBefore: _reminderDaysBefore,
          estimatedAmount: estimatedAmount,
        );
      }
      if (mounted) {
        Navigator.of(context)
            .pop(_editing ? 'Perubahan disimpan' : 'Agenda ditambahkan');
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
      appBar: AppBar(title: Text(_editing ? 'Ubah Agenda' : 'Agenda Baru')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Judul'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _estimateCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(),
              ],
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Estimasi biaya (opsional)',
              ),
            ),
            const SizedBox(height: 16),
            if (_editing)
              FieldTile(
                leading: Icons.repeat_rounded,
                title: scheduleDescription(_frequency, _startDate),
                subtitle:
                    'Mulai ${DateFormat('d MMM yyyy', 'id_ID').format(_startDate)}',
              )
            else ...[
              FieldTile(
                leading: Icons.event_rounded,
                title: dateFmt.format(_startDate),
                subtitle: 'Tanggal mulai',
                onTap: () async {
                  final picked = await _pickDate(_startDate);
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Frequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Ulangi',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: [
                  for (final f in Frequency.values)
                    DropdownMenuItem(value: f, child: Text(frequencyLabel(f))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _frequency = v);
                },
              ),
            ],
            // Tidak relevan untuk agenda sekali: status selesainya berbasis
            // eksekusi/nextIndex (lihat AgendaView.finished), bukan tanggal.
            if (_frequency != Frequency.once) ...[
              FieldTile(
                leading: Icons.event_busy_rounded,
                title: _endDate == null
                    ? 'Tanpa tanggal berakhir'
                    : 'Berakhir ${dateFmt.format(_endDate!)}',
                trailing: _endDate == null
                    ? null
                    : IconButton(
                        tooltip: 'Hapus tanggal berakhir',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _endDate = null),
                      ),
                onTap: () async {
                  final picked = await _pickDate(
                    _endDate ?? _startDate,
                    first: dateOnly(_startDate),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<int>(
              initialValue: _reminderDaysBefore,
              decoration: const InputDecoration(
                labelText: 'Ingatkan berapa hari sebelumnya',
                prefixIcon: Icon(Icons.notifications_active_rounded),
              ),
              items: [
                for (final d in _leadOptions)
                  DropdownMenuItem(value: d, child: Text('H-$d')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _reminderDaysBefore = v);
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
