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
final _highConfidenceTotalLine = RegExp(
  r'(dibayar|total\s*bayar|jumlah\s*bayar|grand\s*total|total\s*belanja)',
  caseSensitive: false,
);

// Fallback kalau tidak ada baris berkata kunci spesifik di atas — cuma
// mengandung "total"/"jumlah" polos, sering kali sekadar label bagian/section
// (mis. "Total Penjualan (Rp)"), bukan nominal akhir.
final _genericTotalLine = RegExp(r'(total|jumlah)', caseSensitive: false);

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

int? _findAmountByKeyword(List<String> lines, RegExp keyword) {
  for (var i = 0; i < lines.length; i++) {
    if (!keyword.hasMatch(lines[i])) continue;
    // Coba baris yang sama dulu, lalu baris berikutnya (banyak struk retail
    // menaruh label dan nominal di baris terpisah).
    final sameLine = _largestAmountInLine(lines[i]);
    if (sameLine != null) return sameLine;
    if (i + 1 < lines.length) {
      final nextLine = _largestAmountInLine(lines[i + 1]);
      if (nextLine != null) return nextLine;
    }
  }
  return null;
}

int? _extractAmount(List<String> lines) {
  // Tingkat 1: kata kunci spesifik ("dibayar", "total bayar", dst.) — paling
  // dipercaya untuk struk dengan beberapa sub-total.
  final specific = _findAmountByKeyword(lines, _highConfidenceTotalLine);
  if (specific != null) return specific;
  // Tingkat 2: "total"/"jumlah" polos — bisa saja cuma label bagian, tapi
  // lebih baik dari tebakan acak.
  final generic = _findAmountByKeyword(lines, _genericTotalLine);
  if (generic != null) return generic;
  // Tingkat 3: angka terbesar di seluruh teks (asumsi total biasanya nominal
  // terbesar di struk — heuristik kasar, bukan akurat).
  int? best;
  for (final line in lines) {
    final v = _largestAmountInLine(line);
    if (v != null && (best == null || v > best)) best = v;
  }
  return best;
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
