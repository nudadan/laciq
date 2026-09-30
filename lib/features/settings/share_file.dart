import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Menulis [content] ke file sementara lalu membuka menu bagikan Android.
///
/// Ekspor berisi data keuangan, jadi folder ekspor sebelumnya dihapus lebih
/// dulu: hanya satu salinan terakhir yang tersisa di cache aplikasi.
Future<void> shareTextFile({
  required String fileName,
  required String content,
  required String mimeType,
  String? subject,
}) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/exports');
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);

  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: subject,
    ),
  );
}
