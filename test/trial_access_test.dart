import 'package:dompet_pintar/features/subscription/subscription_plans.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Selama uji coba Ultimate, FITUR terbuka (hak akses) tetapi tampilan dan
/// keputusan pembelian mengikuti langganan BERBAYAR. Lihat
/// docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 5.2 (risiko penagihan ganda).
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await settle(tester);
}

final _trialEnd = DateTime.now().add(const Duration(days: 20));

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('pengguna Gratis yang sedang uji coba Ultimate', () {
    appTest('fitur Ultimate terbuka: Tabungan dan Buku Kas tidak terkunci', (
      tester,
      h,
    ) async {
      await _openTab(tester, 'Lainnya');
      // Tile aktif (bukan "Fitur Ultimate" yang terkunci).
      expect(find.text('Fitur Ultimate'), findsNothing);
      expect(find.textContaining('Saldo terpisah dari dompet'), findsOneWidget);

      await tester.tap(find.text('Tabungan'));
      await settle(tester);
      expect(find.byTooltip('Tabungan Baru'), findsOneWidget);
      expect(find.text('Upgrade ke Ultimate'), findsNothing);
    }, subscription: FakeSubscriptionStatus(trialEndsAt: _trialEnd));

    appTest(
      'tampilan langganan tetap Gratis: tawaran Premium, bukan "Ultimate aktif"',
      (tester, h) async {
        await _openSettings(tester);
        expect(find.text('Upgrade ke Premium'), findsOneWidget);
        expect(find.text('LaciQ Ultimate aktif'), findsNothing);
        expect(find.text('LaciQ Premium aktif'), findsNothing);
      },
      subscription: FakeSubscriptionStatus(trialEndsAt: _trialEnd),
    );
  });

  group('pelanggan Premium berbayar yang sedang uji coba Ultimate', () {
    appTest(
      'fitur Ultimate terbuka, tetapi tampil sebagai Premium aktif dengan tawaran upgrade',
      (tester, h) async {
        await _openTab(tester, 'Lainnya');
        await tester.tap(find.text('Tabungan'));
        await settle(tester);
        expect(find.byTooltip('Tabungan Baru'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await settle(tester);

        await _openSettings(tester);
        expect(find.text('LaciQ Premium aktif'), findsOneWidget);
        expect(find.text('LaciQ Ultimate aktif'), findsNothing);
        expect(find.text('Upgrade'), findsOneWidget);
      },
      subscription: FakeSubscriptionStatus(
        premium: true,
        trialEndsAt: _trialEnd,
      ),
    );

    appTest(
      'upgrade ke Ultimate hanya menawarkan Ultimate (satu langganan, bukan dua)',
      (tester, h) async {
        await _openSettings(tester);
        await tester.tap(find.text('Upgrade'));
        await settle(tester);
        expect(find.text('Upgrade ke Ultimate'), findsOneWidget);
        // Halaman hanya berisi kartu Ultimate; kartu Premium tidak ditawarkan lagi.
        expect(find.text('Premium'), findsNothing);
        expect(find.text('Ultimate'), findsWidgets);
      },
      subscription: FakeSubscriptionStatus(
        premium: true,
        trialEndsAt: _trialEnd,
      ),
    );
  });

  group('pelanggan Ultimate berbayar', () {
    appTest(
      'uji coba tidak relevan: tampil Ultimate aktif',
      (tester, h) async {
        await _openSettings(tester);
        expect(find.text('LaciQ Ultimate aktif'), findsOneWidget);
      },
      subscription: FakeSubscriptionStatus(
        ultimate: true,
        trialEndsAt: _trialEnd,
      ),
    );
  });

  test('detail Fake: tier berbayar terpisah dari hak akses', () async {
    final trial = FakeSubscriptionStatus(trialEndsAt: _trialEnd);
    expect(await trial.watchIsUltimate().first, isTrue);
    expect(await trial.watchIsPremium().first, isTrue);
    final detail = await trial.watchDetail().first;
    expect(detail.paidTier, ActiveTier.free);
    expect(detail.onTrial, isTrue);
    expect(await trial.activeSubscriptionProductId(), isNull);

    final paidPremium = FakeSubscriptionStatus(
      premium: true,
      trialEndsAt: _trialEnd,
    );
    expect(
      (await paidPremium.watchDetail().first).paidTier,
      ActiveTier.premium,
    );
    expect(await paidPremium.activeSubscriptionProductId(), 'premium_monthly');
  });
}
