import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/csv_export.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../settings/share_file.dart';
import '../subscription/trial_offer.dart';

/// Ikon yang ditawarkan untuk sebuah buku kas (subset dari [categoryIcons]).
const ledgerIconKeys = <String>[
  'savings',
  'business',
  'home',
  'family',
  'shopping',
  'car',
  'education',
  'travel',
  'investment',
  'other',
];

String _templateLabel(LedgerTemplate t) => switch (t) {
  LedgerTemplate.personal => 'Pribadi',
  LedgerTemplate.business => 'Bisnis',
  LedgerTemplate.blank => 'Kosong',
};

String _templateHint(LedgerTemplate t) => switch (t) {
  LedgerTemplate.personal =>
    'Kategori harian: makan, transport, tagihan, gaji, dst.',
  LedgerTemplate.business =>
    'Kategori usaha: stok, gaji karyawan, sewa, pajak, penjualan, jasa, dst.',
  LedgerTemplate.blank =>
    'Hanya Lainnya, Utang, dan Piutang. Buat sendiri sisanya.',
};

/// Lingkaran ikon berwarna milik sebuah buku kas.
class LedgerAvatar extends StatelessWidget {
  const LedgerAvatar(this.ledger, {super.key, this.radius = 18});

  final Ledger ledger;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = Color(ledger.color);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Icon(categoryIcon(ledger.icon), size: radius, color: color),
    );
  }
}

/// Chip di AppBar yang menampilkan buku aktif dan membuka pengalih buku.
/// Hanya tampil untuk pengguna Ultimate.
class LedgerChip extends ConsumerWidget {
  const LedgerChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(multiLedgerEnabledProvider)) return const SizedBox.shrink();
    final ledger = ref.watch(activeLedgerProvider);
    if (ledger == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        tooltip: 'Ganti buku kas',
        avatar: CircleAvatar(radius: 6, backgroundColor: Color(ledger.color)),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(ledger.name, overflow: TextOverflow.ellipsis),
        ),
        onPressed: () => showLedgerSwitcher(context),
      ),
    );
  }
}

Future<void> showLedgerSwitcher(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _SwitcherSheet(),
    );

class _SwitcherSheet extends ConsumerWidget {
  const _SwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = [
      for (final l in ref.watch(ledgersProvider).value ?? const <Ledger>[])
        if (!l.archived) l,
    ];
    final balances = ref.watch(ledgerBalancesProvider).value ?? const {};
    final active = ref.watch(activeLedgerIdProvider);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Buku kas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          for (final l in ledgers)
            ListTile(
              leading: LedgerAvatar(l),
              title: Text(l.name),
              subtitle: Text(rupiah(balances[l.id] ?? 0)),
              trailing: l.id == active
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                await ref.read(activeLedgerPrefProvider.notifier).select(l.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Kelola buku kas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LedgersPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Penanda "Mencatat di: nama buku" di form transaksi. Risiko terbesar fitur
/// multi buku kas adalah transaksi masuk ke buku yang salah, jadi buku aktif
/// harus selalu terlihat saat mencatat. Hanya tampil untuk Ultimate.
class RecordingInLedgerBanner extends ConsumerWidget {
  const RecordingInLedgerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(multiLedgerEnabledProvider)) return const SizedBox.shrink();
    final ledger = ref.watch(activeLedgerProvider);
    if (ledger == null) return const SizedBox.shrink();
    final color = Color(ledger.color);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(categoryIcon(ledger.icon), size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mencatat di: ${ledger.name}',
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kelola buku kas: tambah, ubah, arsipkan, ekspor CSV, hapus.
class LedgersPage extends ConsumerWidget {
  const LedgersPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_LedgerForm>(
      context: context,
      builder: (_) => const _LedgerDialog(),
    );
    if (result == null) return;
    try {
      final db = ref.read(databaseProvider);
      final id = await db.addLedger(
        name: result.name,
        icon: result.icon,
        color: result.color,
        template: result.template,
      );
      // Template Bisnis sudah menjadikannya buku usaha; selain itu ikuti saklar.
      if (result.business != (result.template == LedgerTemplate.business)) {
        await db.setLedgerKind(
          id,
          result.business ? LedgerKind.business : LedgerKind.personal,
        );
      }
      await ref.read(activeLedgerPrefProvider.notifier).select(id);
      if (context.mounted) notify(messenger, 'Buku kas ditambahkan');
    } on LedgerException catch (e) {
      if (context.mounted) notify(messenger, e.message);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Ledger l) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_LedgerForm>(
      context: context,
      builder: (_) => _LedgerDialog(existing: l),
    );
    if (result == null) return;
    try {
      final db = ref.read(databaseProvider);
      await db.updateLedger(
        id: l.id,
        name: result.name,
        icon: result.icon,
        color: result.color,
      );
      if (result.business != (l.kind == LedgerKind.business)) {
        await db.setLedgerKind(
          l.id,
          result.business ? LedgerKind.business : LedgerKind.personal,
        );
      }
      if (context.mounted) notify(messenger, 'Buku kas diperbarui');
    } on LedgerException catch (e) {
      if (context.mounted) notify(messenger, e.message);
    }
  }

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    Ledger l,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(databaseProvider)
          .setLedgerArchived(l.id, archived: !l.archived);
      if (context.mounted) {
        notify(
          messenger,
          l.archived ? 'Buku kas dipulihkan' : 'Buku kas diarsipkan',
        );
      }
    } on LedgerException catch (e) {
      if (context.mounted) notify(messenger, e.message);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Ledger l) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    final usage = await db.ledgerUsage(l.id);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus buku "${l.name}"?'),
        content: Text(
          'Buku ini beserta seluruh isinya akan dihapus PERMANEN: '
          '${usage.accounts} dompet dan ${usage.transactions} transaksi, '
          'juga kategori, anggaran, target, agenda, dan utang/piutang di '
          'dalamnya. Ini tidak bisa dibatalkan.\n\n'
          'Cadangkan atau ekspor CSV dulu bila perlu.',
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
    try {
      await db.deleteLedger(l.id);
      if (context.mounted) notify(messenger, 'Buku kas dihapus');
    } on LedgerException catch (e) {
      if (context.mounted) notify(messenger, e.message);
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref, Ledger l) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final items = await ref
          .read(databaseProvider)
          .getTransactions(ledgerId: l.id);
      if (items.isEmpty) {
        notify(messenger, 'Tidak ada transaksi untuk diekspor.');
        return;
      }
      await shareTextFile(
        fileName: 'laciq-${l.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}.csv',
        content: buildTransactionsCsv(items),
        mimeType: 'text/csv',
        subject: 'Transaksi ${l.name}',
      );
    } catch (e) {
      notify(messenger, 'Ekspor gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(ledgersProvider);
    final balances = ref.watch(ledgerBalancesProvider).value ?? const {};
    final ultimate = ref.watch(isUltimateProvider).value ?? false;
    final active = ref.watch(activeLedgerIdProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Buku Kas')),
      floatingActionButton: ultimate
          ? FloatingActionButton.extended(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Buku Baru'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: AsyncBody<List<Ledger>>(
          value: ledgers,
          builder: (list) {
            final locked = lockedLedgerIds(list, ultimate: ultimate);
            final hasLockedByPlan =
                !ultimate && list.any((l) => l.id != kMainLedgerId);
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (!ultimate)
                  GlassCard(
                    margin: const EdgeInsets.fromLTRB(20, 8, 20, 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasLockedByPlan
                              ? 'Buku tambahan terkunci'
                              : 'Pisahkan pembukuan pribadi dan bisnis',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasLockedByPlan
                              ? 'Langganan Ultimate tidak aktif. Data buku tambahan '
                                    'tetap aman dan bisa diekspor. Berlangganan Ultimate '
                                    'untuk membukanya kembali.'
                              : 'Dengan Ultimate, setiap buku punya dompet, kategori, '
                                    'anggaran, dan laporan sendiri.',
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () => openUpgradeOrTrial(context, ref),
                            child: const Text('Lihat Ultimate'),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final l in list)
                  GlassCard(
                    padding: EdgeInsets.zero,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    child: ListTile(
                      leading: LedgerAvatar(l),
                      title: Text(l.name),
                      subtitle: Text(
                        [
                          if (l.id == active) 'Aktif',
                          if (l.archived)
                            'Diarsipkan'
                          else if (locked.contains(l.id))
                            'Terkunci',
                          rupiah(balances[l.id] ?? 0),
                        ].join(' · '),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Aksi',
                        onSelected: (action) => switch (action) {
                          'edit' => _edit(context, ref, l),
                          'archive' => _toggleArchive(context, ref, l),
                          'csv' => _exportCsv(context, ref, l),
                          'delete' => _delete(context, ref, l),
                          _ => null,
                        },
                        itemBuilder: (_) => [
                          if (!locked.contains(l.id) || l.archived && ultimate)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Ubah'),
                            ),
                          if (l.id != kMainLedgerId && ultimate)
                            PopupMenuItem(
                              value: 'archive',
                              child: Text(l.archived ? 'Pulihkan' : 'Arsipkan'),
                            ),
                          const PopupMenuItem(
                            value: 'csv',
                            child: Text('Ekspor CSV'),
                          ),
                          if (l.id != kMainLedgerId && ultimate)
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Hapus',
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

typedef _LedgerForm = ({
  String name,
  String icon,
  int color,
  LedgerTemplate template,
  bool business,
});

/// Dialog buat/ubah buku. Memiliki controller-nya sendiri agar tidak disposed
/// sebelum animasi tutup selesai (lihat catatan yang sama di tags_page.dart).
class _LedgerDialog extends StatefulWidget {
  const _LedgerDialog({this.existing});

  final Ledger? existing;

  @override
  State<_LedgerDialog> createState() => _LedgerDialogState();
}

class _LedgerDialogState extends State<_LedgerDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late var _icon = widget.existing?.icon ?? ledgerIconKeys.first;
  late var _color = widget.existing?.color ?? categoryColors[5];
  var _template = LedgerTemplate.personal;
  late var _business = widget.existing?.kind == LedgerKind.business;

  /// Pengguna sudah mengatur saklar sendiri, jadi ia tidak lagi mengikuti template.
  var _businessTouched = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop<_LedgerForm>(context, (
      name: _name.text,
      icon: _icon,
      color: _color,
      template: _template,
      business: _business,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Ubah Buku Kas' : 'Buku Kas Baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama buku'),
            ),
            if (!_editing) ...[
              const SizedBox(height: 8),
              const Text('Isi awal'),
              RadioGroup<LedgerTemplate>(
                groupValue: _template,
                onChanged: (v) => setState(() {
                  _template = v ?? _template;
                  if (!_businessTouched) {
                    _business = _template == LedgerTemplate.business;
                  }
                }),
                child: Column(
                  children: [
                    for (final t in LedgerTemplate.values)
                      RadioListTile<LedgerTemplate>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: t,
                        title: Text(_templateLabel(t)),
                        subtitle: Text(_templateHint(t)),
                      ),
                  ],
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Buku usaha'),
              subtitle: const Text(
                'Kategori dikelompokkan untuk laporan Laba Rugi '
                '(pendapatan, HPP, beban).',
              ),
              value: _business,
              onChanged: (v) => setState(() {
                _business = v;
                _businessTouched = true;
              }),
            ),
            const SizedBox(height: 8),
            const Text('Ikon'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in ledgerIconKeys)
                  SwatchButton(
                    selected: key == _icon,
                    onTap: () => setState(() => _icon = key),
                    child: Icon(categoryIcon(key), size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Warna'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categoryColors)
                  SwatchButton(
                    selected: c == _color,
                    fill: Color(c),
                    onTap: () => setState(() => _color = c),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
