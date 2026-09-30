import 'package:dompet_pintar/features/onboarding/onboarding_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('instalasi baru menampilkan onboarding, bukan dashboard', (
    tester,
    h,
  ) async {
    expect(find.text('Catat transaksi dengan cepat'), findsOneWidget);
    expect(find.text('Total Saldo'), findsNothing);
    expect(await h.store.read(onboardingSeenKey), isNull);
  }, seenOnboarding: false);

  appTest(
    '"Lanjut" 2x sampai halaman terakhir, "Mulai" menandai selesai dan ke dashboard',
    (tester, h) async {
      await tester.tap(find.text('Lanjut'));
      await settle(tester);
      expect(find.text('Anggaran dan tren yang mudah dibaca'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await settle(tester);
      expect(find.text('Data Anda tetap di HP Anda'), findsOneWidget);
      expect(find.text('Mulai'), findsOneWidget);

      await tester.tap(find.text('Mulai'));
      await settle(tester);

      expect(find.text('Total Saldo'), findsOneWidget);
      expect(await h.store.read(onboardingSeenKey), '1');
    },
    seenOnboarding: false,
  );

  appTest('"Lewati" dari halaman pertama langsung ke dashboard', (
    tester,
    h,
  ) async {
    expect(find.text('Catat transaksi dengan cepat'), findsOneWidget);
    await tester.tap(find.text('Lewati'));
    await settle(tester);

    expect(find.text('Total Saldo'), findsOneWidget);
    expect(await h.store.read(onboardingSeenKey), '1');
  }, seenOnboarding: false);

  appTest(
    'sudah dilihat sebelumnya (mis. buka lagi app) langsung ke dashboard',
    (tester, h) async {
      expect(find.text('Total Saldo'), findsOneWidget);
      expect(find.text('Catat transaksi dengan cepat'), findsNothing);
    },
  ); // seenOnboarding default true

  appTest('"Lihat panduan lagi" dari Pengaturan menampilkan onboarding tanpa '
      'mengubah status "sudah dilihat", dan kembali dengan tombol Kembali', (
    tester,
    h,
  ) async {
    await tester.tap(find.byTooltip('Pengaturan'));
    await settle(tester);
    await tester.tap(find.text('Lihat panduan lagi'));
    await settle(tester);

    expect(find.text('Catat transaksi dengan cepat'), findsOneWidget);
    // Halaman standalone tidak punya tombol "Lewati" di pojok (masih ada,
    // tapi menutup halaman, bukan mengubah status) — pastikan tetap '1'.
    await tester.tap(find.text('Lewati'));
    await settle(tester);

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(await h.store.read(onboardingSeenKey), '1');
  }); // seenOnboarding default true
}
