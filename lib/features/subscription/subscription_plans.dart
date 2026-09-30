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
