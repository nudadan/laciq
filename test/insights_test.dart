import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/insights.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _now = DateTime(2026, 9, 1);
final _acc = Account(
  id: 'a',
  name: 'Tunai',
  kind: AccountKind.cash,
  ledgerId: kMainLedgerId,
  initialBalance: 0,
  archived: false,
  updatedAt: _now,
);

Category _cat(String id, String name, {int color = 0xFF112233}) => Category(
  id: id,
  name: name,
  type: TxType.expense,
  icon: 'food',
  color: color,
  sortOrder: 0,
  archived: false,
  ledgerId: kMainLedgerId,
  updatedAt: _now,
);

final _makan = _cat('makan', 'Makan');
final _transport = _cat('transport', 'Transport');

var _seq = 0;
TxView _tx(
  TxType type,
  int amount,
  DateTime date, {
  Category? category,
  String? note,
}) => TxView(
  tx: TxEntry(
    id: 't${_seq++}',
    type: type,
    amount: amount,
    accountId: 'a',
    categoryId: category?.id,
    date: date,
    note: note,
    createdAt: _now,
    updatedAt: _now,
  ),
  account: _acc,
  category: category,
);

TxView _out(int amount, DateTime date, {Category? category, String? note}) =>
    _tx(TxType.expense, amount, date, category: category, note: note);
TxView _in(int amount, DateTime date) => _tx(TxType.income, amount, date);

BudgetProgress _budget(Category c, int spent, int? limit) =>
    BudgetProgress(category: c, spent: spent, budget: limit);

MonthlyReport _report({
  required DateTime today,
  List<TxView> current = const [],
  List<TxView> previous = const [],
  List<BudgetProgress> budgets = const [],
  DateTime? month,
}) => buildMonthlyReport(
  month: month ?? DateTime(today.year, today.month),
  current: current,
  previous: previous,
  budgets: budgets,
  today: today,
);

List<String> _texts(MonthlyReport r) => [for (final i in r.insights) i.text];

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('angka dasar', () {
    test('transfer tidak dihitung; kosong menghasilkan laporan kosong', () {
      final empty = _report(today: DateTime(2026, 10, 20));
      expect(empty.isEmpty, isTrue);
      expect(empty.insights, isEmpty);

      final r = _report(
        today: DateTime(2026, 10, 20),
        current: [
          _in(5000000, DateTime(2026, 10, 1)),
          _out(200000, DateTime(2026, 10, 2), category: _makan),
          _tx(TxType.transfer, 999999, DateTime(2026, 10, 3)),
        ],
      );
      expect(r.income, 5000000);
      expect(r.expense, 200000);
      expect(r.net, 4800000);
      expect(r.transactionCount, 2);
      expect(r.savingsRate, closeTo(0.96, 1e-9));
    });

    test('kategori diurutkan terbesar dulu dengan porsi', () {
      final r = _report(
        today: DateTime(2026, 10, 31),
        current: [
          _out(100000, DateTime(2026, 10, 2), category: _transport),
          _out(300000, DateTime(2026, 10, 3), category: _makan),
          _out(100000, DateTime(2026, 10, 4), category: _makan),
        ],
      );
      expect(r.categories.map((c) => c.name), ['Makan', 'Transport']);
      expect(r.categories.first.total, 400000);
      expect(r.categories.first.share, closeTo(0.8, 1e-9));
    });

    test('tanpa kategori diberi nama "Tanpa kategori"', () {
      final r = _report(
        today: DateTime(2026, 10, 31),
        current: [_out(1000, DateTime(2026, 10, 2))],
      );
      expect(r.categories.single.name, 'Tanpa kategori');
    });
  });

  group('perbandingan', () {
    test('bulan berjalan dibanding bulan lalu sampai tanggal yang sama', () {
      final r = _report(
        today: DateTime(2026, 10, 10),
        current: [_out(500000, DateTime(2026, 10, 5), category: _makan)],
        previous: [
          _out(400000, DateTime(2026, 9, 5), category: _makan),
          // Setelah tanggal 10: tidak boleh ikut dibandingkan.
          _out(9000000, DateTime(2026, 9, 25), category: _makan),
        ],
      );
      expect(r.previousExpense, 400000);
      expect(r.comparisonLabel, 'periode yang sama bulan lalu');
      expect(
        _texts(
          r,
        ).any((t) => t.contains('naik 25%') && t.contains('periode yang sama')),
        isTrue,
      );
    });

    test('bulan yang sudah selesai dibanding seluruh bulan lalu', () {
      final r = _report(
        today: DateTime(2026, 11, 15),
        month: DateTime(2026, 10),
        current: [_out(300000, DateTime(2026, 10, 5), category: _makan)],
        previous: [
          _out(400000, DateTime(2026, 9, 5), category: _makan),
          _out(100000, DateTime(2026, 9, 25), category: _makan),
        ],
      );
      expect(r.previousExpense, 500000);
      expect(r.comparisonLabel, 'bulan lalu');
      expect(r.projectedExpense, isNull);
      expect(
        _texts(r).any((t) => t.contains('turun 40% dibanding bulan lalu')),
        isTrue,
      );
    });

    test('perubahan kecil dilaporkan stabil', () {
      final r = _report(
        today: DateTime(2026, 11, 15),
        month: DateTime(2026, 10),
        current: [_out(1050000, DateTime(2026, 10, 5), category: _makan)],
        previous: [_out(1000000, DateTime(2026, 9, 5), category: _makan)],
      );
      expect(_texts(r).any((t) => t.contains('relatif stabil')), isTrue);
    });

    test('kategori yang paling naik dan paling turun disorot', () {
      final r = _report(
        today: DateTime(2026, 11, 15),
        month: DateTime(2026, 10),
        current: [
          _out(600000, DateTime(2026, 10, 5), category: _makan),
          _out(100000, DateTime(2026, 10, 6), category: _transport),
        ],
        previous: [
          _out(300000, DateTime(2026, 9, 5), category: _makan),
          _out(400000, DateTime(2026, 9, 6), category: _transport),
        ],
      );
      final t = _texts(r);
      expect(
        t.any((x) => x.startsWith('Makan naik Rp') && x.contains('100%')),
        isTrue,
      );
      expect(t.any((x) => x.startsWith('Transport turun Rp')), isTrue);
    });

    test('perubahan kategori di bawah ambang tidak disorot', () {
      final r = _report(
        today: DateTime(2026, 11, 15),
        month: DateTime(2026, 10),
        current: [_out(130000, DateTime(2026, 10, 5), category: _makan)],
        previous: [_out(100000, DateTime(2026, 9, 5), category: _makan)],
      );
      expect(_texts(r).any((x) => x.startsWith('Makan naik')), isFalse);
    });
  });

  group('selisih, taksiran, dan anggaran', () {
    test('defisit memberi peringatan; sisa memberi kabar baik', () {
      final deficit = _report(
        today: DateTime(2026, 11, 15),
        month: DateTime(2026, 10),
        current: [
          _in(1000000, DateTime(2026, 10, 1)),
          _out(1500000, DateTime(2026, 10, 2), category: _makan),
        ],
      );
      final d = deficit.insights.first;
      expect(d.tone, InsightTone.warning);
      expect(d.text, contains('melebihi pemasukan'));

      final surplus = _report(
        today: DateTime(2026, 11, 15),
        month: DateTime(2026, 10),
        current: [
          _in(1000000, DateTime(2026, 10, 1)),
          _out(250000, DateTime(2026, 10, 2), category: _makan),
        ],
      );
      expect(surplus.insights.first.tone, InsightTone.good);
      expect(surplus.insights.first.text, contains('75%'));
    });

    test(
      'taksiran akhir bulan hanya setelah 7 hari dan hanya bulan berjalan',
      () {
        final early = _report(
          today: DateTime(2026, 10, 5),
          current: [_out(500000, DateTime(2026, 10, 2), category: _makan)],
        );
        expect(early.projectedExpense, isNull);

        final r = _report(
          today: DateTime(2026, 10, 10),
          current: [
            _in(2000000, DateTime(2026, 10, 1)),
            _out(1000000, DateTime(2026, 10, 2), category: _makan),
          ],
        );
        // 1.000.000 / 10 hari * 31 hari = 3.100.000 > pemasukan 2.000.000.
        expect(r.projectedExpense, 3100000);
        expect(
          _texts(r).any((t) => t.contains('melebihi pemasukan bulan ini')),
          isTrue,
        );
      },
    );

    test('anggaran terlampaui dan hampir habis', () {
      final r = _report(
        today: DateTime(2026, 10, 20),
        current: [_out(1, DateTime(2026, 10, 2), category: _makan)],
        budgets: [
          _budget(_makan, 600000, 500000),
          _budget(_transport, 450000, 500000),
          _budget(_cat('x', 'Tanpa batas'), 999999, null),
          _budget(_cat('y', 'Aman'), 100000, 500000),
        ],
      );
      final t = _texts(r);
      expect(
        t.any(
          (x) =>
              x.startsWith('Anggaran Makan terlampaui') && x.contains('120%'),
        ),
        isTrue,
      );
      expect(
        t.any((x) => x.startsWith('Anggaran Transport sudah 90% terpakai')),
        isTrue,
      );
      expect(t.any((x) => x.contains('Tanpa batas')), isFalse);
      expect(t.any((x) => x.contains('Aman')), isFalse);
    });

    test(
      'pengeluaran terbesar, hari tanpa pengeluaran, dan rata-rata harian',
      () {
        final r = _report(
          today: DateTime(2026, 10, 10),
          current: [
            _out(50000, DateTime(2026, 10, 2), category: _makan),
            _out(
              900000,
              DateTime(2026, 10, 3),
              category: _makan,
              note: 'Servis motor',
            ),
            _out(25000, DateTime(2026, 10, 4), category: _makan),
          ],
        );
        final t = _texts(r);
        expect(
          t.any((x) => x.contains('Servis motor') && x.contains('3 Okt')),
          isTrue,
        );
        // Hari 2,3,4 ada pengeluaran: 10 - 3 = 7 hari tanpa pengeluaran.
        expect(
          t.any((x) => x.startsWith('7 hari tanpa pengeluaran dari 10')),
          isTrue,
        );
        expect(t.last, contains('per hari'));
        expect(r.dailyAverage, 97500);
      },
    );

    test('jumlah sorotan dibatasi', () {
      final r = _report(
        today: DateTime(2026, 10, 20),
        current: [
          _in(100000, DateTime(2026, 10, 1)),
          for (var i = 0; i < 6; i++)
            _out(200000, DateTime(2026, 10, 2 + i), category: _makan),
        ],
        previous: [_out(100000, DateTime(2026, 9, 2), category: _makan)],
        budgets: [
          _budget(_makan, 1200000, 500000),
          _budget(_transport, 480000, 500000),
        ],
      );
      expect(r.insights.length, lessThanOrEqualTo(8));
    });
  });
}
