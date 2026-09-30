/// API key publik RevenueCat untuk Android/Google Play (aman ditaruh di kode,
/// bukan rahasia seperti keystore). Kunci produksi `goog_...` dari dashboard
/// RevenueCat -> DompetKu (Play Store) -> API keys. Sebelumnya memakai kunci
/// Test Store (`test_...`) yang membuat SDK menutup app di build rilis.
const kRevenueCatApiKey = 'goog_cXVEjdyMBAiGLjGdPWPcDAJwGWo';

/// ID entitlement di dashboard RevenueCat yang menandai "premium aktif".
/// GANTI kalau Anda memberi nama entitlement berbeda di dashboard.
const kPremiumEntitlementId = 'premium';

/// Entitlement tingkat Ultimate. Produk Ultimate di dashboard RevenueCat
/// dikaitkan ke DUA entitlement (`premium` dan `ultimate`), jadi semua gate
/// premium yang ada otomatis terbuka untuk pengguna Ultimate.
const kUltimateEntitlementId = 'ultimate';
