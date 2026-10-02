import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Path absolut ke file foto struk dari nilai `Transactions.receiptPath`
/// (format relatif `receipts/<nama-file>`). Dipakai baik saat scan struk baru
/// ([lib/features/transactions/receipt_scanner.dart]) maupun saat memulihkan
/// foto dari backup cloud ([lib/features/cloud_backup/cloud_backup_page.dart]).
Future<String> resolveReceiptPath(String relativePath) async {
  final docsDir = await getApplicationDocumentsDirectory();
  return '${docsDir.path}/$relativePath';
}

/// Menulis [bytes] foto struk ke [relativePath] di penyimpanan lokal,
/// membuat folder `receipts/` dulu kalau belum ada. Idempoten — menimpa file
/// lama di path yang sama tanpa error.
Future<void> writeReceiptFile(String relativePath, List<int> bytes) async {
  final absolute = await resolveReceiptPath(relativePath);
  final file = File(absolute);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}

/// File foto struk bila ADA di perangkat ini, null bila tidak (belum pernah
/// ada, sudah dihapus, atau backup dipulihkan tanpa foto).
Future<File?> existingReceiptFile(String relativePath) async {
  final file = File(await resolveReceiptPath(relativePath));
  return await file.exists() ? file : null;
}

/// Menghapus file foto struk. Tidak melempar bila file sudah tidak ada.
Future<void> deleteReceiptFile(String relativePath) async {
  try {
    final file = File(await resolveReceiptPath(relativePath));
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Gagal menghapus tidak boleh mengganggu alur pengguna.
  }
}

/// Membersihkan foto yatim di `receipts/`: file yang tidak dirujuk satu pun
/// transaksi (termasuk yang sudah dihapus lunak, karena masih bisa
/// dibatalkan). Foto yang dibuat dalam [grace] terakhir dibiarkan, sebab
/// bisa saja milik form yang belum disimpan. Mengembalikan jumlah file yang
/// dihapus.
Future<int> purgeOrphanReceiptFiles(
  Set<String> referencedRelativePaths, {
  Duration grace = const Duration(days: 1),
  DateTime? now,
}) async {
  var removed = 0;
  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/receipts');
    if (!await dir.exists()) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(grace);
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (referencedRelativePaths.contains('receipts/$name')) continue;
      if ((await entity.lastModified()).isAfter(cutoff)) continue;
      await entity.delete();
      removed++;
    }
  } catch (_) {
    // Pembersihan hanya perawatan; abaikan kegagalan.
  }
  return removed;
}
