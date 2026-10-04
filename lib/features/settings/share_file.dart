import 'dart:io';
import 'dart:typed_data';

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
}) => _share(
  fileName: fileName,
  mimeType: mimeType,
  subject: subject,
  write: (file) => file.writeAsString(content),
);

/// Seperti [shareTextFile] untuk berkas biner (mis. .xlsx).
Future<void> shareBinaryFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  String? subject,
}) => _share(
  fileName: fileName,
  mimeType: mimeType,
  subject: subject,
  write: (file) => file.writeAsBytes(bytes),
);

Future<void> _share({
  required String fileName,
  required String mimeType,
  required Future<void> Function(File file) write,
  String? subject,
}) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/exports');
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);

  final file = File('${dir.path}/$fileName');
  await write(file);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: subject,
    ),
  );
}
