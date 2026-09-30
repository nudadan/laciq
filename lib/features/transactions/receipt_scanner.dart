import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/receipt_parser.dart';

/// Hasil satu alur scan struk (OCR + foto tersimpan), fitur Premium. Semua
/// field nullable: kegagalan tebakan/penyimpanan foto tidak pernah
/// menggagalkan alur — pengguna tetap bisa lanjut mengisi manual.
class ScannedReceipt {
  const ScannedReceipt({
    this.amount,
    this.date,
    this.noteGuess,
    this.photoPath,
    this.rawText,
  });

  final int? amount;
  final DateTime? date;
  final String? noteGuess;

  /// Path relatif (dari direktori dokumen app) ke foto struk tersimpan lokal.
  final String? photoPath;

  /// Teks OCR mentah (urut visual) — bahan ekstraksi AI untuk pengguna Ultimate.
  final String? rawText;
}

/// Menyembunyikan `image_picker` + ML Kit dari sisa app — pola sama
/// `NotificationSender`/`SubscriptionStatus`/`CloudBackupService`, supaya
/// widget yang memakainya bisa diuji lewat fake tanpa kamera/device sungguhan.
abstract interface class ReceiptScanner {
  /// Null kalau pengguna membatalkan pemilihan foto.
  Future<ScannedReceipt?> scan(ImageSource source);
}

/// `RecognizedText.text` menggabungkan baris berdasarkan urutan BLOK internal
/// ML Kit, yang terbukti (lewat verifikasi struk asli di HP, lihat
/// docs/RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md §2.8) TIDAK selalu mengikuti
/// urutan visual atas-ke-bawah untuk struk dengan beberapa blok teks
/// berdekatan (mis. tabel harga per-liter sebelum tabel total). Mengurutkan
/// ulang semua baris dari semua blok berdasarkan posisi Y (`boundingBox.top`)
/// yang sebenarnya jauh lebih andal daripada percaya urutan string gabungan.
String _linesByPosition(RecognizedText recognized) {
  final lines = [for (final block in recognized.blocks) ...block.lines]
    ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
  return lines.map((l) => l.text).join('\n');
}

class MlKitReceiptScanner implements ReceiptScanner {
  static const _uuid = Uuid();

  @override
  Future<ScannedReceipt?> scan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // Kompresi bawaan image_picker — cukup untuk OCR & hemat storage lokal
      // maupun kuota Drive nanti saat ikut backup, tanpa package tambahan.
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final String rawText;
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(picked.path),
      );
      rawText = _linesByPosition(result);
    } finally {
      await recognizer.close();
    }
    final parsed = parseReceiptText(rawText);

    String? photoPath;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${docsDir.path}/receipts');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final ext = picked.path.split('.').last;
      final relativePath = 'receipts/${_uuid.v7()}.$ext';
      await File(picked.path).copy('${docsDir.path}/$relativePath');
      photoPath = relativePath;
    } catch (_) {
      // Foto gagal disimpan (mis. storage penuh) — tetap lanjutkan dengan
      // hasil OCR saja, bukan menggagalkan seluruh alur scan.
      photoPath = null;
    }

    return ScannedReceipt(
      amount: parsed.amount,
      date: parsed.date,
      noteGuess: parsed.noteGuess,
      photoPath: photoPath,
      rawText: rawText,
    );
  }
}
