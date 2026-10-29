import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/excel_export.dart';
import '../../data/profit_loss.dart';
import '../../data/providers.dart';
import '../subscription/trial_offer.dart';

enum ExcelScope { month, last3Months, all }

/// Ekspor laporan Excel (fitur Premium) untuk buku kas yang sedang aktif.
///
/// Berkas dibuat sepenuhnya di perangkat lalu dibagikan lewat menu bagikan
/// Android, sama seperti ekspor CSV dan backup: tidak ada data yang dikirim ke
/// server dan tidak ada izin tambahan.
Future<void> startExcelExport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);

  if (!(ref.read(isPremiumProvider).value ?? false)) {
    await openUpgradeOrTrial(context, ref);
    return;
  }

  final db = ref.read(databaseProvider);
  final month = ref.read(selectedMonthProvider);
  final ledgerId = ref.read(activeLedgerIdProvider);
  final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);

  final scope = await showDialog<ExcelScope>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Ekspor laporan Excel'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, ExcelScope.month),
          child: Text('Bulan $monthLabel'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, ExcelScope.last3Months),
          child: const Text('3 bulan terakhir'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, ExcelScope.all),
          child: const Text('Seluruh riwayat'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Text(
            'Berkas dibuat di perangkat ini dan tidak terenkripsi. '
            'Simpan dan bagikan dengan hati-hati.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
  if (scope == null) return;

  try {
    final DateTime? from;
    final DateTime? to;
    final String periodLabel;
    final String suffix;
    switch (scope) {
      case ExcelScope.month:
        from = AppDatabase.monthStart(month);
        to = AppDatabase.monthEnd(month);
        periodLabel = monthLabel;
        suffix = DateFormat('yyyy-MM').format(month);
      case ExcelScope.last3Months:
        final first = DateTime(month.year, month.month - 2);
        from = AppDatabase.monthStart(first);
        to = AppDatabase.monthEnd(month);
        periodLabel =
            '${DateFormat('MMMM yyyy', 'id_ID').format(first)} - $monthLabel';
        suffix =
            '${DateFormat('yyyy-MM').format(first)}_'
            '${DateFormat('yyyy-MM').format(month)}';
      case ExcelScope.all:
        from = null;
        to = null;
        periodLabel = 'Seluruh riwayat';
        suffix = 'semua';
    }

    final items = await db.getTransactions(
      from: from,
      to: to,
      ledgerId: ledgerId,
    );
    if (items.isEmpty) {
      notify(messenger, 'Tidak ada transaksi untuk diekspor.');
      return;
    }
    // Buku dibaca langsung dari database: provider buku bisa belum terisi bila tidak
    // ada widget yang sedang mendengarkannya (Riverpod menjeda yang tidak terlihat).
    final ledger = (await db.watchLedgers().first)
        .where((l) => l.id == ledgerId)
        .firstOrNull;
    final bookName = ledger?.name ?? 'Buku Utama';
    // Buku usaha mendapat lembar "Laba Rugi" tambahan; buku pribadi tidak berubah.
    ProfitLoss? profitLoss;
    if (ledger?.kind == LedgerKind.business) {
      // Transaksi urut dari yang terlama; "seluruh riwayat" memakai rentang datanya.
      final first = items.first.tx.date;
      final last = items.last.tx.date;
      profitLoss = buildProfitLoss(
        items: items,
        categories: await db.watchLedgerCategories(ledgerId).first,
        from: from ?? DateTime(first.year, first.month, first.day),
        to: to ?? DateTime(last.year, last.month, last.day + 1),
      );
    }
    final bytes = buildTransactionsXlsx(
      items,
      bookName: bookName,
      periodLabel: periodLabel,
      profitLoss: profitLoss,
    );
    await ref.read(binaryShareProvider)(
      fileName: 'laciq-laporan-$suffix.xlsx',
      bytes: bytes,
      mimeType: xlsxMimeType,
      subject: 'Laporan LaciQ - $bookName',
    );
  } catch (e) {
    notify(messenger, 'Ekspor gagal: $e');
  }
}
