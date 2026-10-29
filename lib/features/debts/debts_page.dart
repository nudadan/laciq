import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../transactions/transaction_form_page.dart';
import 'debt_form_page.dart';

/// Daftar utang (pengguna berutang) dan piutang (orang lain berutang ke
/// pengguna) — fitur Premium penuh, tanpa versi gratis (pola sama Backup
/// Cloud, gating dilakukan di tile Pengaturan, bukan di halaman ini).
class DebtsPage extends ConsumerWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(debtsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Utang & Piutang')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, const DebtFormPage()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        top: false,
        child: AsyncBody<List<Debt>>(
          value: items,
          builder: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.handshake_rounded,
                message:
                    'Belum ada utang/piutang.\n'
                    'Catat uang yang kamu pinjam dari orang lain (utang) atau '
                    'pinjamkan ke orang lain (piutang).',
                actionLabel: 'Catat utang atau piutang',
                onAction: () => _open(context, const DebtFormPage()),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: list.length,
              itemBuilder: (context, i) => _DebtTile(DebtView(list[i])),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _open(BuildContext context, Widget page) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => page));
  if (message != null) notify(messenger, message);
}

class _DebtTile extends ConsumerWidget {
  const _DebtTile(this.v);

  final DebtView v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = v.item;
    final palette = context.palette;
    final isDebt = item.type == DebtType.debt;
    final color = isDebt ? palette.expense : palette.income;
    final typeLabel = isDebt ? 'Utang' : 'Piutang';
    final status = v.settled
        ? 'Lunas'
        : 'Sisa ${rupiah(v.remaining)}'
              '${item.dueDate != null ? ' · Jatuh tempo ${DateFormat('d MMM yyyy', 'id_ID').format(item.dueDate!)}' : ''}';

    return Opacity(
      opacity: v.settled ? 0.55 : 1,
      child: GlassCard(
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: ListTile(
          onTap: () => _open(context, DebtFormPage(editing: item)),
          leading: CategoryBadge(
            icon: isDebt
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: color,
          ),
          title: Text(
            '$typeLabel · ${item.counterpartyName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(item.note == null ? status : '${item.note}\n$status'),
          isThreeLine: item.note != null,
          trailing: PopupMenuButton<String>(
            onSelected: (a) => _onAction(context, ref, a),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Ubah')),
              if (!v.settled)
                const PopupMenuItem(
                  value: 'pay',
                  child: Text('Catat pembayaran'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String a) async {
    final db = ref.read(databaseProvider);
    switch (a) {
      case 'edit':
        await _open(context, DebtFormPage(editing: v.item));
      case 'pay':
        await _open(context, TransactionFormPage(fromDebtPayment: v.item));
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus catatan ini?'),
            content: const Text(
              'Transaksi pembayaran yang sudah tercatat tidak ikut terhapus.',
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
        if (ok == true) await db.deleteDebt(v.item.id);
    }
  }
}
