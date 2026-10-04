/// Penafsir ucapan transaksi berbahasa Indonesia, seluruhnya di perangkat
/// (tanpa AI, tanpa jaringan): teks hasil pengenalan suara -> jenis, nominal,
/// catatan, tanggal, dan tebakan kategori. Hasilnya hanya mengisi formulir;
/// pengguna selalu memeriksa sebelum menyimpan.
library;

import '../../data/database.dart' show TxType;

class VoiceEntry {
  const VoiceEntry({
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
    this.categoryId,
    this.assumedThousands = false,
  });

  final TxType type;

  /// Rupiah bulat; null bila tidak ada nominal yang terdengar.
  final int? amount;
  final String note;
  final DateTime date;
  final String? categoryId;

  /// Nominal diucapkan tanpa satuan (mis. "makan dua puluh lima") sehingga
  /// dianggap ribuan; layar konfirmasi memberi tahu pengguna.
  final bool assumedThousands;
}

/// Kategori yang tersedia untuk ditebak.
class VoiceCategory {
  const VoiceCategory({required this.id, required this.name});
  final String id;
  final String name;
}

/// Catatan lama pengguna beserta kategorinya: sumber tebakan paling akurat
/// ("kopi" -> Makanan & Minuman karena biasanya begitu).
class VoiceHistoryItem {
  const VoiceHistoryItem({required this.note, required this.categoryId});
  final String note;
  final String categoryId;
}

VoiceEntry parseVoiceEntry(
  String spoken, {
  required DateTime now,
  List<VoiceCategory> categories = const [],
  List<VoiceCategory> Function(TxType type)? categoriesFor,
  List<VoiceHistoryItem> history = const [],
}) {
  var text = _normalize(spoken);

  // Tanggal dulu (sebelum angka), supaya "2 hari lalu" tidak dianggap nominal.
  var date = DateTime(now.year, now.month, now.day);
  final ago = _daysAgo.firstMatch(text);
  if (ago != null) {
    final n = _smallNumber(ago.group(1)!);
    if (n != null) date = date.subtract(Duration(days: n));
    text = text.replaceFirst(ago.group(0)!, ' ');
  } else if (RegExp(r'\b(kemarin lusa|lusa kemarin)\b').hasMatch(text)) {
    date = date.subtract(const Duration(days: 2));
    text = text.replaceAll(RegExp(r'\b(kemarin lusa|lusa kemarin)\b'), ' ');
  } else if (RegExp(r'\bkemarin\b').hasMatch(text)) {
    date = date.subtract(const Duration(days: 1));
    text = text.replaceAll(RegExp(r'\bkemarin\b'), ' ');
  }
  // Selisih hari dihitung dari kalender (bukan jam) agar aman dari DST.
  date = DateTime(date.year, date.month, date.day);

  final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final span = _bestNumberSpan(tokens);

  int? amount;
  var assumedThousands = false;
  final remaining = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    if (span != null && i >= span.start && i < span.end) continue;
    remaining.add(tokens[i]);
  }
  if (span != null) {
    amount = span.value;
    if (!span.hasUnit && amount >= 1 && amount < 1000) {
      amount *= 1000;
      assumedThousands = true;
    }
  }

  final words = remaining.toSet();
  final income = words.any(_incomeCues.contains);
  final type = income ? TxType.income : TxType.expense;

  final noteWords = [
    for (final w in remaining)
      if (!_fillers.contains(w)) w,
  ];
  var note = noteWords.join(' ').trim();
  if (note.isNotEmpty) note = note[0].toUpperCase() + note.substring(1);

  return VoiceEntry(
    type: type,
    amount: amount,
    note: note,
    date: date,
    assumedThousands: assumedThousands,
    // Kategori ditebak dari daftar jenis yang BARU terdeteksi (pengeluaran
    // dan pemasukan punya kategori sendiri).
    categoryId: suggestCategory(
      noteWords,
      categories: categoriesFor?.call(type) ?? categories,
      history: history,
    ),
  );
}

// ----------------------------------------------------------- normalisasi

final _daysAgo = RegExp(
  r'\b(\d+|satu|dua|tiga|empat|lima|enam|tujuh) hari (?:yang )?lalu\b',
);

String _normalize(String s) {
  var t = s.toLowerCase();
  // "Rp25.000", "rp. 25.000" -> angka saja.
  t = t
      .replaceAll(RegExp(r'\brp(?=[\d\s.])\.?\s*'), ' ')
      .replaceAll('rupiah', ' ');
  // Pisahkan angka dari huruf yang menempel: "25rb" -> "25 rb".
  t = t.replaceAllMapped(RegExp(r'(\d)([a-z])'), (m) => '${m[1]} ${m[2]}');
  t = t.replaceAllMapped(RegExp(r'([a-z])(\d)'), (m) => '${m[1]} ${m[2]}');
  // Tanda baca selain pemisah angka menjadi spasi.
  t = t.replaceAll(RegExp(r'[^a-z0-9.,\s]'), ' ');
  // Titik/koma di ujung kata (akhir kalimat) bukan bagian angka.
  t = t.replaceAllMapped(RegExp(r'[.,]+(?=\s|$)'), (_) => ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

int? _smallNumber(String s) => int.tryParse(s) ?? _units[s]?.toInt();

// ---------------------------------------------------------------- angka

const _units = <String, double>{
  'nol': 0,
  'satu': 1,
  'dua': 2,
  'tiga': 3,
  'empat': 4,
  'lima': 5,
  'enam': 6,
  'tujuh': 7,
  'delapan': 8,
  'sembilan': 9,
};

/// Kata yang langsung bernilai penuh.
const _fixed = <String, double>{
  'sepuluh': 10,
  'sebelas': 11,
  'seratus': 100,
  'seribu': 1000,
  'sejuta': 1000000,
  'semiliar': 1000000000,
  'semilyar': 1000000000,
};

/// Sebutan sehari-hari yang sudah mengandung satuan.
const _slang = <String, int>{
  'seceng': 1000,
  'ceceng': 2000,
  'goceng': 5000,
  'ceban': 10000,
  'gocap': 50000,
  'gopek': 500,
  'cepek': 100,
};

const _scale = <String, double>{
  'ribu': 1e3,
  'rb': 1e3,
  'k': 1e3,
  'juta': 1e6,
  'jt': 1e6,
  'miliar': 1e9,
  'milyar': 1e9,
};

class _Span {
  _Span(this.start, this.end, this.value, this.hasUnit);
  final int start;
  final int end;
  final int value;

  /// Ada kata satuan (ribu/juta/...) atau sebutan gaul di dalamnya.
  final bool hasUnit;
}

bool _isNumberToken(String t) =>
    _units.containsKey(t) ||
    _fixed.containsKey(t) ||
    _slang.containsKey(t) ||
    _scale.containsKey(t) ||
    t == 'puluh' ||
    t == 'belas' ||
    t == 'ratus' ||
    t == 'setengah' ||
    _digitValue(t) != null;

final _thousandsDots = RegExp(r'^\d{1,3}(\.\d{3})+$');
final _decimalComma = RegExp(r'^\d+,\d{1,2}$');
final _decimalDot = RegExp(r'^\d+\.\d{1,2}$');

/// Nilai angka bertulis digit: "25", "25.000", "1,5", "2.5".
double? _digitValue(String t) {
  if (RegExp(r'^\d+$').hasMatch(t)) return double.tryParse(t);
  if (_thousandsDots.hasMatch(t)) return double.tryParse(t.replaceAll('.', ''));
  if (_decimalComma.hasMatch(t)) {
    return double.tryParse(t.replaceAll(',', '.'));
  }
  if (_decimalDot.hasMatch(t)) return double.tryParse(t);
  return null;
}

/// Rangkaian token angka terbaik: yang nilainya paling besar. Kalimat seperti
/// "beli 2 kopi 50 ribu" memuat dua rangkaian; nominalnya hampir selalu yang
/// terbesar.
_Span? _bestNumberSpan(List<String> tokens) {
  _Span? best;
  var i = 0;
  while (i < tokens.length) {
    if (!_isNumberToken(tokens[i])) {
      i++;
      continue;
    }
    var j = i;
    while (j < tokens.length && _isNumberToken(tokens[j])) {
      j++;
    }
    final span = _evaluate(tokens, i, j);
    if (span != null && (best == null || span.value > best.value)) best = span;
    i = j;
  }
  return best;
}

_Span? _evaluate(List<String> tokens, int start, int end) {
  var total = 0.0;
  var cur = 0.0;
  var lastUnit = 0.0; // satuan terakhir yang ditambahkan ke [cur]
  var hasUnit = false;
  var any = false;

  for (var k = start; k < end; k++) {
    final t = tokens[k];
    final digits = _digitValue(t);
    if (digits != null) {
      cur += digits;
      lastUnit = digits;
      any = true;
    } else if (_slang.containsKey(t)) {
      total += _slang[t]!;
      hasUnit = true;
      any = true;
    } else if (t == 'setengah') {
      cur += 0.5;
      lastUnit = 0;
      any = true;
    } else if (_fixed.containsKey(t)) {
      cur += _fixed[t]!;
      lastUnit = 0;
      any = true;
      // "seribu"/"sejuta"/"semiliar": tutup kelompok seperti kata satuan.
      if (_fixed[t]! >= 1000) {
        total += cur;
        cur = 0;
        hasUnit = true;
      }
    } else if (_units.containsKey(t)) {
      cur += _units[t]!;
      lastUnit = _units[t]!;
      any = true;
    } else if (t == 'puluh') {
      final base = lastUnit == 0 ? (cur == 0 ? 1 : cur) : lastUnit;
      cur = cur - lastUnit + base * 10;
      lastUnit = 0;
    } else if (t == 'ratus') {
      final base = lastUnit == 0 ? (cur == 0 ? 1 : cur) : lastUnit;
      cur = cur - lastUnit + base * 100;
      lastUnit = 0;
    } else if (t == 'belas') {
      cur += 10;
      lastUnit = 0;
    } else if (_scale.containsKey(t)) {
      final group = cur == 0 ? 1.0 : cur;
      total += group * _scale[t]!;
      cur = 0;
      lastUnit = 0;
      hasUnit = true;
      any = true;
    }
  }
  if (!any) return null;
  final value = (total + cur).round();
  if (value <= 0) return null;
  return _Span(start, end, value, hasUnit);
}

// ---------------------------------------------------------------- jenis

const _incomeCues = {
  'gaji',
  'gajian',
  'bonus',
  'thr',
  'terima',
  'menerima',
  'diterima',
  'dapat',
  'dapet',
  'dikasih',
  'pemasukan',
  'untung',
  'jual',
  'menjual',
  'jualan',
  'terjual',
  'hadiah',
  'cashback',
  'refund',
  'komisi',
  'honor',
};

const _fillers = {
  'tadi',
  'barusan',
  'saya',
  'aku',
  'sebesar',
  'seharga',
  'senilai',
  'sejumlah',
  'total',
  'sebanyak',
  'hari',
  'ini',
  'tolong',
  'catat',
  'sekitar',
  'rupiah',
  'dan',
};

/// Kata penghubung/kata kerja umum: tidak membedakan kategori.
const _stop = {
  'beli',
  'membeli',
  'bayar',
  'membayar',
  'buat',
  'untuk',
  'yang',
  'dari',
  'pada',
  'sama',
  'pakai',
  'isi',
  'kali',
  'dengan',
};

// ------------------------------------------------------------- kategori

/// Kata kunci umum -> potongan nama kategori bawaan. Dicocokkan ke nama
/// kategori milik pengguna (bukan ID), jadi ikut bekerja di buku kas bisnis.
const _keywordToCategory = <String, List<String>>{
  'makan': ['makan'],
  'minum': ['makan'],
  'kopi': ['makan'],
  'bakso': ['makan'],
  'nasi': ['makan'],
  'sarapan': ['makan'],
  'jajan': ['makan'],
  'bensin': ['transport'],
  'parkir': ['transport'],
  'tol': ['transport'],
  'ojek': ['transport'],
  'grab': ['transport'],
  'gojek': ['transport'],
  'angkot': ['transport'],
  'bus': ['transport'],
  'kereta': ['transport'],
  'listrik': ['tagihan', 'utilitas'],
  'pln': ['tagihan', 'utilitas'],
  'air': ['tagihan', 'utilitas'],
  'pdam': ['tagihan', 'utilitas'],
  'pulsa': ['tagihan', 'utilitas'],
  'internet': ['tagihan', 'utilitas'],
  'wifi': ['tagihan', 'utilitas'],
  'token': ['tagihan', 'utilitas'],
  'belanja': ['belanja'],
  'baju': ['belanja'],
  'sepatu': ['belanja'],
  'sewa': ['tempat tinggal', 'sewa'],
  'kontrakan': ['tempat tinggal', 'sewa'],
  'kos': ['tempat tinggal', 'sewa'],
  'dokter': ['kesehatan'],
  'obat': ['kesehatan'],
  'apotek': ['kesehatan'],
  'sekolah': ['pendidikan'],
  'kuliah': ['pendidikan'],
  'spp': ['pendidikan'],
  'les': ['pendidikan'],
  'nonton': ['hiburan'],
  'bioskop': ['hiburan'],
  'game': ['hiburan'],
  'sedekah': ['sedekah'],
  'donasi': ['sedekah'],
  'zakat': ['sedekah'],
  'cicilan': ['cicilan'],
  'gaji': ['gaji'],
  'gajian': ['gaji'],
  'bonus': ['bonus'],
  'thr': ['bonus'],
};

/// Urutan: riwayat pengguna -> kata kunci umum -> kemiripan nama kategori.
String? suggestCategory(
  List<String> words, {
  required List<VoiceCategory> categories,
  List<VoiceHistoryItem> history = const [],
}) {
  if (categories.isEmpty) return null;
  final ids = {for (final c in categories) c.id};
  final significant = [
    for (final w in words)
      if (w.length >= 3 &&
          !_stop.contains(w) &&
          _digitValue(w) == null &&
          !_isNumberToken(w))
        w,
  ];
  if (significant.isEmpty) return null;

  // 1. Riwayat: catatan lama yang memuat kata yang sama; yang terbaru menang
  //    (history diurut dari yang terbaru). Hanya kategori yang masih tersedia.
  for (final h in history) {
    if (!ids.contains(h.categoryId)) continue;
    final noteWords = _normalize(h.note).split(' ').toSet();
    if (significant.any(noteWords.contains)) return h.categoryId;
  }

  // 2. Kata kunci umum.
  for (final w in significant) {
    final fragments = _keywordToCategory[w];
    if (fragments == null) continue;
    for (final frag in fragments) {
      for (final c in categories) {
        if (c.name.toLowerCase().contains(frag)) return c.id;
      }
    }
  }

  // 3. Nama kategori mengandung/diawali kata yang diucapkan (min. 4 huruf).
  for (final w in significant) {
    if (w.length < 4) continue;
    for (final c in categories) {
      final name = c.name.toLowerCase();
      final nameWords = name.split(RegExp(r'[^a-z0-9]+'));
      if (nameWords.any(
        (n) => n.length >= 4 && (n.startsWith(w) || w.startsWith(n)),
      )) {
        return c.id;
      }
    }
  }
  return null;
}
