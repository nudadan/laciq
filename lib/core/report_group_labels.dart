import '../data/database.dart';

/// Istilah kelompok laporan Laba Rugi untuk pengguna (lihat
/// docs/RENCANA-IMPLEMENTASI-UMKM.md §4.2). Dipakai editor kategori dan layar
/// laporan supaya penamaannya sama di semua tempat.
String reportGroupLabel(ReportGroup g) => switch (g) {
  ReportGroup.revenue => 'Pendapatan usaha',
  ReportGroup.cogs => 'Harga pokok penjualan (HPP)',
  ReportGroup.opex => 'Beban operasional',
  ReportGroup.otherIncome => 'Pendapatan lain',
  ReportGroup.otherExpense => 'Beban lain',
  ReportGroup.nonPnl => 'Di luar laba rugi',
};

/// Penjelasan satu kalimat dengan contoh, supaya pengguna awam paham bedanya.
String reportGroupHint(ReportGroup g) => switch (g) {
  ReportGroup.revenue => 'Hasil jualan barang atau jasa utama usahamu.',
  ReportGroup.cogs => 'Biaya langsung barang yang dijual: stok, bahan baku.',
  ReportGroup.opex => 'Biaya menjalankan usaha: sewa, gaji, listrik, iklan.',
  ReportGroup.otherIncome => 'Pemasukan di luar jualan: bunga, hadiah.',
  ReportGroup.otherExpense =>
    'Biaya di luar operasional: bunga pinjaman, denda.',
  ReportGroup.nonPnl =>
    'Tidak mengubah untung-rugi, tetapi mengubah kas: modal, prive, '
        'beli peralatan, pokok cicilan, tabungan.',
};

/// Pilihan kelompok untuk sebuah jenis, urut tampil di editor.
List<ReportGroup> reportGroupChoices(TxType type) => [
  for (final g in ReportGroup.values)
    if (g.allowedFor(type)) g,
];
