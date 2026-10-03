import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'receipt_viewer_page.dart';
import 'transaction_form_page.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(monthTransactionsProvider);
    return Column(
      children: [
        const MonthSelector(),
        Expanded(
          child: AsyncBody<List<TxView>>(
            value: txs,
            builder: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_rounded,
                  message: 'Belum ada transaksi bulan ini.\nKetuk "Catat" untuk mulai.',
                );
              }
              return _GroupedList(list);
            },
          ),
        ),
      ],
    );
  }
}

typedef _DayHeader = ({DateTime day, int net});

class _GroupedList extends ConsumerWidget {
  const _GroupedList(this.items);

  final List<TxView> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final dayFmt = DateFormat('EEEE, d MMMM', 'id_ID');

    // Baris datar: _DayHeader (judul hari + selisih hari itu) atau TxView.
    final rows = <Object>[];
    DateTime? current;
    var headerIndex = -1;
    var net = 0;
    for (final v in items) {
      final d = DateTime(v.tx.date.year, v.tx.date.month, v.tx.date.day);
      if (d != current) {
        if (headerIndex >= 0) rows[headerIndex] = (day: current!, net: net);
        current = d;
        net = 0;
        headerIndex = rows.length;
        rows.add((day: d, net: 0));
      }
      net += switch (v.tx.type) {
        TxType.income => v.tx.amount,
        TxType.expense => -v.tx.amount,
        TxType.transfer => 0,
      };
      rows.add(v);
    }
    if (headerIndex >= 0) rows[headerIndex] = (day: current!, net: net);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, kBottomPad),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is _DayHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayFmt.format(row.day),
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (row.net != 0)
                  Text(
                    '${row.net > 0 ? '+' : '-'}${rupiah(row.net.abs())}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: row.net > 0 ? palette.income : palette.expense,
                    ),
                  ),
              ],
            ),
          );
        }
        final v = row as TxView;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Dismissible(
            key: ValueKey(v.tx.id),
            direction: DismissDirection.endToStart,
            background: Container(
              decoration: BoxDecoration(
                color: palette.expense,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            onDismissed: (_) {
              final db = ref.read(databaseProvider);
              db.setTransactionDeleted(v.tx.id, deleted: true);
              notify(
                ScaffoldMessenger.of(context),
                'Transaksi dihapus',
                action: SnackBarAction(
                  label: 'Batal',
                  onPressed: () =>
                      db.setTransactionDeleted(v.tx.id, deleted: false),
                ),
              );
            },
            child: _TxTile(
              v,
              onTap: () => _edit(context, v.tx),
              onViewReceipt: v.tx.receiptPath == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ReceiptViewerPage(relativePath: v.tx.receiptPath!),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _edit(BuildContext context, TxEntry tx) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => TransactionFormPage(editingTx: tx)),
  );
  if (message != null) notify(messenger, message);
}

class _TxTile extends StatelessWidget {
  const _TxTile(this.v, {required this.onTap, this.onViewReceipt});

  final TxView v;
  final VoidCallback onTap;

  /// Non-null bila transaksi punya foto struk; membuka penampil foto.
  final VoidCallback? onViewReceipt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final tx = v.tx;
    final isTransfer = tx.type == TxType.transfer;
    final color = switch (tx.type) {
      TxType.income => palette.income,
      TxType.expense => palette.expense,
      TxType.transfer => palette.transfer,
    };
    final sign = switch (tx.type) {
      TxType.income => '+',
      TxType.expense => '-',
      TxType.transfer => '',
    };
    final title = isTransfer ? 'Transfer' : (v.category?.name ?? '-');
    final account = isTransfer
        ? '${v.account.name} → ${v.transferTo?.name ?? '-'}'
        : v.account.name;
    final subtitle = tx.note == null ? account : '$account · ${tx.note}';

    return GlassCard(
      margin: EdgeInsets.zero,
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          isTransfer
              ? CategoryBadge(
                  icon: Icons.swap_horiz_rounded,
                  color: palette.transfer,
                )
              : CategoryBadge(
                  icon: categoryIcon(v.category!.icon),
                  color: Color(v.category!.color),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: text.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tx.recurringId != null) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.repeat, size: 14, color: scheme.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (onViewReceipt != null) ...[
            Tooltip(
              message: 'Lihat foto struk',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onViewReceipt,
                child: ReceiptThumbnail(relativePath: tx.receiptPath!),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            '$sign${rupiah(tx.amount)}',
            style: text.titleSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
