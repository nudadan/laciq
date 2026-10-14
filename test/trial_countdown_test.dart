import 'package:dompet_pintar/features/security/app_lock_service.dart'
    show MemoryKeyValueStore;
import 'package:dompet_pintar/features/subscription/trial_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Fase hitung mundur, tonggak, ingatan, dan notifikasi penguat uji coba
/// (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 10.4).
void main() {
  final now = DateTime(2026, 11, 1, 9);
  TrialCountdown at(Duration left, {bool paid = false}) =>
      TrialCountdown.at(now, endsAt: now.add(left), paidUltimate: paid);

  group('fase menurut sisa waktu', () {
    test('batas tiap fase', () {
      expect(at(const Duration(days: 30)).phase, TrialPhase.normal);
      expect(at(const Duration(days: 8)).phase, TrialPhase.normal);
      expect(at(const Duration(days: 7)).phase, TrialPhase.approaching);
      expect(at(const Duration(days: 4)).phase, TrialPhase.approaching);
      expect(at(const Duration(days: 3)).phase, TrialPhase.urgent);
      expect(at(const Duration(days: 1, hours: 1)).phase, TrialPhase.urgent);
      expect(at(const Duration(hours: 24)).phase, TrialPhase.lastDay);
      expect(at(const Duration(minutes: 5)).phase, TrialPhase.lastDay);
    });

    test('sisa hari dibulatkan ke atas', () {
      expect(at(const Duration(days: 30)).daysLeft, 30);
      expect(at(const Duration(days: 6, hours: 23)).daysLeft, 7);
      expect(at(const Duration(hours: 1)).daysLeft, 1);
      expect(TrialCountdown.none.daysLeft, 0);
    });

    test('berakhir: jendela 7 hari, lalu tidak ada', () {
      final end = now.subtract(const Duration(hours: 1));
      final justEnded = TrialCountdown.at(now, lastEnd: end);
      expect(justEnded.phase, TrialPhase.ended);
      expect(justEnded.running, isFalse);

      final old = TrialCountdown.at(
        now,
        lastEnd: now.subtract(const Duration(days: 8)),
      );
      expect(old.phase, TrialPhase.none);
    });

    test('tanpa uji coba sama sekali: none', () {
      expect(TrialCountdown.at(now).phase, TrialPhase.none);
    });

    test('pelanggan Ultimate berbayar: tidak ada pengumuman', () {
      expect(at(const Duration(days: 2), paid: true).phase, TrialPhase.none);
      expect(
        TrialCountdown.at(
          now,
          lastEnd: now.subtract(const Duration(days: 1)),
          paidUltimate: true,
        ).phase,
        TrialPhase.none,
      );
    });
  });

  group('tonggak', () {
    test('satu tonggak per fase, hanya yang belum ditampilkan', () {
      expect(dueMilestone(at(const Duration(days: 20)), {}), isNull);
      expect(dueMilestone(at(const Duration(days: 5)), {}), TrialMilestone.d23);
      expect(dueMilestone(at(const Duration(days: 2)), {}), TrialMilestone.d28);
      expect(
        dueMilestone(at(const Duration(hours: 5)), {}),
        TrialMilestone.d30,
      );
      expect(
        dueMilestone(TrialCountdown.at(now, lastEnd: now), {}),
        TrialMilestone.end,
      );
    });

    test('tidak muncul dua kali', () {
      expect(
        dueMilestone(at(const Duration(days: 5)), {TrialMilestone.d23}),
        isNull,
      );
      expect(
        dueMilestone(TrialCountdown.at(now, lastEnd: now), {
          TrialMilestone.end,
        }),
        isNull,
      );
    });

    test('tonggak yang terlewat tidak muncul berurutan', () {
      expect(impliedBy(TrialMilestone.d28), {
        TrialMilestone.d23,
        TrialMilestone.d28,
      });
      expect(impliedBy(TrialMilestone.end), TrialMilestone.values.toSet());
      // Dibuka pertama kali di hari ke-29: d28 tampil, d23 dianggap lewat.
      final shown = {...impliedBy(TrialMilestone.d28)};
      expect(dueMilestone(at(const Duration(days: 2)), shown), isNull);
      expect(dueMilestone(at(const Duration(days: 5)), shown), isNull);
    });
  });

  group('TrialMemory', () {
    test('tonggak ditampilkan tersimpan beserta yang tersirat', () async {
      final memory = TrialMemory(MemoryKeyValueStore());
      expect(await memory.shown(), isEmpty);
      await memory.markShown(TrialMilestone.d28);
      expect(await memory.shown(), {TrialMilestone.d23, TrialMilestone.d28});
      await memory.markShown(TrialMilestone.end);
      expect(await memory.shown(), TrialMilestone.values.toSet());
    });

    test('kedaluwarsa terakhir tersimpan', () async {
      final memory = TrialMemory(MemoryKeyValueStore());
      expect(await memory.lastEnd(), isNull);
      final end = DateTime(2026, 11, 30, 10);
      await memory.recordEnd(end);
      expect(await memory.lastEnd(), end);
    });

    test('banner yang ditutup berlaku untuk hari itu saja', () async {
      final memory = TrialMemory(MemoryKeyValueStore());
      final day = DateTime(2026, 11, 28, 9);
      expect(await memory.bannerDismissedOn(day), isFalse);
      await memory.dismissBanner(day);
      expect(await memory.bannerDismissedOn(day), isTrue);
      expect(
        await memory.bannerDismissedOn(day.add(const Duration(days: 1))),
        isFalse,
      );
    });
  });

  group('TrialReminderService', () {
    test('menjadwalkan hari ke-23 dan ke-28 pukul 10.00', () async {
      final sender = FakeNotificationSender();
      final service = TrialReminderService(sender);
      final end = DateTime(2026, 12, 1, 14);
      await service.reschedule(end, now: DateTime(2026, 11, 2));

      expect(sender.scheduled, hasLength(2));
      final byId = {for (final s in sender.scheduled) s.id: s};
      expect(byId[TrialReminderService.idWeek]!.at, DateTime(2026, 11, 24, 10));
      expect(
        byId[TrialReminderService.idLastDays]!.at,
        DateTime(2026, 11, 29, 10),
      );
    });

    test('waktu yang sudah lewat tidak dijadwalkan', () async {
      final sender = FakeNotificationSender();
      final service = TrialReminderService(sender);
      await service.reschedule(
        DateTime(2026, 12, 1, 14),
        now: DateTime(2026, 11, 28),
      );
      expect(sender.scheduled.map((s) => s.id), [
        TrialReminderService.idLastDays,
      ]);
    });

    test('tanpa uji coba: membatalkan keduanya', () async {
      final sender = FakeNotificationSender();
      await TrialReminderService(sender).reschedule(null);
      expect(
        sender.cancelled,
        containsAll([
          TrialReminderService.idWeek,
          TrialReminderService.idLastDays,
        ]),
      );
    });
  });
}
