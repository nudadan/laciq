/// Parsing heuristik hasil OCR struk (fitur Premium, lihat
/// docs/RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md). Murni Dart, tidak menyentuh
/// ML Kit — supaya bisa diuji tanpa device/emulator. Semua field boleh gagal
/// ditebak (null), tidak pernah melempar — kegagalan tebakan cuma berarti
/// pengguna mengisi manual, bukan error.
library;

/// Hasil tebakan dari teks OCR mentah. Semua field cuma prefill awal —
/// pengguna selalu bisa mengoreksi sebelum menyimpan transaksi.
class ParsedReceipt {
  const ParsedReceipt({this.amount, this.date, this.noteGuess});

  /// Total belanja dalam Rupiah, kalau berhasil ditebak.
  final int? amount;

  /// Tanggal transaksi, kalau berhasil ditebak.
  final DateTime? date;

  /// Tebakan kasar nama merchant/toko, dari baris pertama struk.
  final String? noteGuess;
}

// Dicoba lebih dulu: kata kunci yang spesifik menunjuk NOMINAL YANG BENAR-BENAR
// DIBAYAR, bukan sekadar mengandung kata "total"/"jumlah". Struk dengan
// beberapa sub-total (mis. tabel "Total Penjualan" berisi "Tanpa Subsidi",
// "Subsidi Pemerintah", BARU "Dibayar Konsumen" di baris terakhir — ditemukan
// nyata lewat verifikasi struk SPBU di HP, lihat
// docs/RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md §2.8) bikin heuristik generik
// "baris pertama mengandung total, ambil angka di baris itu/berikutnya" salah
// ambil sub-total, bukan nominal akhir.
// OCR sering salah baca huruf atau menyisipkan spasi ("TOTAL BELAN JA", "TOTAL
// BELANJA" -> "TOTAL BELAN JA", "TUNAI" -> "TUNAJ"), jadi pola label dibuat
// toleran: spasi opsional di dalam kata dan I/J/1/l dianggap sama.
final _highConfidenceTotalLine = RegExp(
  r'(dibayar|total\s*bayar|jumlah\s*bayar|grand\s*total|'
  r'tota[l1i]\s*bel[a-z\s]{0,4}ja)',
  caseSensitive: false,
);

// Fallback kalau tidak ada baris berkata kunci spesifik di atas — cuma
// mengandung "total"/"jumlah" polos, sering kali sekadar label bagian/section
// (mis. "Total Penjualan (Rp)"), bukan nominal akhir.
final _genericTotalLine = RegExp(r'(tota[l1i]|jumlah)', caseSensitive: false);

/// Label uang yang diserahkan pembeli dan kembalian; toleran salah baca OCR.
final _tenderedLabel = RegExp(r'tuna[ij1l]|cash', caseSensitive: false);
final _changeLabel = RegExp(r'kemba[li1j]|change', caseSensitive: false);

// Angka format Rupiah: boleh diawali "Rp", pemisah ribuan titik/koma, minimal
// 3 digit (menghindari menangkap nomor struk/meja satu-dua digit).
final _amountPattern = RegExp(
  r'Rp\.?\s?[\d.,]{3,}|\b\d{1,3}(?:[.,]\d{3})+\b',
  caseSensitive: false,
);

final _monthNames = {
  'jan': 1,
  'januari': 1,
  'feb': 2,
  'februari': 2,
  'mar': 3,
  'maret': 3,
  'apr': 4,
  'april': 4,
  'mei': 5,
  'jun': 6,
  'juni': 6,
  'jul': 7,
  'juli': 7,
  'agu': 8,
  'agustus': 8,
  'sep': 9,
  'september': 9,
  'okt': 10,
  'oktober': 10,
  'nov': 11,
  'november': 11,
  'des': 12,
  'desember': 12,
};

final _numericDatePattern = RegExp(
  r'\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})\b',
);
final _namedMonthDatePattern = RegExp(
  r'\b(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{2,4})\b',
);

/// Mengurai angka Rupiah dari potongan teks (mis. "Rp12.500" atau "12,500")
/// menjadi integer. Null kalau tidak ada angka yang valid.
int? _parseAmount(String text) {
  final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
  if (digitsOnly.isEmpty) return null;
  return int.tryParse(digitsOnly);
}

/// Angka terbesar yang ditemukan di satu baris teks, kalau ada.
int? _largestAmountInLine(String line) {
  int? best;
  for (final m in _amountPattern.allMatches(line)) {
    final v = _parseAmount(m.group(0)!);
    if (v != null && (best == null || v > best)) best = v;
  }
  return best;
}

/// Baris pembayaran/kembalian/metode bayar: angkanya BUKAN total belanja
/// (tunai yang diserahkan hampir selalu lebih besar dari total).
final _tenderLine = RegExp(
  r'(tuna[ij1l]|cash|kemba[li1j]|change|diterima|debit|kredit|kartu|card|'
  r'qris|ovo|gopay|dana|shopeepay|linkaja|e-?wallet|voucher|hemat)',
  caseSensitive: false,
);

/// Baris yang hanya berisi angka (tanpa label huruf; "Rp" tidak dihitung).
bool _isAmountOnlyLine(String line) {
  final withoutRp = line.replaceAll(RegExp(r'Rp\.?', caseSensitive: false), '');
  return !RegExp(r'[A-Za-z]{2,}').hasMatch(withoutRp);
}

int? _findAmountByKeyword(List<String> lines, RegExp keyword) {
  for (var i = 0; i < lines.length; i++) {
    if (!keyword.hasMatch(lines[i])) continue;
    // Coba baris yang sama dulu, lalu baris berikutnya (banyak struk retail
    // menaruh label dan nominal di baris terpisah).
    final sameLine = _largestAmountInLine(lines[i]);
    if (sameLine != null) return sameLine;
    // Baris berikutnya hanya dipakai bila berisi angka saja. Bila berlabel
    // lain ("TUNAI : 50.000"), itu angka milik label tersebut, bukan milik kita.
    if (i + 1 < lines.length && _isAmountOnlyLine(lines[i + 1])) {
      final nextLine = _largestAmountInLine(lines[i + 1]);
      if (nextLine != null) return nextLine;
    }
  }
  return null;
}

/// Angka pada baris berlabel [keyword] (mis. "TUNAI"), atau pada baris angka
/// tepat sesudahnya bila labelnya sendirian.
int? _amountForLabel(List<String> lines, RegExp keyword) =>
    _findAmountByKeyword(lines, keyword);

int? _extractAmount(List<String> lines) {
  // Tingkat 1: kata kunci spesifik ("dibayar", "total bayar", dst.) — paling
  // dipercaya untuk struk dengan beberapa sub-total.
  final specific = _findAmountByKeyword(lines, _highConfidenceTotalLine);
  // Tingkat 2: "total"/"jumlah" polos — bisa saja cuma label bagian, tapi
  // lebih baik dari tebakan acak.
  final candidate = specific ?? _findAmountByKeyword(lines, _genericTotalLine);

  // Uang yang benar-benar dibayar = tunai - kembali (bila keduanya terbaca).
  final tendered = _amountForLabel(lines, _tenderedLabel);
  final change = _amountForLabel(lines, _changeLabel);
  final paid = (tendered != null && change != null && tendered > change)
      ? tendered - change
      : null;

  if (candidate != null) {
    // Angka yang sama dengan uang tunai atau kembalian pasti salah ambil
    // (label total terbaca berdampingan dengan angka baris lain): pakai paid.
    if (paid != null && (candidate == tendered || candidate == change)) {
      return paid;
    }
    return candidate;
  }
  // Tingkat 3: tidak ada label total yang terbaca — pakai tunai - kembali.
  if (paid != null) return paid;
  // Tingkat 4: angka terbesar di baris yang BUKAN pembayaran/kembalian (asumsi
  // total biasanya nominal terbesar di struk — heuristik kasar, bukan akurat).
  int? best;
  for (final line in lines) {
    if (_tenderLine.hasMatch(line)) continue;
    final v = _largestAmountInLine(line);
    if (v != null && (best == null || v > best)) best = v;
  }
  return best;
}

/// Satu baris teks hasil OCR beserta kotak pembatasnya (koordinat piksel).
/// Murni Dart supaya penyusunan baris bisa diuji tanpa ML Kit.
class OcrLine {
  const OcrLine(
    this.text, {
    required this.top,
    required this.bottom,
    required this.left,
  });

  final String text;
  final double top;
  final double bottom;
  final double left;

  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
}

/// Menyusun potongan teks OCR menjadi baris visual: potongan yang sejajar
/// (selisih titik tengah vertikal kurang dari setengah tinggi huruf) digabung
/// jadi satu baris dan diurut dari kiri ke kanan.
///
/// ML Kit sering memecah "TOTAL BELANJA :" dan "40,100" menjadi dua potongan.
/// Mengurutkan per batas atas saja membuat angka di foto yang sedikit miring
/// jatuh SEBELUM labelnya, sehingga angka baris berikutnya (mis. TUNAI)
/// terbaca sebagai milik label itu.
List<String> orderLinesIntoRows(List<OcrLine> lines) {
  if (lines.isEmpty) return const [];
  final sorted = [...lines]..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<OcrLine>>[];
  for (final line in sorted) {
    if (rows.isNotEmpty) {
      final row = rows.last;
      final rowCenter =
          row.map((l) => l.centerY).reduce((a, b) => a + b) / row.length;
      final rowHeight =
          row.map((l) => l.height).reduce((a, b) => a + b) / row.length;
      final tolerance =
          0.5 * (line.height < rowHeight ? line.height : rowHeight);
      if ((line.centerY - rowCenter).abs() <= tolerance) {
        row.add(line);
        continue;
      }
    }
    rows.add([line]);
  }
  return [
    for (final row in rows)
      (row..sort((a, b) => a.left.compareTo(b.left)))
          .map((l) => l.text)
          .join(' '),
  ];
}

DateTime? _extractDate(String rawText) {
  final numeric = _numericDatePattern.firstMatch(rawText);
  if (numeric != null) {
    final day = int.tryParse(numeric.group(1)!);
    final month = int.tryParse(numeric.group(2)!);
    var year = int.tryParse(numeric.group(3)!);
    if (day != null && month != null && year != null) {
      if (year < 100) year += 2000;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        try {
          return DateTime(year, month, day);
        } on ArgumentError {
          return null;
        }
      }
    }
  }
  final named = _namedMonthDatePattern.firstMatch(rawText);
  if (named != null) {
    final day = int.tryParse(named.group(1)!);
    final month = _monthNames[named.group(2)!.toLowerCase()];
    var year = int.tryParse(named.group(3)!);
    if (day != null && month != null && year != null) {
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    }
  }
  return null;
}

String? _extractNoteGuess(List<String> lines) {
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    // Lewati baris yang cuma angka/simbol (nomor struk, tanggal, garis
    // pembatas) — nama toko selalu mengandung huruf.
    if (!RegExp(r'[A-Za-z]{2,}').hasMatch(trimmed)) continue;
    return trimmed;
  }
  return null;
}

/// Mengurai teks mentah hasil OCR (ML Kit) jadi tebakan field transaksi.
/// [rawText] adalah `RecognizedText.text` — multi-baris, urutan sesuai posisi
/// vertikal di foto.
ParsedReceipt parseReceiptText(String rawText) {
  final lines = rawText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const ParsedReceipt();
  return ParsedReceipt(
    amount: _extractAmount(lines),
    date: _extractDate(rawText),
    noteGuess: _extractNoteGuess(lines),
  );
}
