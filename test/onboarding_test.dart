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
    '"Lanjut" melewati semua halaman panduan, "Mulai" di halaman terakhir '
    'menandai selesai dan ke dashboard',
    (tester, h) async {
      const titles = [
        'Anggaran dan tren yang mudah dibaca',
        'Rencanakan keuangan ke depan',
        'Data Anda tetap di HP Anda',
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

      expect(find.text('Total Saldo'), findsOneWidget);
      expect(await h.store.read(onboardingSeenKey), '1');
    },
    seenOnboarding: false,
  );

  appTest('panduan menjelaskan fitur beserta paket yang membukanya', (
    tester,
    h,
  ) async {
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
  }, seenOnboarding: false);

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
