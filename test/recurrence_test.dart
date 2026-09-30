import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('occurrenceAt', () {
    test('mingguan menambah 7 hari, melewati batas bulan dan tahun', () {
      final s = d(2026, 12, 25);
      expect(occurrenceAt(s, Frequency.weekly, 0), s);
      expect(occurrenceAt(s, Frequency.weekly, 1), d(2027, 1, 1));
      expect(occurrenceAt(s, Frequency.weekly, 2), d(2027, 1, 8));
    });

    test('bulanan tanggal 31 dijepit ke akhir bulan lalu kembali ke 31', () {
      final s = d(2026, 1, 31);
      expect(occurrenceAt(s, Frequency.monthly, 1), d(2026, 2, 28));
      // Dihitung dari jangkar, bukan dari 28 Feb: tidak ada drift.
      expect(occurrenceAt(s, Frequency.monthly, 2), d(2026, 3, 31));
      expect(occurrenceAt(s, Frequency.monthly, 3), d(2026, 4, 30));
      expect(occurrenceAt(s, Frequency.monthly, 12), d(2027, 1, 31));
    });

    test('bulanan tahun kabisat: 31 Jan -> 29 Feb 2028', () {
      expect(
        occurrenceAt(d(2028, 1, 31), Frequency.monthly, 1),
        d(2028, 2, 29),
      );
    });

    test('bulanan melewati pergantian tahun', () {
      final s = d(2026, 11, 15);
      expect(occurrenceAt(s, Frequency.monthly, 2), d(2027, 1, 15));
      expect(occurrenceAt(s, Frequency.monthly, 14), d(2028, 1, 15));
    });

    test('tahunan 29 Feb menjadi 28 Feb di tahun bukan kabisat', () {
      final s = d(2028, 2, 29);
      expect(occurrenceAt(s, Frequency.yearly, 1), d(2029, 2, 28));
      expect(occurrenceAt(s, Frequency.yearly, 4), d(2032, 2, 29));
    });

    test('jam pada tanggal mulai diabaikan', () {
      expect(
        occurrenceAt(DateTime(2026, 5, 10, 23, 59), Frequency.monthly, 1),
        d(2026, 6, 10),
      );
    });

    test('sekali: selalu tanggal mulai, k diabaikan', () {
      final s = d(2026, 3, 15);
      expect(occurrenceAt(s, Frequency.once, 0), s);
      expect(occurrenceAt(s, Frequency.once, 1), s);
      expect(occurrenceAt(s, Frequency.once, 5), s);
    });
  });

  test('firstIndexOnOrAfter', () {
    final s = d(2026, 1, 10);
    expect(firstIndexOnOrAfter(s, Frequency.monthly, d(2025, 1, 1)), 0);
    expect(firstIndexOnOrAfter(s, Frequency.monthly, d(2026, 1, 10)), 0);
    expect(firstIndexOnOrAfter(s, Frequency.monthly, d(2026, 1, 11)), 1);
    expect(firstIndexOnOrAfter(s, Frequency.monthly, d(2026, 3, 10)), 2);
  });

  test(
    'firstIndexOnOrAfter sekali selalu 0 (occurrenceAt konstan, jangan hang)',
    () {
      final s = d(2026, 1, 10);
      expect(firstIndexOnOrAfter(s, Frequency.once, d(2025, 1, 1)), 0);
      expect(firstIndexOnOrAfter(s, Frequency.once, d(2030, 1, 1)), 0);
    },
  );

  test('frequencyLabel dan scheduleDescription untuk Sekali', () {
    expect(frequencyLabel(Frequency.once), 'Sekali');
    expect(
      scheduleDescription(Frequency.once, d(2026, 3, 15)),
      'Sekali, 15 Maret 2026',
    );
  });

  group('occurrenceDatesInRange', () {
    final from = d(2026, 3, 1);
    final to = d(2026, 4, 1);

    test(
      'mingguan: mengembalikan daftar tanggal yang benar, bukan cuma total',
      () {
        final dates = occurrenceDatesInRange(
          startDate: d(2026, 3, 5),
          frequency: Frequency.weekly,
          nextIndex: 0,
          endDate: null,
          from: from,
          to: to,
        );
        expect(dates, [
          d(2026, 3, 5),
          d(2026, 3, 12),
          d(2026, 3, 19),
          d(2026, 3, 26),
        ]);
      },
    );

    test('rentang yang tidak memuat kejadian apa pun -> daftar kosong', () {
      final dates = occurrenceDatesInRange(
        startDate: d(2026, 1, 10),
        frequency: Frequency.monthly,
        nextIndex: 0,
        endDate: d(2026, 2, 10),
        from: from,
        to: to,
      );
      expect(dates, isEmpty);
    });

    test('Sekali: tepat satu tanggal saat belum dieksekusi', () {
      final dates = occurrenceDatesInRange(
        startDate: d(2026, 3, 15),
        frequency: Frequency.once,
        nextIndex: 0,
        endDate: null,
        from: from,
        to: to,
      );
      expect(dates, [d(2026, 3, 15)]);
    });

    test('Sekali: daftar kosong kalau sudah dieksekusi (nextIndex > 0)', () {
      final dates = occurrenceDatesInRange(
        startDate: d(2026, 3, 15),
        frequency: Frequency.once,
        nextIndex: 1,
        endDate: null,
        from: from,
        to: to,
      );
      expect(dates, isEmpty);
    });
  });

  group('occurrencesTotalInRange', () {
    final from = d(2026, 3, 1);
    final to = d(2026, 4, 1); // eksklusif — rentang Maret 2026

    test('bulanan: 1 kejadian dalam rentang dihitung sekali', () {
      final total = occurrencesTotalInRange(
        startDate: d(2026, 3, 10),
        frequency: Frequency.monthly,
        nextIndex: 0,
        endDate: null,
        from: from,
        to: to,
        amount: 50000,
      );
      expect(total, 50000);
    });

    test('bulanan: endDate sebelum rentang -> tidak ada kejadian, total 0', () {
      final total = occurrencesTotalInRange(
        startDate: d(2026, 1, 10),
        frequency: Frequency.monthly,
        nextIndex: 0,
        endDate: d(2026, 2, 10),
        from: from,
        to: to,
        amount: 50000,
      );
      expect(total, 0);
    });

    test('mingguan: beberapa kejadian dalam sebulan dijumlahkan semua', () {
      final total = occurrencesTotalInRange(
        startDate: d(2026, 3, 5), // 5, 12, 19, 26 Maret -> 4 kejadian
        frequency: Frequency.weekly,
        nextIndex: 0,
        endDate: null,
        from: from,
        to: to,
        amount: 10000,
      );
      expect(total, 40000);
    });

    test('endDate memotong di tengah rentang lebar: kejadian setelahnya '
        'tidak ikut dihitung', () {
      final total = occurrencesTotalInRange(
        startDate: d(2026, 1, 5),
        frequency: Frequency.monthly,
        nextIndex: 0,
        endDate: d(2026, 3, 5), // kejadian ke-3 (Jan/Feb/Mar), bukan April+
        from: d(2026, 1, 1),
        to: d(2026, 5, 1),
        amount: 100000,
      );
      expect(total, 300000); // Jan + Feb + Mar, April dst terpotong endDate
    });

    test(
      'Sekali: dalam rentang & belum dieksekusi (nextIndex 0) dihitung TEPAT '
      'sekali (regresi: bukan berkali-kali seperti loop biasa)',
      () {
        final total = occurrencesTotalInRange(
          startDate: d(2026, 3, 15),
          frequency: Frequency.once,
          nextIndex: 0,
          endDate: null,
          from: from,
          to: to,
          amount: 3500000,
        );
        expect(total, 3500000);
      },
    );

    test('Sekali: sudah dieksekusi (nextIndex > 0) tidak dihitung walau '
        'tanggalnya masih dalam rentang', () {
      final total = occurrencesTotalInRange(
        startDate: d(2026, 3, 15),
        frequency: Frequency.once,
        nextIndex: 1,
        endDate: null,
        from: from,
        to: to,
        amount: 3500000,
      );
      expect(total, 0);
    });
  });
}
