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
