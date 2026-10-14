import 'package:dompet_pintar/features/security/app_lock_service.dart'
    show MemoryKeyValueStore;
import 'package:dompet_pintar/features/subscription/trial_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Hitung mundur, banner, dialog tonggak, dan notifikasi uji coba pada
/// aplikasi penuh (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 10.4).
FakeSubscriptionStatus _trial(Duration left, {bool paidUltimate = false}) =>
    FakeSubscriptionStatus(
      ultimate: paidUltimate,
      trialEndsAt: DateTime.now().add(left),
    );

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('fase normal (lebih dari 7 hari)', () {
    appTest('kartu menunjukkan sisa hari; tanpa dialog dan tanpa banner', (
      tester,
      h,
    ) async {
      expect(find.text('Uji coba Ultimate: 20 hari lagi'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byTooltip('Tutup peringatan'), findsNothing);
    }, subscription: _trial(const Duration(days: 20)));

    appTest('notifikasi penguat dijadwalkan untuk hari ke-23 dan ke-28', (
      tester,
      h,
    ) async {
      final ids = h.notifications.scheduled.map((s) => s.id).toSet();
      expect(ids, {
        TrialReminderService.idWeek,
        TrialReminderService.idLastDays,
      });
    }, subscription: _trial(const Duration(days: 20)));

    appTest('Pengaturan menampilkan sisa hari', (tester, h) async {
      await tester.tap(find.byTooltip('Pengaturan'));
      await settle(tester);
      expect(find.text('Uji coba Ultimate: 20 hari lagi'), findsOneWidget);
    }, subscription: _trial(const Duration(days: 20)));
  });

  group('mendekati (7 hari atau kurang)', () {
    appTest(
      'dialog hari ke-23 berisi dampak nyata dari data pengguna',
      (tester, h) async {
        expect(
          find.text('Uji coba Ultimate berakhir 5 hari lagi'),
          findsOneWidget,
        );
        expect(
          find.textContaining('1 buku kas tambahan akan terkunci'),
          findsOneWidget,
        );
        expect(find.textContaining('1 tabungan (Rp 250.000)'), findsOneWidget);
        expect(find.textContaining('Scan dan ringkasan AI'), findsOneWidget);
        expect(find.text('Tetap ada:'), findsOneWidget);
        expect(find.text('Ingatkan nanti'), findsOneWidget);
        expect(find.text('Lihat paket'), findsOneWidget);
      },
      subscription: _trial(const Duration(days: 5)),
      seed: (db) async {
        await db.addLedger(name: 'Bisnis', icon: 'savings', color: 1);
        final id = await db.addSavings(
          name: 'Liburan',
          icon: 'savings',
          color: 1,
        );
        await db.depositToSavings(
          savingsId: id,
          accountId: 'acc-tunai',
          amount: 250000,
          date: DateTime.now(),
        );
      },
    );

    appTest(
      '"Ingatkan nanti" menutup, dan tonggak tersimpan (tidak muncul lagi)',
      (tester, h) async {
        await _tap(tester, 'Ingatkan nanti');
        expect(find.byType(AlertDialog), findsNothing);
        final shown = await tester.runAsync(() => TrialMemory(h.store).shown());
        expect(shown, contains(TrialMilestone.d23));
      },
      subscription: _trial(const Duration(days: 5)),
    );

    appTest(
      'tonggak yang sudah pernah ditampilkan tidak muncul lagi di sesi baru',
      (tester, h) async {
        expect(find.byType(AlertDialog), findsNothing);
        // Kartu tetap menunjukkan sisa hari.
        expect(find.text('Uji coba Ultimate: 5 hari lagi'), findsOneWidget);
      },
      subscription: _trial(const Duration(days: 5)),
      kvStore: MemoryKeyValueStore()..write('trial_milestones_shown', 'd23'),
    );
  });

  group('mendesak dan hari terakhir', () {
    appTest('2 hari: banner, dialog hari ke-28, dan banner bisa ditutup', (
      tester,
      h,
    ) async {
      expect(find.text('Tinggal 2 hari lagi'), findsOneWidget);
      await _tap(tester, 'Ingatkan nanti');
      expect(find.text('Uji coba Ultimate: 2 hari lagi'), findsWidgets);
      expect(find.byTooltip('Tutup peringatan'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup peringatan'));
      await settle(tester);
      expect(find.byTooltip('Tutup peringatan'), findsNothing);
      // Kartu di Dashboard tetap ada dengan ajakan melanjutkan.
      expect(find.text('Lanjutkan'), findsOneWidget);
    }, subscription: _trial(const Duration(days: 2)));

    appTest('hari terakhir: banner tidak bisa ditutup, dialog hari terakhir', (
      tester,
      h,
    ) async {
      expect(find.text('Uji coba Ultimate berakhir hari ini'), findsOneWidget);
      await _tap(tester, 'Ingatkan nanti');
      expect(find.textContaining('berakhir hari ini pukul'), findsWidgets);
      expect(find.byTooltip('Tutup peringatan'), findsNothing);
    }, subscription: _trial(const Duration(hours: 5)));

    appTest('terlewat: dibuka pertama kali di hari ke-29 hanya satu dialog', (
      tester,
      h,
    ) async {
      expect(find.text('Tinggal 2 hari lagi'), findsOneWidget);
      await _tap(tester, 'Ingatkan nanti');
      final shown = await tester.runAsync(() => TrialMemory(h.store).shown());
      expect(shown, {TrialMilestone.d23, TrialMilestone.d28});
    }, subscription: _trial(const Duration(days: 2)));
  });

  group('berakhir', () {
    appTest(
      'kartu dan dialog akhir, isinya dalam bentuk lampau',
      (tester, h) async {
        expect(find.text('Uji coba Ultimate berakhir'), findsWidgets);
        expect(find.textContaining('Data Anda aman'), findsOneWidget);
        expect(find.text('Yang berubah:'), findsOneWidget);
        expect(
          find.textContaining('terkunci (datanya tetap aman)'),
          findsOneWidget,
        );
        expect(find.text('Tutup'), findsOneWidget);
      },
      // Tanpa uji coba aktif; kedaluwarsa terakhir 1 hari lalu tercatat.
      kvStore: MemoryKeyValueStore()
        ..write(
          'trial_last_end',
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        ),
      seed: (db) => db.addLedger(name: 'Bisnis', icon: 'savings', color: 1),
    );

    appTest(
      'lebih dari 7 hari sejak berakhir: tidak ada kartu maupun dialog',
      (tester, h) async {
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Uji coba Ultimate berakhir'), findsNothing);
      },
      kvStore: MemoryKeyValueStore()
        ..write(
          'trial_last_end',
          DateTime.now().subtract(const Duration(days: 9)).toIso8601String(),
        ),
    );

    appTest('berlangganan Ultimate: tidak ada pengumuman uji coba', (
      tester,
      h,
    ) async {
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('hari lagi'), findsNothing);
    }, subscription: _trial(const Duration(days: 2), paidUltimate: true));
  });
}
