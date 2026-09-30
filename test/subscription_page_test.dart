import 'package:dompet_pintar/features/subscription/subscription_plans.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('belum premium: entri Settings menawarkan upgrade', (
    tester,
    h,
  ) async {
    await _openSettings(tester);
    expect(find.text('Upgrade ke Premium'), findsOneWidget);
    expect(find.text('DompetKu Premium aktif'), findsNothing);
  });

  appTest('sudah premium: entri Settings menampilkan status aktif', (
    tester,
    h,
  ) async {
    await _openSettings(tester);
    expect(find.text('DompetKu Premium aktif'), findsOneWidget);
    expect(find.text('Upgrade ke Premium'), findsNothing);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest('menampilkan daftar manfaat, bukan cuma "hilangkan iklan"', (
    tester,
    h,
  ) async {
    await _openSettings(tester);
    await tester.tap(find.text('Upgrade ke Premium'));
    await settle(tester);

    expect(find.textContaining('Tanpa iklan'), findsOneWidget);
    expect(find.textContaining('Analisa Tren'), findsOneWidget);
    expect(find.textContaining('Backup cloud'), findsOneWidget);
    expect(find.textContaining('Agenda pengingat'), findsOneWidget);
  });

  appTest('membeli paket: daftar paket tampil, beli sukses, status berubah', (
    tester,
    h,
  ) async {
    await _openSettings(tester);
    await tester.tap(find.text('Upgrade ke Premium'));
    await settle(tester);

    // Dua tingkat, masing-masing bulanan & tahunan, dalam Rupiah.
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Ultimate'), findsOneWidget);
    expect(find.text('Rp 7.500'), findsOneWidget);
    expect(find.text('Rp 75.000'), findsOneWidget);
    expect(find.text('Rp 12.500'), findsOneWidget);
    expect(find.text('Rp 125.000'), findsOneWidget);
    expect(find.text('Hemat 17% dibanding bulanan'), findsNWidgets(2));

    await tester.tap(find.text('Berlangganan').first);
    await settle(tester);

    expect(h.subscription.purchased, ['premium_monthly']);
    // Berhasil: halaman ditutup, kembali ke Settings dengan status aktif.
    expect(find.text('DompetKu Premium aktif'), findsOneWidget);
  });

  appTest('tile Settings menyebut harga Premium termurah dalam Rupiah', (
    tester,
    h,
  ) async {
    await _openSettings(tester);
    expect(find.text('Hilangkan iklan mulai Rp 7.500/bulan'), findsOneWidget);
  });

  test('harga referensi sesuai penawaran dan hemat tahunan ~17%', () {
    expect(kReferencePrices, {
      (SubscriptionTier.premium, SubscriptionPeriod.monthly): 7500,
      (SubscriptionTier.premium, SubscriptionPeriod.yearly): 75000,
      (SubscriptionTier.ultimate, SubscriptionPeriod.monthly): 12500,
      (SubscriptionTier.ultimate, SubscriptionPeriod.yearly): 125000,
    });
    expect(yearlySavingsPercent(monthly: 7500, yearly: 75000), 17);
    expect(yearlySavingsPercent(monthly: 12500, yearly: 125000), 17);
    expect(yearlySavingsPercent(monthly: 7500, yearly: 90000), 0);
  });

  appTest('pulihkan pembelian memanggil restorePurchases', (tester, h) async {
    await _openSettings(tester);
    await tester.tap(find.text('Upgrade ke Premium'));
    await settle(tester);

    await tester.tap(find.text('Pulihkan pembelian'));
    await settle(tester);

    expect(h.subscription.restoreCalled, isTrue);
  });
}
