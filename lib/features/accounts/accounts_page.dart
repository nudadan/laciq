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
      builder: (_) => _AccountDialog(
        existing: account,
        db: ref.read(databaseProvider),
        ledgerId: ref.read(activeLedgerIdProvider),
      ),
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
  const _AccountDialog({
    required this.existing,
    required this.db,
    required this.ledgerId,
  });

  final AccountBalance? existing;
  final AppDatabase db;
  final String ledgerId;

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

  /// Null selama dicek. Dompet yang sudah punya transaksi tidak boleh diubah
  /// saldo awalnya (saldo = saldo awal + transaksi, sehingga mengetik saldo
  /// aktual memberi angka yang meleset); gunakan "Sesuaikan saldo".
  bool? _hasTransactions;

  /// Saldo awal terkunci; selama pengecekan juga dianggap terkunci.
  bool get _locked => _editing && _hasTransactions != false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      widget.db.accountHasTransactions(existing.id).then((v) {
        if (mounted) setState(() => _hasTransactions = v);
      });
    }
  }

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
    final balance = _locked
        ? existing!.initialBalance
        : parseRupiah(_balance.text) ?? 0;
    return existing == null
        ? _run(
            () => widget.db.addAccount(
              name: name,
              kind: _kind,
              initialBalance: balance,
              ledgerId: widget.ledgerId,
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

  Future<void> _adjust() async {
    final a = widget.existing!;
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _AdjustDialog(db: widget.db, account: a),
    );
    if (message != null && mounted) Navigator.pop(context, message);
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
              enabled: !_locked,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Saldo awal',
                helperText: _locked
                    ? 'Dompet ini sudah punya transaksi, jadi saldo awal '
                          'dikunci. Gunakan "Sesuaikan saldo" bila saldonya '
                          'tidak sesuai kenyataan.'
                    : null,
                helperMaxLines: 5,
              ),
            ),
            if (_hasTransactions == true && !widget.existing!.archived) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _adjust,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(
                    'Sesuaikan saldo (kini ${rupiah(widget.existing!.balance)})',
                  ),
                ),
              ),
            ],
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

/// Menyesuaikan saldo dompet ke saldo aktual lewat satu transaksi selisih.
/// Menutup dengan pesan singkat, atau null bila dibatalkan. Memiliki
/// controller-nya sendiri (lihat catatan di [_AccountDialog]).
class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.db, required this.account});

  final AppDatabase db;
  final AccountBalance account;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _actual = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _actual.dispose();
    super.dispose();
  }

  int? get _diff {
    final v = parseRupiah(_actual.text);
    return v == null ? null : v - widget.account.balance;
  }

  Future<void> _submit() async {
    final actual = parseRupiah(_actual.text);
    if (actual == null) {
      setState(() => _error = 'Masukkan saldo aktual.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final diff = await widget.db.adjustAccountBalance(
        accountId: widget.account.id,
        actualBalance: actual,
      );
      if (mounted) {
        Navigator.pop(
          context,
          'Saldo disesuaikan menjadi ${rupiah(actual)} '
          '(${diff > 0 ? '+' : '-'}${rupiah(diff.abs())})',
        );
      }
    } on AccountException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff = _diff;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    return AlertDialog(
      title: Text('Sesuaikan saldo ${widget.account.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo di aplikasi saat ini ${rupiah(widget.account.balance)}. '
              'Masukkan saldo yang sebenarnya; selisihnya dicatat sebagai '
              'transaksi "Penyesuaian Saldo" dan riwayat Anda tidak berubah.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actual,
              autofocus: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _error = null),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(),
              ],
              decoration: InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Saldo aktual',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            if (diff != null && diff != 0) ...[
              const SizedBox(height: 12),
              Text(
                diff > 0
                    ? 'Dicatat sebagai pemasukan +${rupiah(diff)}'
                    : 'Dicatat sebagai pengeluaran -${rupiah(diff.abs())}',
                style: TextStyle(
                  color: diff > 0 ? palette.income : palette.expense,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (diff == 0) ...[
              const SizedBox(height: 12),
              Text(
                'Sudah sama dengan saldo di aplikasi.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _busy || diff == 0 ? null : _submit,
          child: const Text('Sesuaikan'),
        ),
      ],
    );
  }
}
