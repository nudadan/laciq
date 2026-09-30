import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Menambah ([category] null) atau mengubah satu kategori, termasuk
/// mengarsipkan dan memulihkannya. Menutup halaman dengan `String?` pesan.
class CategoryEditorPage extends ConsumerStatefulWidget {
  const CategoryEditorPage({super.key, required this.type, this.category});

  final TxType type;
  final Category? category;

  @override
  ConsumerState<CategoryEditorPage> createState() => _CategoryEditorPageState();
}

class _CategoryEditorPageState extends ConsumerState<CategoryEditorPage> {
  late final _nameCtrl = TextEditingController(text: widget.category?.name);
  late String _icon = widget.category?.icon ?? 'other';
  late int _color = widget.category?.color ?? categoryColors.first;
  late String? _parentId = widget.category?.parentId;
  String? _error;

  bool get _isEdit => widget.category != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Menjalankan [action]; kesalahan validasi ditampilkan di form, bukan crash.
  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
    } on CategoryException catch (e) {
      setState(() => _error = e.message);
      return;
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
      return;
    }
    if (mounted) Navigator.of(context).pop(successMessage);
  }

  Future<void> _save() {
    final db = ref.read(databaseProvider);
    final existing = widget.category;
    return existing == null
        ? _run(
            () => db.addCategory(
              type: widget.type,
              ledgerId: ref.read(activeLedgerIdProvider),
              name: _nameCtrl.text,
              icon: _icon,
              color: _color,
              parentId: _parentId,
            ),
            'Kategori ditambahkan',
          )
        : _run(
            () => db.updateCategory(
              id: existing.id,
              name: _nameCtrl.text,
              icon: _icon,
              color: _color,
              parentId: _parentId,
            ),
            'Perubahan disimpan',
          );
  }

  Future<void> _archive() async {
    final db = ref.read(databaseProvider);
    final c = widget.category!;
    final usage = await db.categoryUsage(c.id);
    if (!mounted) return;

    final notes = [
      if (usage.transactions > 0)
        '${usage.transactions} transaksi yang memakainya tetap tersimpan dan tetap tampil di laporan.',
      if (usage.activeRules > 0)
        '${usage.activeRules} transaksi berulang yang memakainya tetap berjalan.',
      if (usage.hasBudget)
        'Anggarannya disembunyikan dan kembali bila kategori dipulihkan.',
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Arsipkan "${c.name}"?'),
        content: Text(
          [
            'Kategori ini tidak akan muncul lagi sebagai pilihan.',
            ...notes,
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => db.setCategoryArchived(c.id, archived: true),
      'Kategori diarsipkan',
    );
  }

  Future<void> _restore() => _run(
    () => ref
        .read(databaseProvider)
        .setCategoryArchived(widget.category!.id, archived: false),
    'Kategori dipulihkan',
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final archived = widget.category?.archived ?? false;
    // Pilihan induk: kategori sejenis, tingkat atas (bukan sub-kategori),
    // bukan dirinya sendiri. Satu tingkat saja, jadi tidak ada cucu.
    final parentOptions =
        ref
            .watch(allCategoriesProvider(widget.type))
            .value
            ?.where(
              (c) =>
                  !c.archived &&
                  c.parentId == null &&
                  c.id != widget.category?.id,
            )
            .toList() ??
        const <Category>[];

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Kategori' : 'Kategori Baru')),
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
            const SizedBox(height: 8),
            Center(
              child: Text(
                txTypeLabel(widget.type),
                style: TextStyle(color: scheme.outline),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              enabled: !archived,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama kategori'),
            ),
            if (parentOptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _parentId,
                decoration: const InputDecoration(
                  labelText: 'Sub-kategori dari (opsional)',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tidak ada — kategori utama'),
                  ),
                  for (final c in parentOptions)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: archived
                    ? null
                    : (v) => setState(() => _parentId = v),
              ),
            ],
            const SizedBox(height: 8),
            Text('Ikon', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in categoryIcons.entries)
                  SwatchButton(
                    key: ValueKey('icon-${entry.key}'),
                    selected: _icon == entry.key,
                    onTap: archived
                        ? null
                        : () => setState(() => _icon = entry.key),
                    child: Icon(entry.value, size: 22),
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
                    onTap: archived ? null : () => setState(() => _color = c),
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
            if (archived)
              FilledButton.icon(
                onPressed: _restore,
                icon: const Icon(Icons.unarchive_outlined),
                label: const Text('Pulihkan kategori'),
              )
            else ...[
              FilledButton(onPressed: _save, child: const Text('Simpan')),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _archive,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Arsipkan kategori'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
