import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Kelola tag: tambah, ganti nama, hapus. Tag dipakai untuk menandai
/// transaksi (banyak tag per transaksi), bebas dari kategori/anggaran.
class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _TagDialog(title: 'Tag Baru'),
    );
    if (name == null) return;
    try {
      await ref.read(databaseProvider).addTag(name);
      if (context.mounted) notify(messenger, 'Tag ditambahkan');
    } on TagException catch (e) {
      if (context.mounted) notify(messenger, e.message);
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Tag tag) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _TagDialog(title: 'Ganti Nama Tag', initial: tag.name),
    );
    if (name == null) return;
    try {
      await ref.read(databaseProvider).renameTag(tag.id, name);
      if (context.mounted) notify(messenger, 'Nama tag diubah');
    } on TagException catch (e) {
      if (context.mounted) notify(messenger, e.message);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Tag tag) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus tag "${tag.name}"?'),
        content: const Text(
          'Tag ini akan dilepas dari semua transaksi yang memakainya. '
          'Transaksinya sendiri tidak berubah.',
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
    await ref.read(databaseProvider).deleteTag(tag.id);
    if (context.mounted) notify(messenger, 'Tag dihapus');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Tag')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        top: false,
        child: AsyncBody<List<Tag>>(
          value: tags,
          builder: (list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.sell_outlined,
                  message:
                      'Belum ada tag. Tambahkan untuk menandai transaksi '
                      'lintas kategori, mis. "Liburan" atau "Kantor".',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final t in list)
                      GlassCard(
                        padding: EdgeInsets.zero,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.sell_outlined),
                          title: Text(t.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Ganti nama',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _rename(context, ref, t),
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(context, ref, t),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Dialog memiliki controller-nya sendiri agar tidak disposed sebelum
/// animasi tutup dialog selesai (lihat catatan yang sama di budget_page.dart).
class _TagDialog extends StatefulWidget {
  const _TagDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nama tag'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
