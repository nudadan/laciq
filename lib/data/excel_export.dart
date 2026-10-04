import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../core/category_style.dart';
import 'database.dart';
import 'xlsx_writer.dart';

const xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const _noCategory = 'Tanpa kategori';

/// Laporan Excel dari [items] (seluruhnya dihitung di perangkat). Lembar:
/// Ringkasan, Transaksi (data mentah, angka sebagai angka sungguhan supaya bisa
/// dijumlah/di-pivot), Per Kategori, Per Bulan, dan Per Dompet.
///
/// Transfer tidak dihitung sebagai pemasukan/pengeluaran, sama seperti kartu
/// Dashboard; ia hanya muncul di lembar Transaksi dan Per Dompet.
Uint8List buildTransactionsXlsx(
  List<TxView> items, {
  required String bookName,
  required String periodLabel,
  DateTime? generatedAt,
}) {
  final now = generatedAt ?? DateTime.now();
  return buildXlsx([
    _summarySheet(items, bookName, periodLabel, now),
    _transactionsSheet(items),
    _categorySheet(items),
    _monthSheet(items),
    _accountSheet(items),
  ]);
}

// ------------------------------------------------------------- ringkasan

XlsxSheet _summarySheet(
  List<TxView> items,
  String bookName,
  String periodLabel,
  DateTime now,
) {
  var income = 0;
  var expense = 0;
  for (final v in items) {
    if (v.tx.type == TxType.income) income += v.tx.amount;
    if (v.tx.type == TxType.expense) expense += v.tx.amount;
  }
  final net = income - expense;
  final stamp = DateFormat('yyyy-MM-dd HH:mm').format(now);

  final rows = <List<XlsxCell>>[
    [const XlsxCell('LaciQ - Laporan Keuangan', XlsxStyle.title)],
    [XlsxCell('Buku kas: $bookName', XlsxStyle.muted)],
    [XlsxCell('Periode: $periodLabel', XlsxStyle.muted)],
    [XlsxCell('Dibuat: $stamp', XlsxStyle.muted)],
    [],
    [
      const XlsxCell('Ringkasan', XlsxStyle.header),
      const XlsxCell('Nominal', XlsxStyle.header),
    ],
    [const XlsxCell('Total pemasukan'), XlsxCell(income, XlsxStyle.rupiah)],
    [const XlsxCell('Total pengeluaran'), XlsxCell(expense, XlsxStyle.rupiah)],
    [
      const XlsxCell('Selisih (pemasukan - pengeluaran)', XlsxStyle.bold),
      XlsxCell(net, XlsxStyle.boldRupiah),
    ],
    if (income > 0)
      [
        const XlsxCell('Porsi yang ditabung dari pemasukan'),
        XlsxCell(net / income, XlsxStyle.percent),
      ],
    [const XlsxCell('Jumlah transaksi'), XlsxCell(items.length)],
  ];

  final spend = _byCategory(items, TxType.expense).take(5).toList();
  if (spend.isNotEmpty) {
    rows
      ..add([])
      ..add([
        const XlsxCell('5 pengeluaran terbesar', XlsxStyle.header),
        const XlsxCell('Total', XlsxStyle.header),
        const XlsxCell('Porsi', XlsxStyle.header),
      ]);
    for (final c in spend) {
      rows.add([
        XlsxCell(c.name),
        XlsxCell(c.total, XlsxStyle.rupiah),
        XlsxCell(expense == 0 ? 0.0 : c.total / expense, XlsxStyle.percent),
      ]);
    }
  }
  rows
    ..add([])
    ..add([
      const XlsxCell(
        'Dibuat di perangkat Anda oleh LaciQ. Berkas ini tidak terenkripsi; '
        'simpan dan bagikan dengan hati-hati.',
        XlsxStyle.muted,
      ),
    ]);

  return XlsxSheet(
    name: 'Ringkasan',
    rows: rows,
    columnWidths: const [38, 20, 12],
  );
}

// ------------------------------------------------------------- transaksi

XlsxSheet _transactionsSheet(List<TxView> items) {
  const heads = [
    'Tanggal',
    'Jenis',
    'Kategori',
    'Dompet',
    'Dompet Tujuan',
    'Nominal',
    'Catatan',
  ];
  return XlsxSheet(
    name: 'Transaksi',
    rows: [
      [for (final h in heads) XlsxCell(h, XlsxStyle.header)],
      for (final v in items)
        [
          XlsxCell(v.tx.date, XlsxStyle.date),
          XlsxCell(txTypeLabel(v.tx.type)),
          XlsxCell(v.category?.name),
          XlsxCell(v.account.name),
          XlsxCell(v.transferTo?.name),
          XlsxCell(v.tx.amount, XlsxStyle.rupiah),
          XlsxCell(v.tx.note),
        ],
    ],
    columnWidths: const [12, 13, 24, 18, 18, 16, 40],
    freezeHeaderRow: true,
    autoFilter: true,
  );
}

// ----------------------------------------------------------- per kategori

class _Bucket {
  _Bucket(this.name);
  final String name;
  int total = 0;
  int count = 0;
}

List<_Bucket> _byCategory(List<TxView> items, TxType type) {
  final map = <String, _Bucket>{};
  for (final v in items.where((v) => v.tx.type == type)) {
    final key = v.category?.id ?? '';
    final b = map.putIfAbsent(
      key,
      () => _Bucket(v.category?.name ?? _noCategory),
    );
    b.total += v.tx.amount;
    b.count++;
  }
  return map.values.toList()..sort((a, b) => b.total.compareTo(a.total));
}

XlsxSheet _categorySheet(List<TxView> items) {
  final rows = <List<XlsxCell>>[];
  void block(String title, TxType type) {
    final buckets = _byCategory(items, type);
    final sum = buckets.fold<int>(0, (s, b) => s + b.total);
    if (rows.isNotEmpty) rows.add([]);
    rows.add([
      XlsxCell(title, XlsxStyle.header),
      const XlsxCell('Jumlah transaksi', XlsxStyle.header),
      const XlsxCell('Total', XlsxStyle.header),
      const XlsxCell('Porsi', XlsxStyle.header),
    ]);
    if (buckets.isEmpty) {
      rows.add([const XlsxCell('(tidak ada)', XlsxStyle.muted)]);
      return;
    }
    for (final b in buckets) {
      rows.add([
        XlsxCell(b.name),
        XlsxCell(b.count),
        XlsxCell(b.total, XlsxStyle.rupiah),
        XlsxCell(sum == 0 ? 0.0 : b.total / sum, XlsxStyle.percent),
      ]);
    }
    rows.add([
      const XlsxCell('Total', XlsxStyle.bold),
      XlsxCell(buckets.fold<int>(0, (s, b) => s + b.count), XlsxStyle.bold),
      XlsxCell(sum, XlsxStyle.boldRupiah),
    ]);
  }

  block('Pengeluaran per kategori', TxType.expense);
  block('Pemasukan per kategori', TxType.income);
  return XlsxSheet(
    name: 'Per Kategori',
    rows: rows,
    columnWidths: const [32, 18, 18, 10],
  );
}

// -------------------------------------------------------------- per bulan

XlsxSheet _monthSheet(List<TxView> items) {
  final byMonth = <DateTime, ({int income, int expense})>{};
  for (final v in items) {
    if (v.tx.type == TxType.transfer) continue;
    final m = DateTime(v.tx.date.year, v.tx.date.month);
    final cur = byMonth[m] ?? (income: 0, expense: 0);
    byMonth[m] = v.tx.type == TxType.income
        ? (income: cur.income + v.tx.amount, expense: cur.expense)
        : (income: cur.income, expense: cur.expense + v.tx.amount);
  }
  final rows = <List<XlsxCell>>[
    [
      const XlsxCell('Bulan', XlsxStyle.header),
      const XlsxCell('Pemasukan', XlsxStyle.header),
      const XlsxCell('Pengeluaran', XlsxStyle.header),
      const XlsxCell('Selisih', XlsxStyle.header),
    ],
  ];
  if (byMonth.isNotEmpty) {
    final months = byMonth.keys.toList()..sort();
    // Bulan tanpa transaksi di antara bulan pertama dan terakhir tetap tampil
    // (bernilai 0) supaya deret waktunya utuh.
    var m = months.first;
    while (!m.isAfter(months.last)) {
      final t = byMonth[m] ?? (income: 0, expense: 0);
      rows.add([
        XlsxCell(DateFormat('yyyy-MM').format(m)),
        XlsxCell(t.income, XlsxStyle.rupiah),
        XlsxCell(t.expense, XlsxStyle.rupiah),
        XlsxCell(t.income - t.expense, XlsxStyle.rupiah),
      ]);
      m = DateTime(m.year, m.month + 1);
    }
  }
  return XlsxSheet(
    name: 'Per Bulan',
    rows: rows,
    columnWidths: const [12, 18, 18, 18],
    freezeHeaderRow: true,
  );
}

// --------------------------------------------------------------- per dompet

XlsxSheet _accountSheet(List<TxView> items) {
  final map = <String, _AccountTotals>{};
  _AccountTotals of(Account a) =>
      map.putIfAbsent(a.id, () => _AccountTotals(a.name));
  for (final v in items) {
    final t = of(v.account);
    switch (v.tx.type) {
      case TxType.income:
        t.income += v.tx.amount;
      case TxType.expense:
        t.expense += v.tx.amount;
      case TxType.transfer:
        t.transferOut += v.tx.amount;
        final to = v.transferTo;
        if (to != null) of(to).transferIn += v.tx.amount;
    }
  }
  final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  return XlsxSheet(
    name: 'Per Dompet',
    rows: [
      [
        const XlsxCell('Dompet', XlsxStyle.header),
        const XlsxCell('Pemasukan', XlsxStyle.header),
        const XlsxCell('Pengeluaran', XlsxStyle.header),
        const XlsxCell('Transfer keluar', XlsxStyle.header),
        const XlsxCell('Transfer masuk', XlsxStyle.header),
      ],
      for (final t in list)
        [
          XlsxCell(t.name),
          XlsxCell(t.income, XlsxStyle.rupiah),
          XlsxCell(t.expense, XlsxStyle.rupiah),
          XlsxCell(t.transferOut, XlsxStyle.rupiah),
          XlsxCell(t.transferIn, XlsxStyle.rupiah),
        ],
    ],
    columnWidths: const [26, 18, 18, 18, 18],
    freezeHeaderRow: true,
  );
}

class _AccountTotals {
  _AccountTotals(this.name);
  final String name;
  int income = 0;
  int expense = 0;
  int transferOut = 0;
  int transferIn = 0;
}
