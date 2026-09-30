import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(allAccountsProvider);

    return AsyncBody<List<AccountBalance>>(
      value: accounts,
      builder: (list) {
        final active = list.where((a) => !a.archived).toList();
        final archived = list.where((a) => a.archived).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, kBottomPad),
          children: [
            for (final a in active)
              _AccountCard(a, onTap: () => _edit(context, ref, a)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Dompet'),
            ),
            if (archived.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
                child: Text(
                  'Diarsipkan',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              for (final a in archived)
                _AccountCard(a, onTap: () => _edit(context, ref, a)),
            ],
          ],
        );
      },
    );
  }

  /// [account] null = dompet baru.
  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AccountBalance? account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await showDialog<String>(
      context: context,
      builder: (_) =>
          _AccountDialog(existing: account, db: ref.read(databaseProvider)),
    );
    if (message != null) notify(messenger, message);
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard(this.a, {required this.onTap});

  final AccountBalance a;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    return Opacity(
      opacity: a.archived ? 0.55 : 1,
      child: GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            CategoryBadge(
              icon: accountKindIcon(a.kind),
              color: accountKindColor(a.kind, brightness, palette),
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    style: text.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accountKindLabel(a.kind),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              rupiah(a.balance),
              style: text.titleSmall?.copyWith(
                color: a.balance < 0 ? palette.expense : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tambah atau ubah dompet ([existing] null = tambah). Menutup dengan pesan
/// singkat untuk ditampilkan pemanggil, atau null bila dibatalkan.
///
/// Dialog memiliki controller-nya sendiri. Controller TIDAK boleh di-dispose
/// oleh pemanggil setelah showDialog selesai: animasi penutupan dialog masih
/// membangun ulang TextField dan akan memakai controller yang sudah mati.
///
/// Penyimpanan dilakukan di sini (bukan oleh pemanggil) agar kesalahan
/// validasi, mis. nama kembar, tampil di dalam dialog tanpa membuang isiannya.
class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.existing, required this.db});

  final AccountBalance? existing;
  final AppDatabase db;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _balance = TextEditingController(
    text: switch (widget.existing?.initialBalance) {
      null || 0 => '',
      final v => groupedNumber(v),
    },
  );
  late var _kind = widget.existing?.kind ?? AccountKind.bank;
  String? _error;
  var _busy = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  /// Menjalankan [action]; kesalahan validasi ditampilkan di dialog, sukses
  /// menutup dialog dengan [message].
  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AccountException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
      return;
    }
    if (mounted) Navigator.pop(context, message);
  }

  Future<void> _submit() {
    final existing = widget.existing;
    final name = _name.text;
    final balance = parseRupiah(_balance.text) ?? 0;
    return existing == null
        ? _run(
            () => widget.db.addAccount(
              name: name,
              kind: _kind,
              initialBalance: balance,
            ),
            'Dompet ditambahkan',
          )
        : _run(
            () => widget.db.updateAccount(
              id: existing.id,
              name: name,
              kind: _kind,
              initialBalance: balance,
            ),
            'Dompet diperbarui',
          );
  }

  Future<void> _toggleArchive() async {
    final a = widget.existing!;
    if (!a.archived && a.balance != 0) {
      // Saldo yang masih ada akan keluar dari Total Saldo: pastikan disengaja.
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Arsipkan ${a.name}?'),
          content: Text(
            'Saldo ${rupiah(a.balance)} tidak akan dihitung di Total Saldo '
            'selama dompet ini diarsipkan. Riwayat transaksinya tetap ada '
            'dan dompet bisa dipulihkan kapan saja.',
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
      if (ok != true || !mounted) return;
    }
    await _run(
      () => widget.db.setAccountArchived(a.id, archived: !a.archived),
      a.archived ? 'Dompet dipulihkan' : 'Dompet diarsipkan',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Ubah Dompet' : 'Tambah Dompet'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'Nama (mis. BCA, GoPay)',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: [
                for (final k in AccountKind.values)
                  DropdownMenuItem(value: k, child: Text(accountKindLabel(k))),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balance,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(),
              ],
              decoration: InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Saldo awal',
                helperText: _editing
                    ? 'Mengubah saldo awal mengubah saldo dompet.'
                    : null,
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_editing)
          TextButton(
            onPressed: _busy ? null : _toggleArchive,
            child: Text(widget.existing!.archived ? 'Pulihkan' : 'Arsipkan'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
