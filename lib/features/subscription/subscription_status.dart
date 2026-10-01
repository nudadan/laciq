import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/money.dart';
import 'revenuecat_config.dart';
import 'subscription_plans.dart';

class SubscriptionPackage {
  const SubscriptionPackage({
    required this.id,
    required this.tier,
    required this.period,
    required this.priceLabel,
    this.amount,
    this.native,
  });

  final String id;
  final SubscriptionTier tier;
  final SubscriptionPeriod period;

  /// Harga siap tampil, selalu dalam Rupiah bila toko menagih dalam IDR.
  final String priceLabel;

  /// Nominal Rupiah utuh; null bila toko menagih dalam mata uang lain.
  final int? amount;

  /// Referensi ke objek `Package` RevenueCat asli, dipakai internal oleh
  /// [RevenueCatSubscriptionStatus.purchase]. Diabaikan implementasi lain
  /// (mis. `FakeSubscriptionStatus` di tes).
  final Object? native;
}

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pengguna membatalkan sendiri dialog pembelian — bukan kegagalan yang
/// perlu ditampilkan sebagai error.
class SubscriptionCancelled implements Exception {
  const SubscriptionCancelled();
}

/// Menyembunyikan tipe-tipe `purchases_flutter` dari sisa aplikasi — pola
/// sama seperti `NotificationSender`/`BiometricAuthenticator`.
abstract interface class SubscriptionStatus {
  /// Status premium terkini, dan tiap kali berubah (beli/kedaluwarsa/dipulihkan).
  Stream<bool> watchIsPremium();

  /// Sama seperti [watchIsPremium] tapi untuk tingkat Ultimate.
  Stream<bool> watchIsUltimate();

  /// ID pengguna RevenueCat (anonim), dipakai backend untuk memverifikasi
  /// hak akses Ultimate. Null bila SDK belum siap.
  Future<String?> appUserId();

  /// ID produk langganan yang sedang aktif (mis. `dompetku_premium`), atau null
  /// bila tidak ada atau SDK belum siap. Dipakai untuk menggantikan langganan
  /// Premium saat upgrade ke Ultimate.
  Future<String?> activeSubscriptionProductId();
  Future<List<SubscriptionPackage>> fetchPackages();
  Future<void> purchase(SubscriptionPackage package);
  Future<void> restorePurchases();
}

/// SDK RevenueCat menampilkan dialog "Wrong API Key" lalu MENUTUP aplikasi bila
/// kunci Test Store (`test_...`) dipakai di build rilis. Jadi di rilis, kunci
/// `test_` tidak boleh dikonfigurasi; app tetap jalan dengan premium = false
/// sampai kunci `goog_...` sungguhan dipasang.
bool shouldConfigureRevenueCat(String apiKey, {required bool isRelease}) =>
    !(isRelease && apiKey.startsWith('test_'));

class RevenueCatSubscriptionStatus implements SubscriptionStatus {
  static bool _configured = false;

  /// Dipanggil sekali dari main.dart, sebelum runApp — status premium
  /// (kalau ada) perlu siap sebelum frame pertama HomeShell, beda dengan SDK
  /// iklan yang sengaja lazy (lihat lib/features/ads/banner_ad_widget.dart).
  /// Gagal (mis. API key placeholder, tanpa jaringan) TIDAK melempar —
  /// ditangkap dan dicatat saja, app tetap jalan normal dengan status
  /// premium selalu false (pola sama _StartupGate: gagal baca status jangan
  /// blokir pemakaian).
  static Future<void> configureOnce() async {
    if (_configured) return;
    if (!shouldConfigureRevenueCat(
      kRevenueCatApiKey,
      isRelease: kReleaseMode,
    )) {
      debugPrint(
        'RevenueCat dilewati: kunci Test Store tidak boleh dipakai di build '
        'rilis (SDK menutup aplikasi). Status premium tetap false.',
      );
      return;
    }
    try {
      await Purchases.configure(PurchasesConfiguration(kRevenueCatApiKey));
      _configured = true;
    } catch (e) {
      debugPrint('Gagal configure RevenueCat (API key placeholder?): $e');
    }
  }

  @override
  Stream<bool> watchIsPremium() => _watchEntitlement(kPremiumEntitlementId);

  @override
  Stream<bool> watchIsUltimate() => _watchEntitlement(kUltimateEntitlementId);

  @override
  Future<String?> appUserId() async {
    if (!_configured) return null;
    try {
      return await Purchases.appUserID;
    } catch (_) {
      return null;
    }
  }

  Stream<bool> _watchEntitlement(String entitlementId) async* {
    if (!_configured) {
      yield false;
      return;
    }
    // Status awal aman sebelum listener pertama terpanggil (native butuh
    // waktu mengirim CustomerInfo pertama; tanpa ini provider bisa
    // menggantung menunggu nilai pertama tak terhingga).
    yield false;

    final controller = StreamController<bool>();
    void listener(CustomerInfo info) {
      controller.add(info.entitlements.active.containsKey(entitlementId));
    }

    Purchases.addCustomerInfoUpdateListener(listener);
    controller.onCancel = () =>
        Purchases.removeCustomerInfoUpdateListener(listener);
    yield* controller.stream;
  }

  @override
  Future<List<SubscriptionPackage>> fetchPackages() async {
    if (!_configured) {
      throw const SubscriptionException(
        'Layanan langganan belum siap. Coba lagi nanti.',
      );
    }
    try {
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? const [];
      return [for (final p in packages) ?_toPackage(p)];
    } catch (e) {
      throw const SubscriptionException(
        'Gagal memuat paket langganan. Periksa koneksi internet Anda.',
      );
    }
  }

  /// Paket di luar bulanan/tahunan diabaikan — halaman langganan hanya
  /// menawarkan dua periode itu.
  static SubscriptionPackage? _toPackage(Package p) {
    final key = '${p.identifier} ${p.storeProduct.identifier}'.toLowerCase();
    final tier = key.contains('ultimate')
        ? SubscriptionTier.ultimate
        : SubscriptionTier.premium;
    final SubscriptionPeriod period;
    if (p.packageType == PackageType.annual ||
        key.contains('year') ||
        key.contains('annual') ||
        key.contains('tahun')) {
      period = SubscriptionPeriod.yearly;
    } else if (p.packageType == PackageType.monthly ||
        key.contains('month') ||
        key.contains('bulan')) {
      period = SubscriptionPeriod.monthly;
    } else {
      return null;
    }
    final product = p.storeProduct;
    final isIdr = product.currencyCode.toUpperCase() == 'IDR';
    final amount = isIdr ? product.price.round() : null;
    final expected = kReferencePrices[(tier, period)];
    if (amount != null && amount != expected) {
      debugPrint(
        'Harga ${tier.label} ${period.label} di toko Rp$amount, '
        'seharusnya Rp$expected — periksa Play Console/RevenueCat.',
      );
    }
    return SubscriptionPackage(
      id: p.identifier,
      tier: tier,
      period: period,
      priceLabel: amount != null ? rupiah(amount) : product.priceString,
      amount: amount,
      native: p,
    );
  }

  @override
  Future<void> purchase(SubscriptionPackage package) async {
    final native = package.native;
    if (native is! Package) {
      throw const SubscriptionException('Paket tidak valid untuk dibeli.');
    }
    try {
      final change = await _productChangeFor(package);
      final result = await Purchases.purchase(
        PurchaseParams.package(native, productChangeInfo: change),
      );
      await _waitForEntitlement(package.tier, result.customerInfo);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw const SubscriptionCancelled();
      }
      throw const SubscriptionException('Pembelian gagal. Coba lagi nanti.');
    }
  }

  /// Setelah pembelian (terutama penggantian Premium -> Ultimate), Play dan
  /// RevenueCat kadang butuh beberapa detik sebelum entitlement baru muncul,
  /// sehingga layar sempat menampilkan paket lama padahal pembelian sudah
  /// selesai. Tunggu (maks. ±10 detik) sampai entitlement paket yang dibeli
  /// aktif; bila belum juga, lanjut saja: pembaruan berikutnya tetap sampai
  /// lewat listener CustomerInfo.
  Future<void> _waitForEntitlement(
    SubscriptionTier tier,
    CustomerInfo purchased,
  ) async {
    final id = tier == SubscriptionTier.ultimate
        ? kUltimateEntitlementId
        : kPremiumEntitlementId;
    if (purchased.entitlements.active.containsKey(id)) return;
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        await Purchases.invalidateCustomerInfoCache();
        final info = await Purchases.getCustomerInfo();
        if (info.entitlements.active.containsKey(id)) return;
      } catch (_) {
        // Coba lagi pada putaran berikutnya.
      }
    }
  }

  /// Membaca langganan yang sedang aktif dari RevenueCat: tingkatnya dan ID
  /// produk yang dipegang entitlement `premium`. Null bila SDK belum siap
  /// atau gagal dibaca (pembelian lanjut tanpa penggantian).
  Future<({ActiveTier tier, String? productId})?> _activeSubscription() async {
    if (!_configured) return null;
    try {
      final active = (await Purchases.getCustomerInfo()).entitlements.active;
      final premium = active[kPremiumEntitlementId];
      return (
        tier: ActiveTier.of(
          premium: premium != null,
          ultimate: active.containsKey(kUltimateEntitlementId),
        ),
        productId: premium?.productIdentifier,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> activeSubscriptionProductId() async =>
      (await _activeSubscription())?.productId;

  /// Bila pengguna Premium membeli Ultimate, langganan Premium digantikan
  /// (dibayar selisih untuk sisa siklus) supaya tidak ada dua langganan.
  /// ID produk lama yang benar untuk Google Play (ID langganan atau
  /// `langganan:base-plan`) HARUS diverifikasi di perangkat; hasilnya dicatat
  /// di docs/RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md §8.
  Future<StoreProductChangeInfo?> _productChangeFor(
    SubscriptionPackage package,
  ) async {
    final current = await _activeSubscription();
    final oldId = current?.productId;
    if (current == null ||
        oldId == null ||
        !shouldReplaceProduct(active: current.tier, target: package.tier)) {
      return null;
    }
    return StoreProductChangeInfo(
      oldId,
      replacementMode: StoreReplacementMode.chargeProratedPrice,
    );
  }

  @override
  Future<void> restorePurchases() async {
    if (!_configured) {
      throw const SubscriptionException('Layanan langganan belum siap.');
    }
    try {
      await Purchases.restorePurchases();
    } catch (e) {
      throw const SubscriptionException(
        'Gagal memulihkan pembelian. Periksa koneksi internet Anda.',
      );
    }
  }
}
