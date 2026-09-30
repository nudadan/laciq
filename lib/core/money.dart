import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Semua nominal disimpan sebagai integer Rupiah (tanpa desimal),
/// sehingga tidak ada galat pembulatan floating point.
final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
final _grouped = NumberFormat('#,##0', 'id_ID');

String rupiah(int value) => _rupiah.format(value);

/// Angka dengan pemisah ribuan tanpa simbol: 15000 -> "15.000".
String groupedNumber(int value) => _grouped.format(value);

/// Untuk label ringkas (mis. sumbu grafik): 1500000 -> "Rp 1,5 jt",
/// 15000 -> "Rp 15 rb". Manual (bukan NumberFormat.compact) agar hasilnya
/// pasti dan tidak bergantung data locale.
String compactRupiah(int value) {
  final sign = value < 0 ? '-' : '';
  final v = value.abs();
  final String body;
  if (v >= 1000000000) {
    body = '${_compactDigits(v / 1000000000)} M';
  } else if (v >= 1000000) {
    body = '${_compactDigits(v / 1000000)} jt';
  } else if (v >= 1000) {
    body = '${_compactDigits(v / 1000)} rb';
  } else {
    body = '$v';
  }
  return '${sign}Rp $body';
}

/// Satu angka di belakang koma, tapi dibuang kalau ".0" (mis. 1.0 -> "1",
/// 1.5 -> "1,5"), koma sebagai pemisah desimal ala Indonesia.
String _compactDigits(double v) {
  final rounded = (v * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

int? parseRupiah(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// Memformat input angka dengan pemisah ribuan saat mengetik: 15000 -> 15.000.
class RupiahInputFormatter extends TextInputFormatter {
  static const maxDigits = 12;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    if (digits.isEmpty) return const TextEditingValue();
    final text = _grouped.format(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
