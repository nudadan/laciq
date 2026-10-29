// Hasil spike PDF (docs/RENCANA-IMPLEMENTASI-UMKM.md §4.8 langkah 1): paket `pdf`
// merender font variabel yang dibundel pada bobot bawaannya (Plus Jakarta Sans =
// 400), tetapi tidak bisa memilih bobot lain. Huruf tebal memakai instans statis
// di assets/fonts/pdf/. Tes ini menjaga keduanya tetap termuat dan tersemat.
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<pw.Font> _font(String asset) async =>
    pw.Font.ttf(await rootBundle.load(asset));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('font reguler (variabel) dan tebal (statis) termuat dan tersemat', () async {
    final regular = await _font('assets/fonts/PlusJakartaSans.ttf');
    final bold = await _font('assets/fonts/pdf/PlusJakartaSans-Bold.ttf');

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          children: [
            pw.Text(
              'Laba bersih  Rp 3.210.000 (26,0%) — àéîõü “kutip”',
              style: pw.TextStyle(font: regular),
            ),
            pw.Text(
              'Laba bersih  Rp 3.210.000 (26,0%) — àéîõü “kutip”',
              style: pw.TextStyle(font: bold),
            ),
          ],
        ),
      ),
    );
    final Uint8List bytes = await doc.save();

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Nama font tersemat tertulis apa adanya di objek font PDF.
    final text = String.fromCharCodes(bytes);
    expect(text, contains('PlusJakartaSans-Regular'));
    expect(text, contains('PlusJakartaSans-Bold'));
  });
}
