import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/features/recurring/recurring_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Account _account() => Account(
  id: 'a1',
  name: 'Tunai',
  kind: AccountKind.cash,
  initialBalance: 0,
  archived: false,
  updatedAt: DateTime(2026),
);

RecurringRule _rule({
  bool active = true,
  bool reminderEnabled = true,
  int reminderDaysBefore = 1,
  DateTime? endDate,
}) => RecurringRule(
  id: 'r1',
  type: TxType.expense,
  amount: 500000,
  accountId: 'a1',
  frequency: Frequency.monthly,
  startDate: DateTime(2026, 1, 10),
  nextIndex: 0,
  endDate: endDate,
  active: active,
  reminderEnabled: reminderEnabled,
  reminderDaysBefore: reminderDaysBefore,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('aturan aktif dengan reminder on dan jatuh tempo mendatang '
      'dijadwalkan', () async {
    final sender = FakeNotificationSender();
    final service = RecurringReminderService(sender);
    // Jatuh tempo (index 0) tanggal 10 bulan berjalan; skenario ini memakai
    // startDate jauh di masa depan supaya nextDue pasti setelah `now`.
    final future = DateTime.now().add(const Duration(days: 10));
    final rule = RecurringRule(
      id: 'r1',
      type: TxType.expense,
      amount: 500000,
      accountId: 'a1',
      frequency: Frequency.monthly,
      startDate: DateTime(future.year, future.month, future.day),
      nextIndex: 0,
      endDate: null,
      active: true,
      reminderEnabled: true,
      reminderDaysBefore: 2,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await service.reschedule([RuleView(rule: rule, account: _account())]);

    expect(sender.scheduled, hasLength(1));
    final s = sender.scheduled.single;
    expect(s.at, DateTime(future.year, future.month, future.day - 2, 8));
    expect(s.title, 'Pengingat transaksi berulang');
  });

  test('aturan dijeda dibatalkan, bukan dijadwalkan', () async {
    final sender = FakeNotificationSender();
    final service = RecurringReminderService(sender);

    await service.reschedule([
      RuleView(rule: _rule(active: false), account: _account()),
    ]);

    expect(sender.scheduled, isEmpty);
    expect(sender.cancelled, isNotEmpty);
  });

  test('reminder dimatikan pada aturan dibatalkan', () async {
    final sender = FakeNotificationSender();
    final service = RecurringReminderService(sender);

    await service.reschedule([
      RuleView(rule: _rule(reminderEnabled: false), account: _account()),
    ]);

    expect(sender.scheduled, isEmpty);
  });

  test('aturan sudah selesai (lewat endDate) dibatalkan', () async {
    final sender = FakeNotificationSender();
    final service = RecurringReminderService(sender);

    await service.reschedule([
      RuleView(
        rule: _rule(endDate: DateTime(2020, 1, 1)),
        account: _account(),
      ),
    ]);

    expect(sender.scheduled, isEmpty);
  });

  test('waktu pengingat sudah lewat (jatuh tempo besok, H-7) dibatalkan, '
      'bukan dijadwalkan mundur', () async {
    final sender = FakeNotificationSender();
    final service = RecurringReminderService(sender);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final rule = RecurringRule(
      id: 'r1',
      type: TxType.expense,
      amount: 100000,
      accountId: 'a1',
      frequency: Frequency.monthly,
      startDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
      nextIndex: 0,
      endDate: null,
      active: true,
      reminderEnabled: true,
      reminderDaysBefore: 7,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await service.reschedule([RuleView(rule: rule, account: _account())]);

    expect(sender.scheduled, isEmpty);
    expect(sender.cancelled, isNotEmpty);
  });

  test('cancelFor membatalkan pengingat yang sudah dijadwalkan sebelumnya '
      '(mis. saat aturan dihapus)', () async {
    final sender = FakeNotificationSender();
    final service = RecurringReminderService(sender);
    final future = DateTime.now().add(const Duration(days: 10));
    final rule = RecurringRule(
      id: 'r-to-delete',
      type: TxType.expense,
      amount: 100000,
      accountId: 'a1',
      frequency: Frequency.monthly,
      startDate: DateTime(future.year, future.month, future.day),
      nextIndex: 0,
      endDate: null,
      active: true,
      reminderEnabled: true,
      reminderDaysBefore: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await service.reschedule([RuleView(rule: rule, account: _account())]);
    expect(sender.scheduled, hasLength(1));

    // Baris dihapus dari database -> tidak lagi muncul di reschedule(), jadi
    // pembatalan harus eksplisit lewat cancelFor, bukan reschedule() lagi.
    await service.cancelFor('r-to-delete');

    expect(sender.scheduled, isEmpty);
  });
}
