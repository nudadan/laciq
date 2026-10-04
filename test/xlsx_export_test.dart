import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/excel_export.dart';
import 'package:dompet_pintar/data/xlsx_writer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Archive _unzip(List<int> bytes) => ZipDecoder().decodeBytes(bytes);

String _part(Archive a, String path) {
  final f = a.findFile(path);
  expect(f, isNotNull, reason: 'bagian $path harus ada');
  return utf8.decode(f!.content as List<int>);
}

void main() {
  group('penulis xlsx', () {
    test('berkas zip berisi bagian wajib OOXML', () {
      final bytes = buildXlsx([
        const XlsxSheet(
          name: 'A',
          rows: [
            [XlsxCell('x')],
          ],
        ),
        const XlsxSheet(
          name: 'B',
          rows: [
            [XlsxCell(1)],
          ],
        ),
      ]);
      // Tanda tangan zip "PK".
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
      final a = _unzip(bytes);
      for (final p in [
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
        'xl/worksheets/sheet2.xml',
      ]) {
        expect(a.findFile(p), isNotNull, reason: p);
      }
      final wb = _part(a, 'xl/workbook.xml');
      expect(wb, contains('name="A"'));
      expect(wb, contains('name="B"'));
    });

    test('teks, angka, dan tanggal ditulis dengan tipe sel yang benar', () {
      final a = _unzip(
        buildXlsx([
          XlsxSheet(
            name: 'T',
            rows: [
              [
                const XlsxCell('Halo'),
                const XlsxCell(12345, XlsxStyle.rupiah),
                XlsxCell(DateTime(2026, 10, 4), XlsxStyle.date),
                const XlsxCell(0.25, XlsxStyle.percent),
                const XlsxCell(null),
              ],
            ],
          ),
        ]),
      );
      final xml = _part(a, 'xl/worksheets/sheet1.xml');
      expect(xml, contains('<c r="A1" s="0" t="inlineStr">'));
      expect(xml, contains('<c r="B1" s="2"><v>12345</v></c>'));
      expect(xml, contains('<c r="C1" s="3"><v>46299</v></c>'));
      expect(xml, contains('<c r="D1" s="7"><v>0.25</v></c>'));
      expect(xml, isNot(contains('r="E1"')));
    });

    test('nomor seri tanggal Excel', () {
      expect(excelDateSerial(DateTime(1900, 1, 1)), 2);
      expect(excelDateSerial(DateTime(2024)), 45292);
      expect(excelDateSerial(DateTime(2026, 10, 4)), 46299);
      // Jam tidak memengaruhi.
      expect(excelDateSerial(DateTime(2026, 10, 4, 23, 59)), 46299);
    });

    test('teks dengan karakter XML dan rumus tetap menjadi teks biasa', () {
      final a = _unzip(
        buildXlsx([
          const XlsxSheet(
            name: 'T',
            rows: [
              [
                XlsxCell('<a>&"b"'),
                XlsxCell('=HYPERLINK("http://evil")'),
                XlsxCell('+62 811'),
              ],
            ],
          ),
        ]),
      );
      final xml = _part(a, 'xl/worksheets/sheet1.xml');
      expect(xml, contains('&lt;a&gt;&amp;"b"'));
      // Rumus tidak pernah ditulis sebagai <f>; hanya teks inline.
      expect(xml, isNot(contains('<f>')));
      expect(xml, contains('=HYPERLINK("http://evil")</t>'));
      expect(xml, contains('+62 811</t>'));
    });

    test('karakter kontrol dibuang dan surrogat rusak tidak merusak XML', () {
      final a = _unzip(
        buildXlsx([
          XlsxSheet(
            name: 'T',
            rows: [
              [XlsxCell('a\u0000b\u0008c\td\ne\uD800f\uDC00g😀')],
            ],
          ),
        ]),
      );
      final xml = _part(a, 'xl/worksheets/sheet1.xml');
      expect(xml, contains('>abc\td\nefg😀</t>'));
    });

    test('teks sangat panjang dipotong sesuai batas Excel', () {
      final a = _unzip(
        buildXlsx([
          XlsxSheet(
            name: 'T',
            rows: [
              [XlsxCell('x' * 40000)],
            ],
          ),
        ]),
      );
      final xml = _part(a, 'xl/worksheets/sheet1.xml');
      final len = RegExp('>(x+)</t>').firstMatch(xml)!.group(1)!.length;
      expect(len, 32767);
    });

    test(
      'nama lembar dibersihkan: karakter terlarang, panjang, dan duplikat',
      () {
        expect(sanitizeSheetNames(['A/B', 'a/b', '', 'x' * 40]), [
          'A B',
          'a b (2)',
          'Lembar',
          'x' * 31,
        ]);
        // Duplikat pada nama 31 karakter tetap muat dalam 31 karakter.
        final dup = sanitizeSheetNames(['y' * 31, 'y' * 31]);
        expect(dup[1].length, lessThanOrEqualTo(31));
        expect(dup[1], endsWith(' (2)'));
      },
    );

    test('lebar kolom, bekukan baris, dan filter ditulis', () {
      final a = _unzip(
        buildXlsx([
          const XlsxSheet(
            name: 'T',
            rows: [
              [
                XlsxCell('H1', XlsxStyle.header),
                XlsxCell('H2', XlsxStyle.header),
              ],
              [XlsxCell(1), XlsxCell(2)],
            ],
            columnWidths: [10, 20.5],
            freezeHeaderRow: true,
            autoFilter: true,
          ),
        ]),
      );
      final xml = _part(a, 'xl/worksheets/sheet1.xml');
      expect(
        xml,
        contains('<col min="2" max="2" width="20.5" customWidth="1"/>'),
      );
      expect(xml, contains('state="frozen"'));
      expect(xml, contains('<autoFilter ref="A1:B2"/>'));
      expect(xml, contains('<dimension ref="A1:B2"/>'));
    });

    test('kolom ke-27 bernama AA', () {
      final row = [for (var i = 0; i < 27; i++) XlsxCell(i)];
      final a = _unzip(
        buildXlsx([
          XlsxSheet(name: 'T', rows: [row]),
        ]),
      );
      expect(_part(a, 'xl/worksheets/sheet1.xml'), contains('r="AA1"'));
    });

    test('tanpa lembar ditolak', () {
      expect(() => buildXlsx(const []), throwsArgumentError);
    });
  });

  group('laporan Excel dari database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> tx(
      TxType type,
      int amount, {
      String? cat,
      String? note,
      required DateTime date,
      String account = 'acc-tunai',
      String? to,
    }) => db.addTransaction(
      type: type,
      amount: amount,
      accountId: account,
      categoryId: cat,
      transferToAccountId: to,
      note: note,
      date: date,
    );

    test('lima lembar dengan isi yang benar; transfer tidak dihitung', () async {
      await tx(
        TxType.income,
        5000000,
        cat: 'cat-inc-gaji',
        date: DateTime(2026, 9, 1),
      );
      await tx(
        TxType.expense,
        100000,
        cat: 'cat-exp-makan',
        note: 'Siang',
        date: DateTime(2026, 9, 2),
      );
      await tx(
        TxType.expense,
        300000,
        cat: 'cat-exp-makan',
        date: DateTime(2026, 9, 3),
      );
      await tx(
        TxType.expense,
        50000,
        cat: 'cat-exp-transport',
        date: DateTime(2026, 10, 1),
      );
      await db.addAccount(name: 'Dana', kind: AccountKind.ewallet);
      final dana = (await db.watchAccountBalances().first).firstWhere(
        (a) => a.name == 'Dana',
      );
      await tx(TxType.transfer, 70000, to: dana.id, date: DateTime(2026, 9, 4));

      final bytes = buildTransactionsXlsx(
        await db.getTransactions(),
        bookName: 'Buku Utama',
        periodLabel: 'Seluruh riwayat',
        generatedAt: DateTime(2026, 10, 4, 9, 30),
      );
      final a = _unzip(bytes);
      final wb = _part(a, 'xl/workbook.xml');
      for (final n in [
        'Ringkasan',
        'Transaksi',
        'Per Kategori',
        'Per Bulan',
        'Per Dompet',
      ]) {
        expect(wb, contains('name="$n"'));
      }

      final summary = _part(a, 'xl/worksheets/sheet1.xml');
      expect(summary, contains('Buku kas: Buku Utama'));
      expect(summary, contains('Dibuat: 2026-10-04 09:30'));
      // Pemasukan 5.000.000; pengeluaran 450.000 (transfer 70.000 tidak ikut).
      expect(summary, contains('<v>5000000</v>'));
      expect(summary, contains('<v>450000</v>'));
      expect(summary, contains('<v>4550000</v>'));
      expect(summary, isNot(contains('<v>70000</v>')));

      final txs = _part(a, 'xl/worksheets/sheet2.xml');
      expect(txs, contains('Siang'));
      expect(txs, contains('Dana'));
      expect(txs, contains('<autoFilter ref="A1:G6"/>'));

      final cats = _part(a, 'xl/worksheets/sheet3.xml');
      // Makan 400.000 (2 transaksi) mendahului Transportasi 50.000.
      expect(
        cats.indexOf('Makanan &amp; Minuman'),
        lessThan(cats.indexOf('Transportasi')),
      );
      expect(cats, contains('<v>400000</v>'));

      final months = _part(a, 'xl/worksheets/sheet4.xml');
      expect(months, contains('2026-09'));
      expect(months, contains('2026-10'));

      final accounts = _part(a, 'xl/worksheets/sheet5.xml');
      expect(accounts, contains('Dana'));
      expect(accounts, contains('<v>70000</v>')); // transfer keluar/masuk
    });

    test('bulan kosong di antara data tetap muncul dengan nilai 0', () async {
      await tx(
        TxType.expense,
        1000,
        cat: 'cat-exp-makan',
        date: DateTime(2026, 7, 5),
      );
      await tx(
        TxType.expense,
        2000,
        cat: 'cat-exp-makan',
        date: DateTime(2026, 9, 5),
      );
      final a = _unzip(
        buildTransactionsXlsx(
          await db.getTransactions(),
          bookName: 'B',
          periodLabel: 'P',
        ),
      );
      final months = _part(a, 'xl/worksheets/sheet4.xml');
      expect(months, contains('2026-07'));
      expect(months, contains('2026-08'));
      expect(months, contains('2026-09'));
    });

    test('catatan berisi rumus tidak pernah menjadi rumus', () async {
      await tx(
        TxType.expense,
        1000,
        cat: 'cat-exp-makan',
        note: '=1+1',
        date: DateTime(2026, 9, 5),
      );
      final a = _unzip(
        buildTransactionsXlsx(
          await db.getTransactions(),
          bookName: 'B',
          periodLabel: 'P',
        ),
      );
      final txs = _part(a, 'xl/worksheets/sheet2.xml');
      expect(txs, contains('=1+1</t>'));
      expect(txs, isNot(contains('<f>')));
    });
  });
}
