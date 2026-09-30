/// API key publik RevenueCat (aman ditaruh di kode, bukan rahasia seperti
/// keystore). Ini kunci **RevenueCat Test Store** (prefix `test_`) — dipakai
/// sementara untuk integrasi SDK sebelum produk Play Console + Offering
/// sungguhan dihubungkan. GANTI dengan kunci `goog_...` dari dashboard
/// RevenueCat begitu itu selesai (lihat docs/CHECKLIST-REVENUECAT-ADMOB.md).
const kRevenueCatApiKey = 'test_bCDAonmzHgrAqFLIhMUTjIqigAg';

/// ID entitlement di dashboard RevenueCat yang menandai "premium aktif".
/// GANTI kalau Anda memberi nama entitlement berbeda di dashboard.
const kPremiumEntitlementId = 'premium';

/// Entitlement tingkat Ultimate. Produk Ultimate di dashboard RevenueCat
/// dikaitkan ke DUA entitlement (`premium` dan `ultimate`), jadi semua gate
/// premium yang ada otomatis terbuka untuk pengguna Ultimate.
const kUltimateEntitlementId = 'ultimate';
