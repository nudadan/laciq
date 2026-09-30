import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/features/agenda/agenda_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

AgendaReminder _agenda({
  String id = 'g1',
  bool active = true,
  int reminderDaysBefore = 1,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? createdAt,
  String? note,
}) => AgendaReminder(
  id: id,
  title: 'Servis AC',
  note: note,
  frequency: Frequency.monthly,
  startDate: startDate ?? DateTime(2026, 1, 10),
  nextIndex: 0,
  endDate: endDate,
  reminderDaysBefore: reminderDaysBefore,
  active: active,
  createdAt: createdAt ?? DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('agenda aktif dengan jatuh tempo mendatang dijadwalkan', () async {
    final sender = FakeNotificationSender();
    final service = AgendaReminderService(sender);
    final future = DateTime.now().add(const Duration(days: 10));

    await service.reschedule([
      AgendaView(
        _agenda(
          startDate: DateTime(future.year, future.month, future.day),
          reminderDaysBefore: 2,
        ),
      ),
    ], premium: true);

    expect(sender.scheduled, hasLength(1));
    final s = sender.scheduled.single;
    expect(s.at, DateTime(future.year, future.month, future.day - 2, 8));
    expect(s.title, 'Servis AC');
  });

  test('catatan dipakai sebagai isi notifikasi kalau ada', () async {
    final sender = FakeNotificationSender();
    final service = AgendaReminderService(sender);
    final future = DateTime.now().add(const Duration(days: 10));

    await service.reschedule([
      AgendaView(
        _agenda(
          startDate: DateTime(future.year, future.month, future.day),
          note: 'Bengkel Pak Budi',
        ),
      ),
    ], premium: true);

    expect(sender.scheduled.single.body, 'Bengkel Pak Budi');
  });

  test('agenda dijeda dibatalkan', () async {
    final sender = FakeNotificationSender();
    final service = AgendaReminderService(sender);

    await service.reschedule([
      AgendaView(_agenda(active: false)),
    ], premium: true);

    expect(sender.scheduled, isEmpty);
    expect(sender.cancelled, isNotEmpty);
  });

  test('agenda sudah selesai (lewat endDate) dibatalkan', () async {
    final sender = FakeNotificationSender();
    final service = AgendaReminderService(sender);

    await service.reschedule([
      AgendaView(_agenda(endDate: DateTime(2020, 1, 1))),
    ], premium: true);

    expect(sender.scheduled, isEmpty);
  });

  test('cancelFor membatalkan pengingat yang sudah dijadwalkan sebelumnya '
      '(mis. saat agenda dihapus)', () async {
    final sender = FakeNotificationSender();
    final service = AgendaReminderService(sender);
    final future = DateTime.now().add(const Duration(days: 10));
    await service.reschedule([
      AgendaView(
        _agenda(startDate: DateTime(future.year, future.month, future.day)),
      ),
    ], premium: true);
    expect(sender.scheduled, hasLength(1));

    await service.cancelFor('g1');

    expect(sender.scheduled, isEmpty);
  });

  test('belum premium: hanya kFreeAgendaLimit item TERTUA (berdasar '
      'createdAt) yang dijadwalkan, sisanya dibatalkan', () async {
    final sender = FakeNotificationSender();
    final service = AgendaReminderService(sender);
    final future = DateTime.now().add(const Duration(days: 10));
    final due = DateTime(future.year, future.month, future.day);

    // 5 item, createdAt sengaja diacak urutannya untuk memastikan
    // pengurutan (bukan urutan daftar input) yang menentukan kelayakan.
    final items = [
      AgendaView(
        _agenda(id: 'newest', createdAt: DateTime(2026, 5), startDate: due),
      ),
      AgendaView(
        _agenda(id: 'oldest', createdAt: DateTime(2026, 1), startDate: due),
      ),
      AgendaView(
        _agenda(id: 'mid2', createdAt: DateTime(2026, 3), startDate: due),
      ),
      AgendaView(
        _agenda(id: 'mid1', createdAt: DateTime(2026, 2), startDate: due),
      ),
      AgendaView(
        _agenda(id: 'newer', createdAt: DateTime(2026, 4), startDate: due),
      ),
    ];

    await service.reschedule(items, premium: false);

    expect(kFreeAgendaLimit, 3);
    final scheduledIds = sender.scheduled.map((s) => s.id).toSet();
    final oldestThreeIds = {'oldest', 'mid1', 'mid2'}
        .map((id) => Object.hash('agenda_reminder', id).abs() % 2147483647)
        .toSet();
    expect(scheduledIds, oldestThreeIds);
    expect(sender.scheduled, hasLength(3));
    expect(sender.cancelled, hasLength(2)); // 'newer' dan 'newest'
  });

  test(
    'premium: semua item dijadwalkan meski lebih dari kFreeAgendaLimit',
    () async {
      final sender = FakeNotificationSender();
      final service = AgendaReminderService(sender);
      final future = DateTime.now().add(const Duration(days: 10));
      final due = DateTime(future.year, future.month, future.day);

      final items = [
        for (var i = 0; i < 5; i++)
          AgendaView(
            _agenda(
              id: 'item$i',
              createdAt: DateTime(2026, i + 1),
              startDate: due,
            ),
          ),
      ];

      await service.reschedule(items, premium: true);

      expect(sender.scheduled, hasLength(5));
    },
  );
}
