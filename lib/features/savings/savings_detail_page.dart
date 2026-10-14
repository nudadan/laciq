import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/recurrence.dart' show dateOnly;
import 'savings_page.dart' show openSavingsForm, openSavingsUpgrade;

class SavingsDetailPage extends ConsumerWidget {
  const SavingsDetailPage({super.key, required this.savingsId});

  final String savingsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(savingsProvider);
    final v = all.value?.where((s) => s.savings.id == savingsId).firstOrNull;

    if (v == null) {
      return Scaffold(
        appBar: AppBar(),
        body: all.hasValue
            ? const EmptyState(
                icon: Icons.savings_outlined,
                message: 'Tabungan ini sudah dihapus.',
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final savings = v.savings;
    final scheme = Theme.of(context).colorScheme;
    final entries = ref.watch(savingsEntriesProvider(savingsId));
    final ultimate = ref.watch(isUltimateProvider).value ?? false;
    // Ditonton di sini (autoDispose): dialog setor/tarik butuh daftar dompet.
    final wallets =
        ref.watch(accountBalancesProvider).value ?? const <AccountBalance>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(savings.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Ubah tabungan',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openSavingsForm(context, savings: savings),
          ),
          PopupMenuButton<String>(
            onSelected: (a) => _onMenu(context, ref, v, a),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  savings.archived ? 'Pulihkan tabungan' : 'Arsipkan tabungan',
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Hapus tabungan'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (savings.archived)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'Tabungan ini diarsipkan. Pulihkan untuk menyetor atau menarik dana.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              child: Column(
                children: [
                  CategoryBadge(
                    icon: categoryIcon(savings.icon),
                    color: Color(savings.color),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saldo tabungan',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  AnimatedAmount(
                    v.balance,
                    style: Theme.of(context).textTheme.headlineMedium!,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Disetor ${rupiah(v.deposited)} · '
                    'Ditarik ${rupiah(v.withdrawn)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: savings.archived
                        ? null
                        : ultimate
                        ? () => _move(
                            context,
                            ref,
                            v,
                            deposit: true,
                            wallets: wallets,
                          )
                        : () => openSavingsUpgrade(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Setor'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: savings.archived || v.balance <= 0
                        ? null
                        : () => _move(
                            context,
                            ref,
                            v,
                            deposit: false,
                            wallets: wallets,
                          ),
                    icon: const Icon(Icons.remove),
                    label: const Text('Tarik'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Riwayat', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            AsyncBody<List<TxView>>(
              value: entries,
              builder: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: EmptyState(
                        icon: Icons.history,
                        message:
                            'Belum ada setoran.\n'
                            'Ketuk "Setor" untuk memindahkan uang dari dompet.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final e in list)
                          _EntryTile(e, savingsName: savings.name),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    SavingsView v, {
    required bool deposit,
    required List<AccountBalance> wallets,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    if (wallets.isEmpty) {
      notify(messenger, 'Belum ada dompet aktif.');
      return;
    }
    final result = await showDialog<_MoveInput>(
      context: context,
      builder: (context) => _MoveDialog(
        deposit: deposit,
        savingsName: v.savings.name,
        balance: v.balance,
        wallets: wallets,
      ),
    );
    if (result == null) return;
    try {
      if (deposit) {
        await db.depositToSavings(
          savingsId: v.savings.id,
          accountId: result.accountId,
          amount: result.amount,
          date: result.date,
          note: result.note,
        );
      } else {
        await db.withdrawFromSavings(
          savingsId: v.savings.id,
          accountId: result.accountId,
          amount: result.amount,
          date: result.date,
          note: result.note,
        );
      }
      notify(
        messenger,
        deposit
            ? '${rupiah(result.amount)} disetor ke ${v.savings.name}'
            : '${rupiah(result.amount)} ditarik dari ${v.savings.name}',
      );
    } on SavingsException catch (e) {
      notify(messenger, e.message);
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    SavingsView v,
    String action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final db = ref.read(databaseProvider);
    switch (action) {
      case 'archive':
        try {
          await db.setSavingsArchived(
            v.savings.id,
            archived: !v.savings.archived,
          );
          notify(
            messenger,
            v.savings.archived ? 'Tabungan dipulihkan' : 'Tabungan diarsipkan',
          );
        } on SavingsException catch (e) {
          notify(messenger, e.message);
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Hapus "${v.savings.name}"?'),
            content: const Text(
              'Hanya tabungan yang belum pernah dipakai yang bisa dihapus. '
              'Tabungan yang sudah punya riwayat cukup diarsipkan.',
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
          await db.deleteSavings(v.savings.id);
        } on SavingsException catch (e) {
          notify(messenger, e.message);
          return;
        }
        notify(messenger, 'Tabungan dihapus');
        navigator.pop();
    }
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile(this.e, {required this.savingsName});

  final TxView e;
  final String savingsName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = e.tx;
    final isDeposit = tx.type == TxType.expense;
    final color = isDeposit ? context.palette.income : context.palette.expense;
    final date = DateFormat('d MMM yyyy', 'id_ID').format(tx.date);
    final defaultNote = isDeposit
        ? 'Setoran ke $savingsName'
        : 'Penarikan dari $savingsName';
    final wallet = isDeposit
        ? 'dari ${e.account.name}'
        : 'ke ${e.account.name}';
    final note = tx.note == null || tx.note == defaultNote ? null : tx.note;

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: context.palette.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      // Dicoba di sini: bila ditolak (saldo jadi negatif), baris tidak
      // dilepas dan pesannya ditampilkan.
      confirmDismiss: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final db = ref.read(databaseProvider);
        try {
          await db.setSavingsEntryDeleted(tx.id, deleted: true);
        } on SavingsException catch (ex) {
          notify(messenger, ex.message);
          return false;
        }
        notify(
          messenger,
          isDeposit
              ? 'Setoran dihapus, saldo ${e.account.name} dikembalikan'
              : 'Penarikan dihapus, saldo ${e.account.name} dikurangi',
          action: SnackBarAction(
            label: 'Batal',
            onPressed: () async {
              try {
                await db.setSavingsEntryDeleted(tx.id, deleted: false);
              } on SavingsException catch (ex) {
                notify(messenger, ex.message);
              }
            },
          ),
        );
        return true;
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            isDeposit ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: color,
            size: 18,
          ),
        ),
        title: Text(isDeposit ? 'Setoran' : 'Penarikan'),
        subtitle: Text(
          note == null ? '$date · $wallet' : '$date · $wallet · $note',
        ),
        trailing: Text(
          '${isDeposit ? '+' : '-'}${rupiah(tx.amount)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

typedef _MoveInput = ({
  int amount,
  String accountId,
  DateTime date,
  String? note,
});

/// Dialog memiliki controller-nya sendiri (jangan di-dispose oleh pemanggil:
/// animasi penutupan dialog masih memakainya).
class _MoveDialog extends StatefulWidget {
  const _MoveDialog({
    required this.deposit,
    required this.savingsName,
    required this.balance,
    required this.wallets,
  });

  final bool deposit;
  final String savingsName;
  final int balance;
  final List<AccountBalance> wallets;

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _accountId = widget.wallets.first.id;
  DateTime _date = dateOnly(DateTime.now());
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  AccountBalance get _wallet =>
      widget.wallets.firstWhere((w) => w.id == _accountId);

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  void _submit() {
    final amount = parseRupiah(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Masukkan nominal.');
      return;
    }
    if (!widget.deposit && amount > widget.balance) {
      setState(
        () => _error = 'Saldo tabungan hanya ${rupiah(widget.balance)}.',
      );
      return;
    }
    final note = _note.text.trim();
    Navigator.pop<_MoveInput>(context, (
      amount: amount,
      accountId: _accountId,
      date: _date,
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final deposit = widget.deposit;
    return AlertDialog(
      title: Text(
        deposit
            ? 'Setor ke ${widget.savingsName}'
            : 'Tarik dari ${widget.savingsName}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: deposit ? 'Dari dompet' : 'Ke dompet',
                helperText: 'Saldo dompet ${rupiah(_wallet.balance)}',
              ),
              items: [
                for (final w in widget.wallets)
                  DropdownMenuItem(
                    value: w.id,
                    child: Text(w.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _accountId = v ?? _accountId),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
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
                labelText: 'Nominal',
                errorText: _error,
                helperText: deposit
                    ? 'Dicatat sebagai pengeluaran dompet'
                    : 'Tersedia ${rupiah(widget.balance)} · '
                          'dicatat sebagai pemasukan dompet',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            FieldTile(
              leading: Icons.event_rounded,
              title: DateFormat('d MMMM yyyy', 'id_ID').format(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(deposit ? 'Setor' : 'Tarik'),
        ),
      ],
    );
  }
}
