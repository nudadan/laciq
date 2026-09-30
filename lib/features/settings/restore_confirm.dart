import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/backup.dart';
import '../../data/providers.dart';

/// Dialog peringatan + eksekusi `restore()`, dipakai dari mana pun sumber
/// [data]-nya berasal (file lokal via `SettingsPage._restore`, atau backup
/// cloud via `CloudBackupPage`) — begitu sudah ada [BackupData] tervalidasi
/// di tangan, alurnya sama persis. Mengembalikan `true` kalau benar-benar
/// dipulihkan (bukan dibatalkan pengguna) — `CloudBackupPage` memakainya
/// untuk tahu kapan foto struk (fitur Premium) juga perlu diunduh.
Future<bool> confirmAndRestore(
  BuildContext context,
  WidgetRef ref,
  BackupData data,
) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));

  if (!context.mounted) return false;
  final when = data.exportedAt == null
      ? 'tidak diketahui'
      : DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(data.exportedAt!);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: const Text('Pulihkan backup?'),
      content: Text(
        'Backup dibuat: $when\n'
        '${data.activeTransactionCount} transaksi, ${data.accounts.length} dompet, '
        '${data.budgets.length} anggaran.\n\n'
        'SELURUH data yang ada sekarang akan diganti dan tidak bisa dikembalikan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ganti data'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    final service = BackupService(ref.read(databaseProvider));
    await service.restore(data);
    // Aturan berulang di backup mungkin sudah punya kejadian yang jatuh tempo.
    await ref.read(recurringGeneratorProvider)();
    say('Data berhasil dipulihkan.');
    return true;
  } catch (e) {
    // Transaksi dibatalkan penuh: data lama tidak berubah.
    say('Pemulihan gagal, data Anda tidak diubah. ($e)');
    return false;
  }
}
