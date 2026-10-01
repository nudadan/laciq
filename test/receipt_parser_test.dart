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

    test('tanpa kata kunci total: tunai - kembali, bukan tunai', () {
      const raw = '''
TOKO KELONTONG
Beras 5kg   60.000
Minyak      32.000
TUNAI       100.000
KEMBALI       8.000
''';
      expect(parseReceiptText(raw).amount, 92000);
    });

    test('angka terbesar mengabaikan baris tunai/kembali/debit', () {
      const raw = '''
KIOS A
Kopi         15.000
Roti         10.000
DEBIT BCA    25.000
TUNAI       200.000
''';
      // Tidak ada kata total dan tidak ada kembalian: ambil angka terbesar
      // yang bukan baris pembayaran.
      expect(parseReceiptText(raw).amount, 15000);
    });

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

  group('orderLinesIntoRows', () {
    // Kotak teks menyalin foto struk Indomaret asli yang dipakai uji di HP
    // (foto sedikit miring: angka kolom kanan berada beberapa piksel LEBIH
    // ATAS dari label di kolom kiri pada baris yang sama). Urutan masukan
    // sengaja acak seperti keluaran ML Kit.
    OcrLine l(String text, double top, double bottom, double left) =>
        OcrLine(text, top: top, bottom: bottom, left: left);

    final indomaret = [
      l('50,000', 1182, 1218, 715),
      l('TOTAL BELANJA :', 1075, 1115, 385),
      l('KEMBALI :', 1245, 1285, 492),
      l('40,100', 1068, 1105, 713),
      l('TUNAI :', 1190, 1228, 527),
      l('9,900', 1238, 1272, 730),
      l('ANDA HEMAT :', 1300, 1338, 445),
      l('500', 1295, 1330, 765),
      l('DISKON :', 975, 1010, 503),
      l('(500)', 968, 1003, 730),
    ];

    test('label dan angka yang sejajar digabung jadi satu baris', () {
      final rows = orderLinesIntoRows(indomaret);
      expect(rows, [
        'DISKON : (500)',
        'TOTAL BELANJA : 40,100',
        'TUNAI : 50,000',
        'KEMBALI : 9,900',
        'ANDA HEMAT : 500',
      ]);
    });

    test('struk Indomaret asli: total belanja 40.100, bukan tunai 50.000', () {
      final raw = [
        'BATUNUNGGAL 117',
        '28.09.26-15:08/4.5.0/TDMK-97114/ZAHRA/01',
        ...orderLinesIntoRows(indomaret),
      ].join('\n');
      final r = parseReceiptText(raw);
      expect(r.amount, 40100);
      expect(r.date, DateTime(2026, 9, 28));
    });

    test('hasil baca ML Kit nyata (label salah baca "TOTAL BELAN JA", '
        '"TUNAJ"): total 40.100', () {
      // Disalin dari log HP (Galaxy Z Fold6) pada uji 2026-10-01.
      const raw = '''
BATUNUNGGAL 117
28.09.26-15:08/4.5.0/TDMK -97114/ZAHRA/01
/e SLTCHS COMBO 175 1 14500 14.500
SEDAAP MIE BSO CUP77 i 1 5600 5,600
POP MI SPCY RMYEON71 1 6500 6,500
DISKON (500)
TOTAL BELAN JA 40,100
TUNAJ: 50.000
KEMBALI : 9.900
ANDA HEMAT: 500
''';
      expect(parseReceiptText(raw).amount, 40100);
    });

    test('baris total tidak terbaca sama sekali: pakai tunai - kembali '
        '(bukan angka barang 14.500)', () {
      const raw = '''
BATUNUNGGAL 117
/e SLTCHS COMBO 175 1 14500 14.500
SEDAAP MIE BSO CUP77 i 1 5600 5,600
DISKON (500)
TOTAL BELAN JA
TUNAJ: 50.000
KEMBALI : 9.900
''';
      expect(parseReceiptText(raw).amount, 40100);
    });

    test('baris yang berurutan tidak ikut tergabung', () {
      final rows = orderLinesIntoRows([
        l('A', 100, 140, 10),
        l('B', 160, 200, 10),
        l('C', 220, 260, 10),
      ]);
      expect(rows, ['A', 'B', 'C']);
    });

    test('daftar kosong menghasilkan daftar kosong', () {
      expect(orderLinesIntoRows(const []), isEmpty);
    });
  });
}
