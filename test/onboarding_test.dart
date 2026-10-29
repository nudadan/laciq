import 'package:flutter/material.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/features/onboarding/onboarding_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<void> openGuide(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Pengaturan'));
    await settle(tester);
    await tester.tap(find.text('Lihat panduan lagi'));
    await settle(tester);
  }

  Future<LedgerKind> mainKind(AppHarness h, WidgetTester tester) async {
    final ledger = await tester.runAsync(
      () => h.db.watchLedgers().first.then(
        (l) => l.firstWhere((x) => x.id == kMainLedgerId),
      ),
    );
    return ledger!.kind;
  }

  group('alur awal instalasi baru', () {
    appTest('menampilkan sapaan, bukan dashboard', (tester, h) async {
      expect(find.text('Selamat datang di LaciQ'), findsOneWidget);
      expect(find.text('Total Saldo'), findsNothing);
      expect(await h.store.read(onboardingSeenKey), isNull);
    }, seenOnboarding: false);

    appTest('pribadi: tiga langkah, Mode usaha tetap mati', (tester, h) async {
      await tester.tap(find.text('Mulai'));
      await settle(tester);
      expect(find.text('Untuk apa kamu memakai LaciQ?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('choice-personal')));
      await settle(tester);
      expect(find.text('Catat transaksi pertamamu'), findsOneWidget);

      await tester.tap(find.text('Nanti saja'));
      await settle(tester);

      expect(find.text('Total Saldo'), findsOneWidget);
      expect(await h.store.read(onboardingSeenKey), '1');
      expect(await mainKind(h, tester), LedgerKind.personal);
    }, seenOnboarding: false);

    appTest('usaha kecil: Mode usaha menyala di Buku Utama', (tester, h) async {
      await tester.tap(find.text('Mulai'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('choice-business')));
      await settle(tester);
      expect(find.text('Catat transaksi pertamamu'), findsOneWidget);

      await tester.tap(find.text('Nanti saja'));
      await settle(tester);

      expect(find.text('Total Saldo'), findsOneWidget);
      expect(await mainKind(h, tester), LedgerKind.business);
    }, seenOnboarding: false);

    appTest('Catat sekarang membuka formulir; selesai ke dashboard', (
      tester,
      h,
    ) async {
      await tester.tap(find.text('Mulai'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('choice-personal')));
      await settle(tester);
      await tester.tap(find.text('Catat sekarang'));
      await settle(tester);
      expect(find.text('Simpan'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, '25000');
      await tester.tap(find.text('Makanan & Minuman'));
      await tester.pump();
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.text('Total Saldo'), findsOneWidget);
      expect(await h.store.read(onboardingSeenKey), '1');
      final count = await tester.runAsync(
        () => h.db.watchActiveTransactionCount().first,
      );
      expect(count, 1);
    }, seenOnboarding: false);

    appTest('"Lewati" dari sapaan langsung ke dashboard', (tester, h) async {
      expect(find.text('Selamat datang di LaciQ'), findsOneWidget);
      await tester.tap(find.text('Lewati'));
      await settle(tester);

      expect(find.text('Total Saldo'), findsOneWidget);
      expect(await h.store.read(onboardingSeenKey), '1');
      expect(await mainKind(h, tester), LedgerKind.personal);
    }, seenOnboarding: false);

    appTest(
      'sudah dilihat sebelumnya (mis. buka lagi app) langsung ke dashboard',
      (tester, h) async {
        expect(find.text('Total Saldo'), findsOneWidget);
        expect(find.text('Selamat datang di LaciQ'), findsNothing);
      },
    ); // seenOnboarding default true
  });

  group('panduan fitur (Pengaturan > Lihat panduan lagi)', () {
    appTest('menampilkan panduan tanpa mengubah status "sudah dilihat", dan '
        '"Lewati" kembali ke Pengaturan', (tester, h) async {
      await openGuide(tester);
      expect(find.text('Catat transaksi dengan cepat'), findsOneWidget);

      await tester.tap(find.text('Lewati'));
      await settle(tester);

      expect(find.text('Pengaturan'), findsOneWidget);
      expect(await h.store.read(onboardingSeenKey), '1');
    });

    appTest(
      '"Lanjut" melewati semua halaman, "Mulai" di halaman terakhir menutup '
      'panduan',
      (tester, h) async {
        await openGuide(tester);
        const titles = [
          'Anggaran dan tren yang mudah dibaca',
          'Rencanakan keuangan ke depan',
          'Datamu tetap di HP-mu',
          'Ultimate untuk pembukuan serius',
          'Pilih paket yang cocok',
        ];
        for (final title in titles) {
          expect(find.text('Mulai'), findsNothing);
          await tester.tap(find.text('Lanjut'));
          await settle(tester);
          expect(find.text(title), findsOneWidget);
        }
        expect(find.text('Mulai'), findsOneWidget);
        expect(find.text('Lanjut'), findsNothing);

        await tester.tap(find.text('Mulai'));
        await settle(tester);

        expect(find.text('Pengaturan'), findsOneWidget);
        expect(await h.store.read(onboardingSeenKey), '1');
      },
    );

    appTest('menjelaskan fitur beserta paket yang membukanya', (
      tester,
      h,
    ) async {
      await openGuide(tester);
      // Halaman 1: fitur dasar dan fitur Premium berlabel.
      expect(find.text('Banyak dompet'), findsOneWidget);
      expect(find.text('Scan struk'), findsOneWidget);
      expect(find.text('Catat dengan suara'), findsOneWidget);
      expect(find.text('Premium'), findsWidgets);

      // Halaman 2: Laporan Bulanan dan ekspor Excel.
      await tester.tap(find.text('Lanjut'));
      await settle(tester);
      expect(find.text('Laporan Bulanan'), findsOneWidget);
      expect(find.text('Ekspor laporan ke Excel'), findsOneWidget);
      expect(find.text('Ekspor CSV'), findsOneWidget);

      // Halaman Ultimate: fitur khusus berlabel Ultimate.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Lanjut'));
        await settle(tester);
      }
      expect(find.text('Multi buku kas'), findsOneWidget);
      expect(find.text('Scan struk dengan AI'), findsOneWidget);
      expect(find.text('Ringkasan AI untuk Laporan Bulanan'), findsOneWidget);
      expect(find.textContaining('empat fitur khusus'), findsOneWidget);
      expect(find.text('Tabungan'), findsOneWidget);
      expect(find.text('Ultimate'), findsWidgets);

      // Halaman paket: perbandingan Gratis, Premium, Ultimate.
      await tester.tap(find.text('Lanjut'));
      await settle(tester);
      expect(find.text('Gratis'), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
    });
  });
}
