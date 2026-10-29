import 'database.dart';

/// Menebak kelompok Laba Rugi dari NAMA sebuah kategori baru, supaya pengguna
/// usaha tidak perlu memilih manual untuk kategori yang jelas (mis. "Beli stok"
/// = HPP, "Prive" = di luar laba rugi). Hanya saran: pengguna selalu bisa
/// menggantinya, dan null berarti "tidak yakin, biarkan otomatis" (bawaan jenis).
///
/// Sengaja sederhana dan konservatif (kata kunci, bukan AI): lebih baik tidak
/// menebak daripada salah menebak. Urutan pemeriksaan penting: "di luar laba
/// rugi" lebih dulu agar "Pembelian Peralatan" tidak dianggap HPP karena kata
/// "pembelian". Lihat docs/RENCANA-IMPLEMENTASI-UMKM.md §4.2.
ReportGroup? suggestReportGroup(TxType type, String name) {
  final n = _normalize(name);
  if (n.isEmpty || type == TxType.transfer) return null;
  bool has(Iterable<String> words) => words.any(n.contains);

  if (type == TxType.income) {
    if (has(_incomeNonPnl)) return ReportGroup.nonPnl;
    if (has(_incomeOther)) return ReportGroup.otherIncome;
    return null;
  }

  // Pengecualian: kata yang mengandung kata kunci tetapi artinya lain.
  if (has(_notCogs)) return null;
  if (has(_expenseNonPnl)) return ReportGroup.nonPnl;
  if (has(_expenseOther)) return ReportGroup.otherExpense;
  if (has(_expenseCogs)) return ReportGroup.cogs;
  return null;
}

String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();

// Pemasukan.
const _incomeNonPnl = [
  'modal',
  'pinjaman',
  'utang',
  'piutang',
  'tabungan',
  'setoran',
  'pelunasan',
  'suntikan dana',
];
const _incomeOther = [
  'pendapatan lain',
  'bunga',
  'hadiah',
  'cashback',
  'refund',
  'jual aset',
  'penjualan aset',
];

// Pengeluaran. Kata kunci dicocokkan sebagai potongan teks (kecuali yang diberi
// spasi), jadi "peralatan" cocok dengan "Pembelian Peralatan".
const _expenseNonPnl = [
  'prive',
  'peralatan',
  'perlengkapan besar',
  'mesin',
  'kendaraan',
  'aset',
  'investasi',
  'tabungan',
  'cicilan pokok',
  'angsuran pokok',
  'cicilan usaha',
  'pelunasan',
  'bayar utang',
  'bayar pinjaman',
  'penarikan pemilik',
];
const _expenseOther = ['bunga', 'denda', 'kerugian', 'selisih kas'];
const _expenseCogs = [
  'stok',
  'bahan baku',
  'bahan',
  'kulak',
  'barang dagang',
  'dagangan',
  'pembelian barang',
  'beli barang',
  'hpp',
  'harga pokok',
  'kemasan',
  'packaging',
  'produksi',
];
const _notCogs = ['bahan bakar', 'bbm'];
