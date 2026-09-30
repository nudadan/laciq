import 'package:dompet_pintar/data/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseReceiptText', () {
    test('struk minimarket dengan TOTAL di baris sendiri', () {
      const raw = '''
INDOMARET
Jl. Merdeka No. 1
23/09/2026 14:30
Aqua 600ml         5.000
Roti Tawar        18.500
TOTAL
Rp23.500
TUNAI            25.000
KEMBALI           1.500
''';
      final r = parseReceiptText(raw);
      expect(r.amount, 23500);
      expect(r.date, DateTime(2026, 9, 23));
      expect(r.noteGuess, 'INDOMARET');
    });

    test('struk retail dengan GRAND TOTAL satu baris', () {
      const raw = '''
ALFAMART
GRAND TOTAL Rp45.000
12 Sep 2026
''';
      final r = parseReceiptText(raw);
      expect(r.amount, 45000);
      expect(r.date, DateTime(2026, 9, 12));
      expect(r.noteGuess, 'ALFAMART');
    });

    test('struk resto dengan Total Bayar dan tanggal titik', () {
      const raw = '''
Warung Makan Sederhana
01.03.2026
Nasi Goreng        22.000
Es Teh              5.000
Total Bayar        27.000
''';
      final r = parseReceiptText(raw);
      expect(r.amount, 27000);
      expect(r.date, DateTime(2026, 3, 1));
      expect(r.noteGuess, 'Warung Makan Sederhana');
    });

    test('struk SPBU tanpa kata kunci total — fallback ke angka terbesar', () {
      const raw = '''
PERTAMINA
Pertalite 5.5L
Rp55.000
''';
      final r = parseReceiptText(raw);
      expect(r.amount, 55000);
      expect(r.noteGuess, 'PERTAMINA');
    });

    test(
      'struk SPBU dengan beberapa sub-total (kasus nyata ditemukan lewat '
      'verifikasi HP) — "Dibayar" diprioritaskan, bukan sub-total di atasnya',
      () {
        const raw = '''
PERTAMINA
SPBU SOEKARNO HATTA
Waktu: 28/09/2026 06:52:58
Informasi Harga BBM (Rp/Liter)
Harga Non Subsidi  : 15.892
Subsidi Pemerintah :  5.892
Harga Jual         : 10.000
Total Penjualan (Rp)
Tanpa Subsidi      : 389.086
Subsidi Pemerintah : 144.236
Dibayar Konsumen   : 244.850
CASH
250.000
''';
        final r = parseReceiptText(raw);
        // Bukan 5.892 (subsidi per liter) atau 389.086 (sub-total "Tanpa
        // Subsidi" — baris pertama yang cocok kata kunci generik "total").
        expect(r.amount, 244850);
        expect(r.date, DateTime(2026, 9, 28));
      },
    );

    test('teks kosong tidak melempar, semua field null', () {
      final r = parseReceiptText('');
      expect(r.amount, isNull);
      expect(r.date, isNull);
      expect(r.noteGuess, isNull);
    });

    test('teks tanpa angka sama sekali — amount null, bukan error', () {
      final r = parseReceiptText('Terima kasih\nSelamat datang kembali');
      expect(r.amount, isNull);
      expect(r.noteGuess, 'Terima kasih');
    });
  });
}
