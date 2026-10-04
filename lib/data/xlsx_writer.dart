import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Penulis berkas Excel (.xlsx) minimal, seluruhnya di perangkat: tanpa
/// jaringan, tanpa pustaka spreadsheet pihak ketiga. Cukup untuk laporan:
/// beberapa lembar, teks, angka, tanggal, judul tebal, filter, dan kolom lebar.
///
/// Teks selalu ditulis sebagai sel teks (`inlineStr`), tidak pernah sebagai
/// rumus, jadi isi seperti `=HYPERLINK(...)` hanya tampil sebagai teks dan
/// tidak perlu diberi awalan seperti pada CSV.

/// Gaya sel. Urutannya harus sama dengan `cellXfs` di [_stylesXml].
enum XlsxStyle {
  normal,
  header,
  rupiah,
  date,
  title,
  bold,
  boldRupiah,
  percent,
  muted,
}

class XlsxCell {
  const XlsxCell(this.value, [this.style = XlsxStyle.normal]);

  /// `String`, `int`, `double`, `DateTime` (hanya tanggalnya), atau null (kosong).
  final Object? value;
  final XlsxStyle style;
}

class XlsxSheet {
  const XlsxSheet({
    required this.name,
    required this.rows,
    this.columnWidths = const [],
    this.freezeHeaderRow = false,
    this.autoFilter = false,
  });

  final String name;
  final List<List<XlsxCell>> rows;

  /// Lebar kolom dalam karakter; kolom di luar daftar memakai lebar bawaan.
  final List<double> columnWidths;

  /// Membekukan baris pertama agar judul kolom tetap terlihat saat menggulir.
  final bool freezeHeaderRow;

  /// Memberi tombol filter pada baris pertama.
  final bool autoFilter;
}

/// Batas Excel: 32.767 karakter per sel, 31 karakter nama lembar.
const _maxCellChars = 32767;

/// Nama lembar valid: maks. 31 karakter, tanpa `[]:*?/\`, tidak kosong, unik
/// (tanpa membedakan huruf besar/kecil).
List<String> sanitizeSheetNames(Iterable<String> names) {
  final used = <String>{};
  final out = <String>[];
  for (final raw in names) {
    var base = raw.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (base.isEmpty) base = 'Lembar';
    if (base.length > 31) base = base.substring(0, 31).trim();
    var candidate = base;
    var n = 2;
    while (!used.add(candidate.toLowerCase())) {
      final suffix = ' ($n)';
      final head = base.length + suffix.length > 31
          ? base.substring(0, 31 - suffix.length)
          : base;
      candidate = '$head$suffix';
      n++;
    }
    out.add(candidate);
  }
  return out;
}

/// Nomor seri tanggal Excel: hari sejak 1899-12-30. Dihitung dari komponen
/// tanggal (UTC) agar tidak terpengaruh zona waktu atau pergantian jam musim.
int excelDateSerial(DateTime d) => DateTime.utc(
  d.year,
  d.month,
  d.day,
).difference(DateTime.utc(1899, 12, 30)).inDays;

Uint8List buildXlsx(List<XlsxSheet> sheets) {
  if (sheets.isEmpty) throw ArgumentError('Minimal satu lembar.');
  final names = sanitizeSheetNames(sheets.map((s) => s.name));

  final archive = Archive();
  void add(String path, String xml) =>
      archive.addFile(ArchiveFile.bytes(path, utf8.encode(xml)));

  add('[Content_Types].xml', _contentTypesXml(sheets.length));
  add('_rels/.rels', _rootRelsXml);
  add('xl/workbook.xml', _workbookXml(names));
  add('xl/_rels/workbook.xml.rels', _workbookRelsXml(sheets.length));
  add('xl/styles.xml', _stylesXml);
  for (var i = 0; i < sheets.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i]));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

// ------------------------------------------------------------------ XML

const _xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const _nsMain = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _nsRel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

String _contentTypesXml(int sheetCount) =>
    '$_xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '${[for (var i = 1; i <= sheetCount; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
    '</Types>';

const _rootRelsXml =
    '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="$_nsRel/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbookXml(List<String> names) =>
    '$_xmlHead<workbook xmlns="$_nsMain" xmlns:r="$_nsRel"><sheets>'
    '${[for (var i = 0; i < names.length; i++) '<sheet name="${_escAttr(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
    '</sheets></workbook>';

String _workbookRelsXml(int sheetCount) =>
    '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '${[for (var i = 1; i <= sheetCount; i++) '<Relationship Id="rId$i" Type="$_nsRel/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
    '<Relationship Id="rId${sheetCount + 1}" Type="$_nsRel/styles" Target="styles.xml"/>'
    '</Relationships>';

/// Font: 0 biasa, 1 tebal, 2 tebal besar, 3 abu-abu.
/// Isian: 0 kosong, 1 abu-abu 125 (wajib), 2 ungu muda (judul kolom).
/// Format angka: 164 Rupiah, 165 tanggal, 166 persen.
const _stylesXml =
    '$_xmlHead<styleSheet xmlns="$_nsMain">'
    '<numFmts count="3">'
    '<numFmt numFmtId="164" formatCode="&quot;Rp&quot;\\ #,##0;[Red]\\-&quot;Rp&quot;\\ #,##0"/>'
    '<numFmt numFmtId="165" formatCode="yyyy\\-mm\\-dd"/>'
    '<numFmt numFmtId="166" formatCode="0.0%"/>'
    '</numFmts>'
    '<fonts count="4">'
    '<font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="14"/><name val="Calibri"/></font>'
    '<font><sz val="10"/><color rgb="FF6B6B80"/><name val="Calibri"/></font>'
    '</fonts>'
    '<fills count="3">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFE8E6FA"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="2">'
    '<border><left/><right/><top/><bottom/><diagonal/></border>'
    '<border><left/><right/><top/><bottom style="thin"><color rgb="FF8884C4"/></bottom><diagonal/></border>'
    '</borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="9">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="left"/></xf>'
    '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="164" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>'
    '<xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

String _sheetXml(XlsxSheet s) {
  final b = StringBuffer(_xmlHead)..write('<worksheet xmlns="$_nsMain">');

  final maxCols = s.rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  final lastRow = s.rows.length;
  if (maxCols > 0 && lastRow > 0) {
    b.write('<dimension ref="A1:${_colName(maxCols - 1)}$lastRow"/>');
  }
  if (s.freezeHeaderRow) {
    b.write(
      '<sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews>',
    );
  }
  if (s.columnWidths.isNotEmpty) {
    b.write('<cols>');
    for (var i = 0; i < s.columnWidths.length; i++) {
      b.write(
        '<col min="${i + 1}" max="${i + 1}" '
        'width="${s.columnWidths[i]}" customWidth="1"/>',
      );
    }
    b.write('</cols>');
  }

  b.write('<sheetData>');
  for (var r = 0; r < s.rows.length; r++) {
    final row = s.rows[r];
    b.write('<row r="${r + 1}">');
    for (var c = 0; c < row.length; c++) {
      _writeCell(b, '${_colName(c)}${r + 1}', row[c]);
    }
    b.write('</row>');
  }
  b.write('</sheetData>');

  if (s.autoFilter && maxCols > 0 && lastRow > 1) {
    b.write('<autoFilter ref="A1:${_colName(maxCols - 1)}$lastRow"/>');
  }
  b.write('</worksheet>');
  return b.toString();
}

void _writeCell(StringBuffer b, String ref, XlsxCell cell) {
  final style = cell.style.index;
  final v = cell.value;
  if (v == null) {
    if (style != 0) b.write('<c r="$ref" s="$style"/>');
    return;
  }
  switch (v) {
    case int():
      b.write('<c r="$ref" s="$style"><v>$v</v></c>');
    case double():
      if (v.isNaN || v.isInfinite) {
        b.write('<c r="$ref" s="$style"/>');
      } else {
        b.write('<c r="$ref" s="$style"><v>$v</v></c>');
      }
    case DateTime():
      b.write('<c r="$ref" s="$style"><v>${excelDateSerial(v)}</v></c>');
    default:
      var text = _cleanText(v.toString());
      if (text.length > _maxCellChars) {
        text = text.substring(0, _maxCellChars);
      }
      b.write(
        '<c r="$ref" s="$style" t="inlineStr"><is>'
        '<t xml:space="preserve">${_escText(text)}</t></is></c>',
      );
  }
}

/// Nama kolom Excel: 0 -> A, 25 -> Z, 26 -> AA.
String _colName(int index) {
  var n = index;
  var out = '';
  do {
    out = String.fromCharCode(65 + n % 26) + out;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return out;
}

/// Membuang karakter yang tidak boleh ada di XML 1.0 (kontrol selain tab,
/// baris baru, dan CR) dan pasangan surrogat yang rusak; berkas dengan
/// karakter itu dianggap korup oleh Excel.
String _cleanText(String s) {
  final out = StringBuffer();
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    if (u == 0x9 || u == 0xA || u == 0xD) {
      out.writeCharCode(u);
    } else if (u < 0x20 || u == 0xFFFE || u == 0xFFFF) {
      continue;
    } else if (u >= 0xD800 && u <= 0xDBFF) {
      if (i + 1 < units.length &&
          units[i + 1] >= 0xDC00 &&
          units[i + 1] <= 0xDFFF) {
        out
          ..writeCharCode(u)
          ..writeCharCode(units[i + 1]);
        i++;
      }
    } else if (u >= 0xDC00 && u <= 0xDFFF) {
      continue;
    } else {
      out.writeCharCode(u);
    }
  }
  return out.toString();
}

String _escText(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _escAttr(String s) => _escText(s).replaceAll('"', '&quot;');
