import 'package:dompet_pintar/data/cash_flow.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  final from = d(2026, 3, 1);
  final to = d(2026, 4, 1); // eksklusif — rentang Maret 2026

  AgendaReminder agenda({
    required DateTime startDate,
    int? estimatedAmount,
    bool active = true,
    Frequency frequency = Frequency.monthly,
    int nextIndex = 0,
    DateTime? endDate,
  }) => AgendaReminder(
    id: 'a',
    title: 'Agenda',
    frequency: frequency,
    startDate: startDate,
    nextIndex: nextIndex,
    endDate: endDate,
    reminderDaysBefore: 1,
    active: active,
    estimatedAmount: estimatedAmount,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  RuleView rule({
    required TxType type,
    required int amount,
    required DateTime startDate,
    Frequency frequency = Frequency.monthly,
    int nextIndex = 0,
    DateTime? endDate,
    bool active = true,
  }) => RuleView(
    rule: RecurringRule(
      id: 'r',
      type: type,
      amount: amount,
      accountId: 'acc',
      categoryId: null,
      transferToAccountId: null,
      note: null,
      frequency: frequency,
      startDate: startDate,
      nextIndex: nextIndex,
      endDate: endDate,
      active: active,
      reminderEnabled: false,
      reminderDaysBefore: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    account: Account(
      id: 'acc',
      name: 'Tunai',
      kind: AccountKind.cash,
      initialBalance: 0,
      archived: false,
      updatedAt: DateTime(2026),
    ),
  );

  test(
    'semua kejadian bersih positif: tidak pernah kurang, minBalance di awal',
    () {
      // Pemasukan lebih dulu (tanggal 5), baru pengeluaran (tanggal 10) —
      // saldo tidak pernah turun di bawah saldo awal.
      final result = simulateDailyBalance(
        startingBalance: 1000000,
        from: from,
        to: to,
        agenda: [agenda(startDate: d(2026, 3, 10), estimatedAmount: 100000)],
        recurringRules: [
          rule(type: TxType.income, amount: 5000000, startDate: d(2026, 3, 5)),
        ],
      );
      expect(result.hasShortfall, isFalse);
      expect(result.startingBalance, 1000000);
      expect(
        result.minBalance,
        1000000,
      ); // titik terendah: sebelum ada kejadian apa pun
      expect(result.minBalanceDate, from);
      expect(result.endingBalance, 1000000 - 100000 + 5000000);
    },
  );

  test('pengeluaran besar sebelum ada pemasukan: saldo minus persis di tanggal pemicunya', () {
    final result = simulateDailyBalance(
      startingBalance: 500000,
      from: from,
      to: to,
      agenda: [agenda(startDate: d(2026, 3, 10), estimatedAmount: 800000)],
      recurringRules: [
        rule(type: TxType.income, amount: 5000000, startDate: d(2026, 3, 25)),
      ],
    );
    expect(result.hasShortfall, isTrue);
    expect(result.minBalanceDate, d(2026, 3, 10));
    expect(result.minBalance, 500000 - 800000);
    // Sesudah gajian tanggal 25, saldo akhir kembali positif.
    expect(result.endingBalance, 500000 - 800000 + 5000000);
  });

  test(
    'pemasukan datang SEBELUM pengeluaran besar: saldo tetap cukup walau '
    'tanpa pemasukan itu akan minus (urutan tanggal benar-benar dipakai)',
    () {
      final result = simulateDailyBalance(
        startingBalance: 500000,
        from: from,
        to: to,
        agenda: [agenda(startDate: d(2026, 3, 28), estimatedAmount: 800000)],
        recurringRules: [
          rule(type: TxType.income, amount: 5000000, startDate: d(2026, 3, 25)),
        ],
      );
      expect(result.hasShortfall, isFalse);
      expect(
        result.minBalance,
        500000,
      ); // sebelum tanggal 25, belum ada kejadian apa pun
    },
  );

  test('beberapa kejadian di tanggal yang sama digabung jadi satu titik', () {
    final result = simulateDailyBalance(
      startingBalance: 1000000,
      from: from,
      to: to,
      agenda: [agenda(startDate: d(2026, 3, 15), estimatedAmount: 300000)],
      recurringRules: [
        rule(type: TxType.expense, amount: 400000, startDate: d(2026, 3, 15)),
      ],
    );
    expect(result.minBalanceDate, d(2026, 3, 15));
    expect(result.minBalance, 1000000 - 300000 - 400000);
  });

  test('transfer tidak memengaruhi simulasi sama sekali', () {
    final result = simulateDailyBalance(
      startingBalance: 1000000,
      from: from,
      to: to,
      agenda: const [],
      recurringRules: [
        rule(type: TxType.transfer, amount: 900000, startDate: d(2026, 3, 10)),
      ],
    );
    expect(result.hasShortfall, isFalse);
    expect(result.minBalance, 1000000);
    expect(result.endingBalance, 1000000);
  });

  test('agenda tanpa estimatedAmount: kontribusi 0 ke simulasi', () {
    final result = simulateDailyBalance(
      startingBalance: 1000000,
      from: from,
      to: to,
      agenda: [agenda(startDate: d(2026, 3, 10))],
      recurringRules: const [],
    );
    expect(result.endingBalance, 1000000);
  });

  test('Sekali: kejadian yang sudah dieksekusi (nextIndex > 0) tidak ikut simulasi', () {
    final result = simulateDailyBalance(
      startingBalance: 1000000,
      from: from,
      to: to,
      agenda: [
        agenda(
          startDate: d(2026, 3, 15),
          estimatedAmount: 3500000,
          frequency: Frequency.once,
          nextIndex: 1,
        ),
      ],
      recurringRules: const [],
    );
    expect(result.endingBalance, 1000000);
    expect(result.hasShortfall, isFalse);
  });
}
