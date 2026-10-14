enum SubscriptionTier {
  premium('Premium'),
  ultimate('Ultimate');

  const SubscriptionTier(this.label);
  final String label;
}

enum SubscriptionPeriod {
  monthly('Bulanan', 'bulan'),
  yearly('Tahunan', 'tahun');

  const SubscriptionPeriod(this.label, this.unit);
  final String label;
  final String unit;
}

/// Harga resmi (Rupiah) yang HARUS dikonfigurasi di Play Console/RevenueCat.
/// Yang ditampilkan ke pengguna tetap harga dari toko (itu yang benar-benar
/// ditagihkan); tabel ini dipakai untuk teks statis (mis. "mulai Rp ...") dan
/// untuk mendeteksi salah konfigurasi harga di toko.
const Map<(SubscriptionTier, SubscriptionPeriod), int> kReferencePrices = {
  (SubscriptionTier.premium, SubscriptionPeriod.monthly): 7500,
  (SubscriptionTier.premium, SubscriptionPeriod.yearly): 75000,
  (SubscriptionTier.ultimate, SubscriptionPeriod.monthly): 12500,
  (SubscriptionTier.ultimate, SubscriptionPeriod.yearly): 125000,
};

/// Hemat berapa persen dibanding membayar bulanan 12 kali.
int yearlySavingsPercent({required int monthly, required int yearly}) {
  final full = monthly * 12;
  if (full <= 0 || yearly >= full) return 0;
  return ((full - yearly) / full * 100).round();
}

/// Tingkat langganan pengguna saat ini (bukan tingkat yang dijual, lihat
/// [SubscriptionTier]). Ultimate juga memegang entitlement `premium`
/// (lihat revenuecat_config.dart), jadi urutannya diperiksa dari yang tertinggi.
enum ActiveTier {
  free,
  premium,
  ultimate;

  static ActiveTier of({required bool premium, required bool ultimate}) =>
      ultimate
      ? ActiveTier.ultimate
      : premium
      ? ActiveTier.premium
      : ActiveTier.free;
}

/// Apakah membeli paket [target] harus MENGGANTIKAN langganan yang sedang
/// aktif. Premium dan Ultimate adalah dua langganan Play yang berbeda; tanpa
/// penggantian, pelanggan Premium yang membeli Ultimate ditagih dua langganan
/// sekaligus. Beralih ke tingkat yang sama atau lebih rendah tidak lewat
/// aplikasi (arahkan ke Kelola di Play Store).
bool shouldReplaceProduct({
  required ActiveTier active,
  required SubscriptionTier target,
}) => active == ActiveTier.premium && target == SubscriptionTier.ultimate;

/// Satu entitlement aktif, lepas dari SDK (mudah diuji).
class ActiveEntitlement {
  const ActiveEntitlement({
    required this.id,
    required this.productId,
    required this.promotional,
    this.expiresAt,
  });

  /// ID entitlement (`premium` / `ultimate`).
  final String id;
  final String productId;

  /// Hibah promosional RevenueCat (uji coba), bukan pembelian di Play.
  final bool promotional;
  final DateTime? expiresAt;
}

/// Satu langganan/produk aktif, lepas dari SDK.
class ActiveSubscription {
  const ActiveSubscription({
    required this.productId,
    required this.promotional,
    this.expiresAt,
  });

  final String productId;
  final bool promotional;
  final DateTime? expiresAt;
}

/// Hak akses pengguna dipisah menurut SUMBERNYA (rencana trial Ultimate,
/// docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 5.2):
///
///  - *tier akses* (membuka fitur) boleh memasukkan hibah uji coba, dan itu
///    tetap berasal dari `watchIsPremium`/`watchIsUltimate`;
///  - *tier berbayar* ([paidTier], [paidProductId]) HANYA dari pembelian di toko.
///    Inilah yang menentukan tombol beli, tampilan "Kelola langganan", dan
///    penggantian produk Play. Bila uji coba ikut dihitung, pelanggan Premium
///    yang sedang trial Ultimate lalu membeli Ultimate TIDAK akan menggantikan
///    langganan Premium-nya, sehingga tertagih dua langganan sekaligus.
class SubscriptionDetail {
  const SubscriptionDetail({
    required this.paidTier,
    this.paidProductId,
    this.trialEndsAt,
  });

  static const free = SubscriptionDetail(paidTier: ActiveTier.free);

  /// Tingkat dari langganan berbayar saja.
  final ActiveTier paidTier;

  /// ID produk langganan berbayar aktif (untuk penggantian produk Play).
  final String? paidProductId;

  /// Kedaluwarsa uji coba Ultimate yang sedang berjalan; null bila tidak ada
  /// uji coba, atau pengguna sudah berlangganan Ultimate (uji coba tak berarti).
  final DateTime? trialEndsAt;

  bool get onTrial => trialEndsAt != null;
}

bool _isUltimateProduct(String productId) =>
    productId.toLowerCase().contains('ultimate');

/// Menurunkan [SubscriptionDetail] dari entitlement dan langganan aktif.
///
/// Dua sumber dipakai bersamaan karena RevenueCat memetakan entitlement ke
/// produk dengan kedaluwarsa terpanjang: hibah uji coba yang berakhir LEBIH
/// LAMA daripada langganan berbayar menyamarkan langganan itu pada objek
/// entitlement, sehingga daftar langganan aktif diperiksa juga.
SubscriptionDetail subscriptionDetailOf({
  required Iterable<ActiveEntitlement> entitlements,
  required Iterable<ActiveSubscription> subscriptions,
  String premiumEntitlementId = 'premium',
  String ultimateEntitlementId = 'ultimate',
}) {
  var paid = ActiveTier.free;
  void raise(ActiveTier t) {
    if (t.index > paid.index) paid = t;
  }

  for (final e in entitlements) {
    if (e.promotional) continue;
    if (e.id == ultimateEntitlementId) raise(ActiveTier.ultimate);
    if (e.id == premiumEntitlementId) raise(ActiveTier.premium);
  }
  for (final s in subscriptions) {
    if (s.promotional) continue;
    raise(
      _isUltimateProduct(s.productId)
          ? ActiveTier.ultimate
          : ActiveTier.premium,
    );
  }

  // ID produk berbayar yang dipegang tier berbayar tertinggi. Entitlement
  // `premium` lebih dulu (perilaku yang sudah terverifikasi), langganan sebagai cadangan.
  String? productId;
  if (paid != ActiveTier.free) {
    for (final e in entitlements) {
      final matches = paid == ActiveTier.ultimate
          ? e.id == ultimateEntitlementId
          : e.id == premiumEntitlementId;
      if (!e.promotional && matches) {
        productId = e.productId;
        break;
      }
    }
    productId ??= subscriptions
        .where(
          (s) =>
              !s.promotional &&
              (paid == ActiveTier.ultimate) == _isUltimateProduct(s.productId),
        )
        .map((s) => s.productId)
        .firstOrNull;
  }

  DateTime? trialEndsAt;
  if (paid != ActiveTier.ultimate) {
    final ends = <DateTime>[
      for (final e in entitlements)
        if (e.promotional &&
            e.id == ultimateEntitlementId &&
            e.expiresAt != null)
          e.expiresAt!,
      for (final s in subscriptions)
        if (s.promotional &&
            _isUltimateProduct(s.productId) &&
            s.expiresAt != null)
          s.expiresAt!,
    ];
    if (ends.isNotEmpty) {
      trialEndsAt = ends.reduce((a, b) => a.isAfter(b) ? a : b);
    }
  }

  return SubscriptionDetail(
    paidTier: paid,
    paidProductId: productId,
    trialEndsAt: trialEndsAt,
  );
}

/// ID produk langganan lama yang harus digantikan saat membeli [target], atau
/// null bila pembelian biasa. Hanya tier BERBAYAR yang dipertimbangkan.
String? productToReplace({
  required SubscriptionDetail detail,
  required SubscriptionTier target,
}) {
  if (!shouldReplaceProduct(active: detail.paidTier, target: target)) {
    return null;
  }
  return detail.paidProductId;
}

/// Apakah tier berbayar sudah memenuhi paket [target] yang baru dibeli.
bool paidTierSatisfies(ActiveTier paid, SubscriptionTier target) =>
    paid.index >= (target == SubscriptionTier.ultimate ? 2 : 1);
