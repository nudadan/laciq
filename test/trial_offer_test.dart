import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/features/subscription/trial_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Penawaran uji coba Ultimate: opt-in kontekstual, tidak pernah dimulai tanpa
/// ketukan pengguna (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 10.3).
const _title = 'Coba semua fitur Ultimate gratis 30 hari';

TrialStatus _available() => const TrialStatus(TrialOffer.available);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

Future<void> _seedTransactions(AppDatabase db, int n) async {
  for (var i = 0; i < n; i++) {
    await db.addTransaction(
      type: TxType.expense,
      amount: 1000 + i,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-makan',
      date: DateTime.now(),
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('kartu di Dashboard', () {
    appTest('tidak tampil bila transaksi masih sedikit', (tester, h) async {
      expect(find.text(_title), findsNothing);
    }, trialService: FakeTrialService(currentStatus: _available()));

    appTest(
      'tampil setelah cukup transaksi dan membuka lembar konfirmasi',
      (tester, h) async {
        expect(find.text(_title), findsOneWidget);
        await tester.tap(find.text(_title));
        await settle(tester);
        // Judul yang sama kini ada di kartu dan di lembar.
        expect(find.text(_title), findsNWidgets(2));
        expect(find.text('Mulai uji coba'), findsOneWidget);
        expect(find.text('Nanti saja'), findsOneWidget);
        expect(find.text('Lihat paket'), findsOneWidget);
        // Kejujuran soal akhir uji coba dan privasi.
        expect(find.textContaining('kembali ke paket Gratis'), findsOneWidget);
        expect(find.textContaining('ber-hash'), findsOneWidget);
      },
      seed: (db) => _seedTransactions(db, 5),
      trialService: FakeTrialService(currentStatus: _available()),
    );

    appTest(
      'tidak tampil bila status bukan layak (sudah dipakai, dijeda)',
      (tester, h) async {
        expect(find.text(_title), findsNothing);
      },
      seed: (db) => _seedTransactions(db, 6),
      trialService: FakeTrialService(
        currentStatus: const TrialStatus(TrialOffer.used),
      ),
    );

    appTest(
      '"Lanjutkan" untuk perangkat yang masih punya uji coba berjalan',
      (tester, h) async {
        expect(find.text('Lanjutkan uji coba Ultimate'), findsOneWidget);
        await tester.tap(find.text('Lanjutkan uji coba Ultimate'));
        await settle(tester);
        expect(find.text('Lanjutkan uji coba'), findsOneWidget);
        expect(find.textContaining('hari lagi'), findsOneWidget);
      },
      seed: (db) => _seedTransactions(db, 5),
      trialService: FakeTrialService(
        currentStatus: TrialStatus(
          TrialOffer.resumable,
          endsAt: DateTime.now().add(const Duration(days: 12, hours: 1)),
        ),
      ),
    );

    appTest(
      'ditutup: hilang dan tidak muncul lagi di sesi ini',
      (tester, h) async {
        await tester.tap(find.byTooltip('Tutup'));
        await settle(tester);
        expect(find.text(_title), findsNothing);
      },
      seed: (db) => _seedTransactions(db, 5),
      trialService: FakeTrialService(currentStatus: _available()),
    );
  });

  group('titik fitur terkunci', () {
    appTest('menyentuh Tabungan menawarkan uji coba, bukan halaman langganan', (
      tester,
      h,
    ) async {
      await _openTab(tester, 'Lainnya');
      await tester.tap(find.text('Tabungan'));
      await settle(tester);
      expect(find.text('Mulai uji coba'), findsOneWidget);
      expect(find.text('Upgrade ke Ultimate'), findsNothing);
      // Tidak ada klaim sebelum pengguna menekan tombol.
      expect(h.trial.claimCalls, 0);
    }, trialService: FakeTrialService(currentStatus: _available()));

    appTest(
      'Mulai uji coba: klaim dipanggil, fitur terbuka, pesan sukses',
      (tester, h) async {
        await _openTab(tester, 'Lainnya');
        await tester.tap(find.text('Tabungan'));
        await settle(tester);
        await tester.tap(find.text('Mulai uji coba'));
        await settle(tester);

        expect(h.trial.claimCalls, 1);
        expect(find.textContaining('Uji coba Ultimate aktif'), findsOneWidget);
        // Sheet tertutup; kembali ke menu Lainnya dengan Tabungan kini terbuka.
        expect(find.text('Mulai uji coba'), findsNothing);
        await tester.tap(find.text('Tabungan'));
        await settle(tester);
        expect(find.byTooltip('Tabungan Baru'), findsOneWidget);
      },
      trialService: FakeTrialService(
        currentStatus: _available(),
        claimResult: TrialClaimResult(
          TrialClaimOutcome.granted,
          endsAt: DateTime(2026, 11, 13),
        ),
      ),
    );

    appTest('Lihat paket: membuka halaman langganan tanpa klaim', (
      tester,
      h,
    ) async {
      await _openTab(tester, 'Lainnya');
      await tester.tap(find.text('Tabungan'));
      await settle(tester);
      await tester.tap(find.text('Lihat paket'));
      await settle(tester);
      expect(find.text('Mulai uji coba'), findsNothing);
      expect(find.text('LaciQ Premium'), findsOneWidget);
      expect(h.trial.claimCalls, 0);
    }, trialService: FakeTrialService(currentStatus: _available()));

    appTest('Nanti saja: menutup tanpa klaim dan tanpa halaman langganan', (
      tester,
      h,
    ) async {
      await _openTab(tester, 'Lainnya');
      await tester.tap(find.text('Tabungan'));
      await settle(tester);
      await tester.tap(find.text('Nanti saja'));
      await settle(tester);
      expect(find.text('Mulai uji coba'), findsNothing);
      expect(find.text('LaciQ Premium'), findsNothing);
      expect(h.trial.claimCalls, 0);
    }, trialService: FakeTrialService(currentStatus: _available()));

    appTest(
      'klaim ditolak: pesan jelas, tidak ada akses diberikan',
      (tester, h) async {
        await _openTab(tester, 'Lainnya');
        await tester.tap(find.text('Tabungan'));
        await settle(tester);
        await tester.tap(find.text('Mulai uji coba'));
        await settle(tester);
        expect(find.textContaining('sudah pernah dipakai'), findsOneWidget);
        await tester.tap(find.text('Tabungan'));
        await settle(tester);
        // Masih terkunci: halaman upgrade, bukan halaman Tabungan.
        expect(find.byTooltip('Tabungan Baru'), findsNothing);
      },
      trialService: FakeTrialService(
        currentStatus: _available(),
        claimResult: const TrialClaimResult(TrialClaimOutcome.alreadyUsed),
      ),
    );

    appTest('tidak layak: langsung ke halaman langganan seperti biasa', (
      tester,
      h,
    ) async {
      await _openTab(tester, 'Lainnya');
      await tester.tap(find.text('Tabungan'));
      await settle(tester);
      expect(find.text('Mulai uji coba'), findsNothing);
      expect(find.text('LaciQ Premium'), findsOneWidget);
    }, trialService: FakeTrialService());
  });

  group('Pengaturan', () {
    appTest('baris uji coba tampil bila layak', (tester, h) async {
      await tester.tap(find.byTooltip('Pengaturan'));
      await settle(tester);
      expect(find.text('Coba Ultimate gratis 30 hari'), findsOneWidget);
    }, trialService: FakeTrialService(currentStatus: _available()));

    appTest('baris uji coba tidak tampil bila tidak layak', (tester, h) async {
      await tester.tap(find.byTooltip('Pengaturan'));
      await settle(tester);
      expect(find.text('Coba Ultimate gratis 30 hari'), findsNothing);
    }, trialService: FakeTrialService());
  });
}
