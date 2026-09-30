import 'package:dompet_pintar/core/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('rupiah memakai format Indonesia tanpa desimal', () {
    expect(rupiah(1500000).replaceAll(' ', ' '), 'Rp 1.500.000');
    expect(rupiah(0).replaceAll(' ', ' '), 'Rp 0');
  });

  test('parseRupiah mengabaikan pemisah dan karakter non-angka', () {
    expect(parseRupiah('15.000'), 15000);
    expect(parseRupiah('Rp 2.500.000'), 2500000);
    expect(parseRupiah(''), isNull);
    expect(parseRupiah('abc'), isNull);
  });

  test('RupiahInputFormatter memberi titik ribuan dan membatasi panjang', () {
    final f = RupiahInputFormatter();
    String fmt(String s) => f
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s))
        .text;
    expect(fmt('15000'), '15.000');
    expect(fmt('1500000'), '1.500.000');
    expect(fmt(''), '');
    expect(
      parseRupiah(fmt('9' * 20)),
      int.parse('9' * RupiahInputFormatter.maxDigits),
    );
  });

  group('compactRupiah', () {
    test('di bawah 1.000 tampil apa adanya', () {
      expect(compactRupiah(0), 'Rp 0');
      expect(compactRupiah(999), 'Rp 999');
    });

    test('ribuan disingkat "rb"', () {
      expect(compactRupiah(15000), 'Rp 15 rb');
      expect(compactRupiah(999000), 'Rp 999 rb');
    });

    test('jutaan disingkat "jt", satu desimal bila perlu', () {
      expect(compactRupiah(2000000), 'Rp 2 jt');
      expect(compactRupiah(1500000), 'Rp 1,5 jt');
    });

    test('miliaran disingkat "M"', () {
      expect(compactRupiah(1200000000), 'Rp 1,2 M');
    });

    test('nilai negatif menjaga tanda minus di depan "Rp"', () {
      expect(compactRupiah(-15000), '-Rp 15 rb');
    });
  });
}
