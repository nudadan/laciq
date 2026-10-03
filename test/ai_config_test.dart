import 'package:dompet_pintar/features/ai/ai_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alamat Worker bawaan menunjuk produksi, bukan kosong', () {
    // Tanpa --dart-define, build rilis tetap memanggil Worker. Kosong berarti
    // fitur AI mati diam-diam (regresi build 7).
    expect(kAiExtractionUrl, 'https://dompetku-api.hardan-ti.com/extract');
  });
}
