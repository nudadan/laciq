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
  ///
  /// Kedua stream di atas adalah HAK AKSES: hibah uji coba ikut dihitung.
  /// Untuk keputusan pembelian dan tampilan langganan pakai [watchDetail].
  Stream<bool> watchIsUltimate();

  /// Rincian menurut sumber: tingkat BERBAYAR (hanya pembelian di toko), ID
  /// produk berbayarnya, dan kedaluwarsa uji coba Ultimate bila ada. Lihat
  /// [SubscriptionDetail] untuk alasan pemisahan ini.
  Stream<SubscriptionDetail> watchDetail();

  /// ID pengguna RevenueCat (anonim), dipakai backend untuk memverifikasi
  /// hak akses Ultimate. Null bila SDK belum siap.
  Future<String?> appUserId();

  /// ID produk langganan BERBAYAR yang sedang aktif (mis. `dompetku_premium`),
  /// atau null bila tidak ada atau SDK belum siap. Hibah uji coba tidak
  /// dihitung. Dipakai untuk menggantikan langganan Premium saat upgrade ke
  /// Ultimate.
  Future<String?> activeSubscriptionProductId();
  Future<List<SubscriptionPackage>> fetchPackages();
  Future<void> purchase(SubscriptionPackage package);

  /// Memulihkan pembelian dari Google Play lalu mengembalikan true bila SESUDAH
  /// itu ada langganan (Premium/Ultimate) yang aktif untuk ID pengguna ini.
  /// False = tidak ada yang bisa dipulihkan; pemanggil TIDAK boleh mengklaim
  /// "dipulihkan".
  Future<bool> restorePurchases();
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
  Stream<SubscriptionDetail> watchDetail() =>
      _watchInfo(SubscriptionDetail.free, _detailOf);

  /// Memetakan CustomerInfo ke [SubscriptionDetail]. Hibah uji coba dikenali
  /// dari `store == promotional`.
  static SubscriptionDetail _detailOf(CustomerInfo info) {
    return subscriptionDetailOf(
      premiumEntitlementId: kPremiumEntitlementId,
      ultimateEntitlementId: kUltimateEntitlementId,
      entitlements: [
        for (final e in info.entitlements.active.values)
          ActiveEntitlement(
            id: e.identifier,
            productId: e.productIdentifier,
            promotional: e.store == Store.promotional,
            expiresAt: DateTime.tryParse(e.expirationDate ?? ''),
          ),
      ],
      subscriptions: [
        for (final s in info.subscriptionsByProductIdentifier.values)
          if (s.isActive)
            ActiveSubscription(
              productId: s.productIdentifier,
              promotional: s.store == Store.promotional,
              expiresAt: DateTime.tryParse(s.expiresDate ?? ''),
            ),
      ],
    );
  }

  @override
  Future<String?> appUserId() async {
    if (!_configured) return null;
    try {
      return await Purchases.appUserID;
    } catch (_) {
      return null;
    }
  }

  /// Kabar CustomerInfo yang kita dorong sendiri (setelah beli/pulihkan), di
  /// samping pemberitahuan plugin: status tidak boleh bergantung hanya pada
  /// plugin mengirim ulang info yang sama.
  static final _pushedInfo = StreamController<CustomerInfo>.broadcast();

  Stream<bool> _watchEntitlement(String entitlementId) => _watchInfo(
    false,
    (info) => info.entitlements.active.containsKey(entitlementId),
  );

  /// Memantau CustomerInfo dan memetakannya dengan [map]. [initial] dikirim
  /// lebih dulu supaya provider tidak menggantung menunggu nilai pertama.
  Stream<T> _watchInfo<T>(T initial, T Function(CustomerInfo) map) async* {
    if (!_configured) {
      yield initial;
      return;
    }
    // Status awal aman sebelum info pertama datang (native butuh waktu; tanpa
    // ini provider bisa menggantung menunggu nilai pertama tak terhingga).
    yield initial;

    final controller = StreamController<T>();
    void listener(CustomerInfo info) {
      if (!controller.isClosed) controller.add(map(info));
    }

    Purchases.addCustomerInfoUpdateListener(listener);
    final pushed = _pushedInfo.stream.listen(listener);
    // Ambil status secara eksplisit juga, jangan hanya menunggu pemberitahuan.
    unawaited(Purchases.getCustomerInfo().then(listener, onError: (_) {}));
    controller.onCancel = () {
      Purchases.removeCustomerInfoUpdateListener(listener);
      pushed.cancel();
    };
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
      await _pushLatestInfo();
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
    // Yang ditunggu adalah pembelian BERBAYAR: hibah uji coba yang sudah aktif
    // tidak boleh membuat penantian berhenti sebelum pembelian tercatat.
    bool bought(CustomerInfo info) =>
        paidTierSatisfies(_detailOf(info).paidTier, tier);
    if (bought(purchased)) return;
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        await Purchases.invalidateCustomerInfoCache();
        final info = await Purchases.getCustomerInfo();
        if (bought(info)) return;
      } catch (_) {
        // Coba lagi pada putaran berikutnya.
      }
    }
  }

  /// Membaca langganan BERBAYAR yang sedang aktif dari RevenueCat. Hibah uji
  /// coba tidak dihitung (lihat [SubscriptionDetail]). Null bila SDK belum siap
  /// atau gagal dibaca (pembelian lanjut tanpa penggantian).
  Future<SubscriptionDetail?> _activeSubscription() async {
    if (!_configured) return null;
    try {
      return _detailOf(await Purchases.getCustomerInfo());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> activeSubscriptionProductId() async =>
      (await _activeSubscription())?.paidProductId;

  /// Bila pengguna Premium membeli Ultimate, langganan Premium digantikan
  /// (dibayar selisih untuk sisa siklus) supaya tidak ada dua langganan.
  /// ID produk lama yang benar untuk Google Play (ID langganan atau
  /// `langganan:base-plan`) HARUS diverifikasi di perangkat; hasilnya dicatat
  /// di docs/RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md §8.
  Future<StoreProductChangeInfo?> _productChangeFor(
    SubscriptionPackage package,
  ) async {
    final current = await _activeSubscription();
    final oldId = current == null
        ? null
        : productToReplace(detail: current, target: package.tier);
    if (oldId == null) return null;
    return StoreProductChangeInfo(
      oldId,
      replacementMode: StoreReplacementMode.chargeProratedPrice,
    );
  }

  /// Memaksa info terbaru dari server (bukan cache) lalu mendorongnya ke
  /// semua pengamat status. Gagal = diam.
  Future<CustomerInfo?> _pushLatestInfo() async {
    try {
      await Purchases.invalidateCustomerInfoCache();
      final info = await Purchases.getCustomerInfo();
      _pushedInfo.add(info);
      return info;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> restorePurchases() async {
    if (!_configured) {
      throw const SubscriptionException('Layanan langganan belum siap.');
    }
    final CustomerInfo restored;
    try {
      restored = await Purchases.restorePurchases();
    } catch (e) {
      throw const SubscriptionException(
        'Gagal memulihkan pembelian. Periksa koneksi internet Anda.',
      );
    }
    _pushedInfo.add(restored);
    // Info dari restore bisa kosong walau server sudah tahu; cek sekali lagi
    // langsung ke server sebelum menyimpulkan tidak ada langganan.
    final fresh = await _pushLatestInfo() ?? restored;
    // Hanya langganan berbayar yang dihitung "dipulihkan"; hibah uji coba tidak.
    return _detailOf(fresh).paidTier != ActiveTier.free;
  }
}
