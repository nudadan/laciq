import 'package:intl/intl.dart';

import '../core/category_style.dart';
import 'database.dart';

/// Pemisah `;` dipakai karena Excel dengan regional Indonesia memakai titik
/// koma sebagai pemisah daftar; dengan koma, seluruh baris menumpuk di satu
/// kolom. Google Sheets dan LibreOffice mendeteksi keduanya otomatis.
const csvSeparator = ';';

const _bom = '﻿'; // agar Excel membaca UTF-8 dengan benar
const _header = [
  'Tanggal',
  'Jenis',
  'Kategori',
  'Dompet',
  'Dompet Tujuan',
  'Nominal',
  'Catatan',
];

String buildTransactionsCsv(List<TxView> items) {
  final dateFmt = DateFormat('yyyy-MM-dd');
  final rows = <List<String>>[
    _header,
    for (final v in items)
      [
        dateFmt.format(v.tx.date),
        txTypeLabel(v.tx.type),
        _text(v.category?.name ?? ''),
        _text(v.account.name),
        _text(v.transferTo?.name ?? ''),
        // Angka murni tanpa pemisah ribuan agar bisa dijumlah di spreadsheet.
        v.tx.amount.toString(),
        _text(v.tx.note ?? ''),
      ],
  ];
  final body = rows.map((r) => r.map(_quote).join(csvSeparator)).join('\r\n');
  return '$_bom$body\r\n';
}

/// Mencegah CSV/formula injection: sel teks yang diawali `= + - @` (atau tab/CR)
/// akan dieksekusi sebagai rumus oleh Excel/Sheets, jadi diberi awalan `'`.
String _text(String s) => s.isNotEmpty && '=+-@\t\r'.contains(s[0]) ? "'$s" : s;

String _quote(String s) {
  final needsQuote =
      s.contains(csvSeparator) ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r');
  return needsQuote ? '"${s.replaceAll('"', '""')}"' : s;
}
