import 'package:dompet_pintar/features/subscription/subscription_plans.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tier akses (membuka fitur) boleh memasukkan uji coba, tetapi tier BERBAYAR
/// tidak: itu yang menentukan penggantian produk Play. Salah di sini berarti
/// pelanggan Premium yang membeli Ultimate saat uji coba tertagih dua langganan.
void main() {
  final trialEnd = DateTime.utc(2026, 11, 13, 4);
  final paidEnd = DateTime.utc(2026, 10, 20);

  ActiveEntitlement ent(
    String id, {
    bool promo = false,
    String? product,
    DateTime? ends,
  }) => ActiveEntitlement(
    id: id,
    productId: product ?? (promo ? 'rc_promo_${id}_custom' : 'dompetku_$id'),
    promotional: promo,
    expiresAt: ends,
  );

  ActiveSubscription sub(
    String product, {
    bool promo = false,
    DateTime? ends,
  }) => ActiveSubscription(
    productId: product,
    promotional: promo,
    expiresAt: ends,
  );

  group('subscriptionDetailOf', () {
    test('tanpa langganan dan tanpa uji coba: gratis', () {
      final d = subscriptionDetailOf(entitlements: [], subscriptions: []);
      expect(d.paidTier, ActiveTier.free);
      expect(d.paidProductId, isNull);
      expect(d.trialEndsAt, isNull);
      expect(d.onTrial, isFalse);
    });

    test('hanya uji coba (hibah promosional): berbayar tetap gratis, uji coba terbaca', () {
      final d = subscriptionDetailOf(
        entitlements: [
          ent('premium', promo: true, ends: trialEnd),
          ent('ultimate', promo: true, ends: trialEnd),
        ],
        subscriptions: [
          sub('rc_promo_ultimate_custom', promo: true, ends: trialEnd),
          sub('rc_promo_premium_custom', promo: true, ends: trialEnd),
        ],
      );
      expect(d.paidTier, ActiveTier.free);
      expect(d.paidProductId, isNull);
      expect(d.trialEndsAt, trialEnd);
      expect(d.onTrial, isTrue);
    });

    test('Premium berbayar: tier premium, produk terbaca, tanpa uji coba', () {
      final d = subscriptionDetailOf(
        entitlements: [
          ent('premium', product: 'dompetku_premium', ends: paidEnd),
        ],
        subscriptions: [sub('dompetku_premium', ends: paidEnd)],
      );
      expect(d.paidTier, ActiveTier.premium);
      expect(d.paidProductId, 'dompetku_premium');
      expect(d.onTrial, isFalse);
    });

    test('Ultimate berbayar: tier ultimate; produk Ultimate', () {
      final d = subscriptionDetailOf(
        entitlements: [
          ent('premium', product: 'dompetku_ultimate', ends: paidEnd),
          ent('ultimate', product: 'dompetku_ultimate', ends: paidEnd),
        ],
        subscriptions: [sub('dompetku_ultimate', ends: paidEnd)],
      );
      expect(d.paidTier, ActiveTier.ultimate);
      expect(d.paidProductId, 'dompetku_ultimate');
    });

    test('Premium berbayar + uji coba Ultimate: berbayar tetap PREMIUM dan produknya terbaca', () {
      final d = subscriptionDetailOf(
        entitlements: [
          // uji coba lebih panjang daripada langganan, jadi entitlement menunjuk produk promo
          ent('premium', promo: true, ends: trialEnd),
          ent('ultimate', promo: true, ends: trialEnd),
        ],
        subscriptions: [
          sub('dompetku_premium', ends: paidEnd),
          sub('rc_promo_ultimate_custom', promo: true, ends: trialEnd),
        ],
      );
      expect(d.paidTier, ActiveTier.premium);
      expect(d.paidProductId, 'dompetku_premium');
      expect(d.trialEndsAt, trialEnd);
    });

    test('Ultimate berbayar + hibah: tidak dianggap sedang uji coba', () {
      final d = subscriptionDetailOf(
        entitlements: [
          ent('ultimate', product: 'dompetku_ultimate', ends: paidEnd),
          ent('premium', product: 'dompetku_ultimate', ends: paidEnd),
        ],
        subscriptions: [
          sub('dompetku_ultimate', ends: paidEnd),
          sub('rc_promo_ultimate_custom', promo: true, ends: trialEnd),
        ],
      );
      expect(d.paidTier, ActiveTier.ultimate);
      expect(d.trialEndsAt, isNull);
    });

    test(
      'hibah promosional Premium saja (bukan Ultimate) bukan uji coba Ultimate',
      () {
        final d = subscriptionDetailOf(
          entitlements: [ent('premium', promo: true, ends: trialEnd)],
          subscriptions: [
            sub('rc_promo_premium_custom', promo: true, ends: trialEnd),
          ],
        );
        expect(d.paidTier, ActiveTier.free);
        expect(d.trialEndsAt, isNull);
      },
    );
  });

  group('productToReplace (penggantian produk Play)', () {
    test('Premium berbayar membeli Ultimate: produk Premium diganti, juga saat sedang uji coba', () {
      const premiumPaid = SubscriptionDetail(
        paidTier: ActiveTier.premium,
        paidProductId: 'dompetku_premium',
      );
      expect(
        productToReplace(
          detail: premiumPaid,
          target: SubscriptionTier.ultimate,
        ),
        'dompetku_premium',
      );
      final withTrial = SubscriptionDetail(
        paidTier: ActiveTier.premium,
        paidProductId: 'dompetku_premium',
        trialEndsAt: trialEnd,
      );
      expect(
        productToReplace(detail: withTrial, target: SubscriptionTier.ultimate),
        'dompetku_premium',
      );
    });

    test('gratis (termasuk yang sedang uji coba) membeli: pembelian biasa tanpa penggantian', () {
      final trialOnly = SubscriptionDetail(
        paidTier: ActiveTier.free,
        trialEndsAt: trialEnd,
      );
      for (final target in SubscriptionTier.values) {
        expect(productToReplace(detail: trialOnly, target: target), isNull);
      }
    });

    test('Premium membeli Premium, atau Ultimate membeli apa pun: tanpa penggantian', () {
      const premiumPaid = SubscriptionDetail(
        paidTier: ActiveTier.premium,
        paidProductId: 'dompetku_premium',
      );
      expect(
        productToReplace(detail: premiumPaid, target: SubscriptionTier.premium),
        isNull,
      );
      const ultimatePaid = SubscriptionDetail(
        paidTier: ActiveTier.ultimate,
        paidProductId: 'dompetku_ultimate',
      );
      expect(
        productToReplace(
          detail: ultimatePaid,
          target: SubscriptionTier.ultimate,
        ),
        isNull,
      );
    });
  });

  group('paidTierSatisfies', () {
    test('menunggu pembelian berbayar, bukan hibah', () {
      expect(
        paidTierSatisfies(ActiveTier.free, SubscriptionTier.premium),
        isFalse,
      );
      expect(
        paidTierSatisfies(ActiveTier.premium, SubscriptionTier.premium),
        isTrue,
      );
      expect(
        paidTierSatisfies(ActiveTier.premium, SubscriptionTier.ultimate),
        isFalse,
      );
      expect(
        paidTierSatisfies(ActiveTier.ultimate, SubscriptionTier.premium),
        isTrue,
      );
      expect(
        paidTierSatisfies(ActiveTier.ultimate, SubscriptionTier.ultimate),
        isTrue,
      );
    });
  });
}
