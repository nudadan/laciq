import 'package:dompet_pintar/data/database.dart' show TxType;
import 'package:dompet_pintar/features/voice/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 4, 14, 30);

VoiceEntry _p(
  String s, {
  List<VoiceCategory> categories = const [],
  List<VoiceHistoryItem> history = const [],
}) => parseVoiceEntry(s, now: _now, categories: categories, history: history);

const _cats = [
  VoiceCategory(id: 'makan', name: 'Makanan & Minuman'),
  VoiceCategory(id: 'transport', name: 'Transportasi'),
  VoiceCategory(id: 'belanja', name: 'Belanja'),
  VoiceCategory(id: 'tagihan', name: 'Tagihan & Utilitas'),
  VoiceCategory(id: 'kesehatan', name: 'Kesehatan'),
  VoiceCategory(id: 'gaji', name: 'Gaji'),
];

void main() {
  group('nominal', () {
    final cases = <String, int>{
      'makan siang dua puluh lima ribu': 25000,
      'makan siang 25 ribu': 25000,
      'makan siang 25rb': 25000,
      'makan siang 25k': 25000,
      'makan siang Rp25.000': 25000,
      'makan siang rp. 25.000': 25000,
      'makan siang 25000': 25000,
      'makan siang dua puluh lima ribu rupiah': 25000,
      'bensin lima puluh ribu': 50000,
      'sepuluh ribu': 10000,
      'sebelas ribu': 11000,
      'dua belas ribu': 12000,
      'lima belas ribu': 15000,
      'seratus ribu': 100000,
      'seratus lima puluh ribu': 150000,
      'dua ratus lima puluh ribu': 250000,
      'seribu': 1000,
      'seribu lima ratus': 1500,
      'tiga ribu lima ratus': 3500,
      'dua ratus ribu lima ratus': 200500,
      'sejuta': 1000000,
      'satu juta': 1000000,
      'gaji lima juta': 5000000,
      'dua juta lima ratus ribu': 2500000,
      'setengah juta': 500000,
      'satu setengah juta': 1500000,
      'dua setengah juta': 2500000,
      'servis motor 1,5 juta': 1500000,
      'servis motor 1.5jt': 1500000,
      'servis motor 2 juta 500 ribu': 2500000,
      'bayar kontrakan 1.200.000': 1200000,
      'sewa tiga juta lima ratus ribu': 3500000,
      'parkir ceban': 10000,
      'jajan goceng': 5000,
      'kopi gopek': 500,
      'sembilan puluh sembilan ribu sembilan ratus': 99900,
      'dua miliar': 2000000000,
      'Makan siang, dua puluh lima ribu.': 25000,
    };
    cases.forEach((spoken, expected) {
      test('"$spoken" -> $expected', () {
        final e = _p(spoken);
        expect(e.amount, expected);
        expect(e.assumedThousands, isFalse);
      });
    });

    test('beberapa angka: yang terbesar dianggap nominal', () {
      expect(_p('beli 2 kopi 50 ribu').amount, 50000);
      expect(_p('tiga kali makan 75 ribu').amount, 75000);
      expect(_p('beli 2 kopi 50 ribu').note, 'Beli 2 kopi');
    });

    test('tanpa satuan dan kecil dianggap ribuan, dengan penanda', () {
      final e = _p('makan siang 25');
      expect(e.amount, 25000);
      expect(e.assumedThousands, isTrue);
      final w = _p('makan siang dua puluh lima');
      expect(w.amount, 25000);
      expect(w.assumedThousands, isTrue);
    });

    test('tanpa angka: nominal kosong', () {
      final e = _p('makan siang di warteg');
      expect(e.amount, isNull);
      expect(e.note, 'Makan siang di warteg');
    });

    test('kalimat kosong tidak melempar galat', () {
      final e = _p('   ');
      expect(e.amount, isNull);
      expect(e.note, '');
      expect(e.type, TxType.expense);
    });
  });

  group('jenis', () {
    test('pengeluaran adalah bawaan', () {
      expect(_p('beli bensin lima puluh ribu').type, TxType.expense);
    });

    test('kata pemasukan dikenali', () {
      for (final s in [
        'gajian lima juta',
        'terima gaji 5 juta',
        'dapat bonus dua ratus ribu',
        'jual hp satu juta',
        'cashback 10 ribu',
      ]) {
        expect(_p(s).type, TxType.income, reason: s);
      }
    });

    test('"masuk tol" tetap pengeluaran', () {
      expect(_p('masuk tol dua puluh ribu').type, TxType.expense);
    });
  });

  group('tanggal', () {
    test('bawaan hari ini; jam dibuang', () {
      expect(_p('kopi 20 ribu').date, DateTime(2026, 10, 4));
    });

    test('kemarin, kemarin lusa, dan N hari lalu', () {
      expect(_p('kemarin makan 20 ribu').date, DateTime(2026, 10, 3));
      expect(_p('makan 20 ribu kemarin').date, DateTime(2026, 10, 3));
      expect(_p('kemarin lusa makan 20 ribu').date, DateTime(2026, 10, 2));
      expect(_p('makan 20 ribu 3 hari lalu').date, DateTime(2026, 10, 1));
      expect(
        _p('makan dua puluh ribu tiga hari yang lalu').date,
        DateTime(2026, 10, 1),
      );
    });

    test('lintas bulan dan penanda tanggal dibuang dari catatan', () {
      final e = parseVoiceEntry(
        'kemarin makan 20 ribu',
        now: DateTime(2026, 11, 1),
      );
      expect(e.date, DateTime(2026, 10, 31));
      expect(e.note, 'Makan');
      // "2 hari lalu" bukan nominal.
      final f = _p('makan 20 ribu 2 hari lalu');
      expect(f.amount, 20000);
      expect(f.note, 'Makan');
    });
  });

  group('catatan', () {
    test('angka dan kata pengisi dibuang, huruf pertama kapital', () {
      expect(_p('tadi makan siang dua puluh lima ribu').note, 'Makan siang');
      expect(_p('beli bensin seharga 50 ribu').note, 'Beli bensin');
      expect(_p('catat gaji bulan ini lima juta').note, 'Gaji bulan');
    });
  });

  group('kategori', () {
    test('kata kunci umum -> nama kategori pengguna', () {
      String? cat(String s) => _p(s, categories: _cats).categoryId;
      expect(cat('makan siang 25 ribu'), 'makan');
      expect(cat('kopi 20 ribu'), 'makan');
      expect(cat('beli bensin 50 ribu'), 'transport');
      expect(cat('parkir 5 ribu'), 'transport');
      expect(cat('bayar listrik 350 ribu'), 'tagihan');
      expect(cat('beli pulsa 50 ribu'), 'tagihan');
      expect(cat('obat batuk 30 ribu'), 'kesehatan');
      expect(cat('gajian 5 juta'), 'gaji');
      expect(cat('beli baju 150 ribu'), 'belanja');
    });

    test('"beli" saja tidak menentukan kategori', () {
      expect(
        _p('beli bensin 50 ribu', categories: _cats).categoryId,
        'transport',
      );
      expect(_p('beli sesuatu 50 ribu', categories: _cats).categoryId, isNull);
    });

    test('riwayat pengguna mengalahkan kata kunci umum', () {
      final e = _p(
        'kopi kenangan 30 ribu',
        categories: _cats,
        history: const [
          VoiceHistoryItem(note: 'Kopi Kenangan', categoryId: 'belanja'),
        ],
      );
      expect(e.categoryId, 'belanja');
    });

    test('riwayat dengan kategori yang sudah tidak ada diabaikan', () {
      final e = _p(
        'kopi 30 ribu',
        categories: _cats,
        history: const [VoiceHistoryItem(note: 'kopi', categoryId: 'hilang')],
      );
      expect(e.categoryId, 'makan');
    });

    test('kemiripan nama kategori buatan pengguna', () {
      final e = _p(
        'servis motor 200 ribu',
        categories: const [
          VoiceCategory(id: 'servis', name: 'Servis Kendaraan'),
          VoiceCategory(id: 'x', name: 'Lain-lain'),
        ],
      );
      expect(e.categoryId, 'servis');
    });

    test('tanpa kecocokan: null; tanpa kategori: null', () {
      expect(_p('xyz abc 10 ribu', categories: _cats).categoryId, isNull);
      expect(_p('makan 10 ribu').categoryId, isNull);
    });
  });
}
