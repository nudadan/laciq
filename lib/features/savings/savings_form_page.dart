import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Membuat ([savings] null) atau mengubah nama/ikon/warna tabungan.
/// Menutup halaman dengan `String?` pesan konfirmasi.
class SavingsFormPage extends ConsumerStatefulWidget {
  const SavingsFormPage({super.key, this.savings});

  final SavingsAccount? savings;

  @override
  ConsumerState<SavingsFormPage> createState() => _SavingsFormPageState();
}

class _SavingsFormPageState extends ConsumerState<SavingsFormPage> {
  late final _nameCtrl = TextEditingController(text: widget.savings?.name);
  late String _icon = widget.savings?.icon ?? goalIconKeys.first;
  late int _color = widget.savings?.color ?? categoryColors[7];
  String? _error;

  bool get _isEdit => widget.savings != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final existing = widget.savings;
    try {
      if (existing == null) {
        await db.addSavings(
          name: _nameCtrl.text,
          icon: _icon,
          color: _color,
          ledgerId: ref.read(activeLedgerIdProvider),
        );
      } else {
        await db.updateSavings(
          id: existing.id,
          name: _nameCtrl.text,
          icon: _icon,
          color: _color,
        );
      }
    } on SavingsException catch (e) {
      setState(() => _error = e.message);
      return;
    } on LedgerException catch (e) {
      setState(() => _error = e.message);
      return;
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
      return;
    }
    if (mounted) {
      Navigator.of(context)
          .pop(_isEdit ? 'Perubahan disimpan' : 'Tabungan dibuat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Tabungan' : 'Tabungan Baru')),
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
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: const InputDecoration(
                labelText: 'Nama tabungan (mis. Dana darurat)',
              ),
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
