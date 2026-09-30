# Checklist Setup RevenueCat + AdMob (akun sungguhan)

> Dibuat 2026-09-27. Next step yang diputuskan pemilik setelah
> [GAP-ANALISA-2026-09-24.md](GAP-ANALISA-2026-09-24.md) §8 — ganti `kRevenueCatApiKey` dan ID uji AdMob dengan
> akun sungguhan sebelum rilis. Centang tiap butir seiring progres; dokumen ini dimaksudkan untuk dicoret-coret
> lintas sesi, bukan snapshot sekali tulis seperti dokumen `CATATAN-SESI-*`/`GAP-ANALISA-*` lainnya.

Dibagi 2 kelompok: yang **harus dikerjakan pemilik sendiri** (akun, dashboard, uang — Claude tidak boleh dan tidak
bisa melakukan ini), dan yang **Claude bantu di kode** setelah ID-ID dari dashboard sudah ada.

## Urutan yang disarankan (ada dependensi)

AdMob independen, bisa langsung dikerjakan kapan saja. RevenueCat butuh Play Console app + produk langganan
**sudah ada** sebelum bisa dihubungkan — jadi bagian 3 harus selesai dulu sebelum bagian 4.

## 1. AdMob (bisa mulai sekarang, tidak ada dependensi)

- [x] Daftar/masuk akun di [admob.google.com](https://admob.google.com)
- [x] Tambah app baru → platform **Android**, package `com.hardanti.lacipintar` — **status: dalam review Google**
      sejak 2026-09-28 (App ID/Ad Unit ID sudah bisa diambil walau review belum selesai; iklan yang tampil
      mungkin masih terbatas sampai review kelar)
- [x] Buat Ad Unit format **Banner**
- [x] Catat App ID (`ca-app-pub-7333479614271728~5481989947`) dan Ad Unit ID
      (`ca-app-pub-7333479614271728/3640537078`) — diterima 2026-09-28, sudah ditulis ke kode (lihat bagian 5)

## 2. Keputusan harga langganan (blocker untuk bagian 3)

- [x] **Harga final, diputuskan 2026-09-29** — sekarang **2 tier** (bukan 1), menyusul keputusan menambah tier
      Ultimate saat merencanakan fitur OCR (lihat
      [RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md](RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md)):
      - **Premium: Rp 7.500/bulan, Rp 75.000/tahun**
      - **Ultimate: Rp 12.500/bulan, Rp 125.000/tahun**
      (Angka tahunan diasumsikan rasio 10x bulanan/diskon ~17%, konsisten dengan pola harga sebelumnya — belum
      dikonfirmasi eksplisit oleh pemilik, cek ulang sebelum submit ke Play Console.)
      Riwayat revisi harga sebelum tier Ultimate ada: mulai Rp 7.500/75.000 (tier tunggal) → naik ke
      Rp 10.000/100.000 → naik lagi ke Rp 12.500/125.000 (dicek vs Rekapin Rp 15rb/bulan) → **setelah tier
      Ultimate ditambahkan, Premium turun lagi ke Rp 7.500/75.000 dan angka Rp 12.500/125.000 dipindah jadi
      harga Ultimate**. Tidak ada perubahan kode untuk harga: `SubscriptionPage` menampilkan `priceLabel`
      langsung dari RevenueCat/Play Store
      ([lib/features/subscription/subscription_page.dart:106](../lib/features/subscription/subscription_page.dart#L106)).

## 3. Play Console (dibutuhkan RevenueCat, sekalian menyentuh P2 jalur rilis)

- [ ] Buat aplikasi baru di Play Console dengan package `com.hardanti.lacipintar` (kalau belum ada)
- [ ] `flutter build appbundle` (AAB, bukan APK) dengan keystore rilis yang sudah ada
      (`android/app/upload-keystore.jks`), upload ke track **Internal testing**
- [ ] Monetize → Products → Subscriptions: buat **4 produk** (2 tier × 2 periode) dengan harga dari bagian 2 —
      misal `dompetku_premium_monthly`, `dompetku_premium_yearly`, `dompetku_ultimate_monthly`,
      `dompetku_ultimate_yearly`
- [ ] Setup → License testing: tambahkan email Google sendiri sebagai tester (supaya bisa uji beli tanpa kena
      tagih sungguhan)

## 4. RevenueCat

- [x] Daftar akun di [app.revenuecat.com](https://app.revenuecat.com)
- [x] Buat Project → tambah App Android, package `com.hardanti.lacipintar`
- [x] Ambil API Key dari halaman "Install SDK" — **tapi ini kunci RevenueCat Test Store** (prefix `test_`,
      bukan `goog_`), diberikan otomatis sebelum Play Console dihubungkan. Sudah ditulis ke kode (bagian 5)
      supaya SDK bisa diuji sekarang; **HARUS diganti lagi** ke kunci `goog_...` begitu 2 butir di bawah selesai
- [ ] Hubungkan ke Play Console: butuh **service account JSON** (dibuat dari Play Console → API access), diberi
      izin "View financial data" + "Manage orders and subscriptions" — RevenueCat punya panduan langkah-demi-
      langkah untuk ini di dashboard-nya. **Masih proses** (2026-09-28) — bergantung bagian 3 (Play Console)
      yang belum dimulai
- [ ] Import 4 produk langganan yang dibuat di bagian 3
- [ ] Buat **Entitlement `premium`** — kode sudah hardcode ini di
      [lib/features/subscription/revenuecat_config.dart:11](../lib/features/subscription/revenuecat_config.dart#L11)
      (`kPremiumEntitlementId`); kalau dashboard pakai nama lain, konstanta ini perlu disesuaikan
- [ ] Buat **Entitlement `ultimate`** (baru, untuk fitur ekstraksi AI — lihat
      [RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md §3.1](RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md)) — kode
      `kUltimateEntitlementId`/`isUltimateProvider` belum ditulis, baru rencana
- [ ] **Kaitkan 2 produk `ultimate_*` ke DUA entitlement sekaligus** (`premium` DAN `ultimate`) — supaya
      pengguna Ultimate otomatis lolos semua gate `isPremiumProvider` yang sudah ada, tanpa perlu ubah kode di
      fitur-fitur premium lama. Produk `premium_*` cuma dikaitkan ke entitlement `premium` saja.
- [ ] Buat **Offering** (default/current) berisi package untuk keempat produk di atas — sampai ini selesai,
      `fetchPackages()` di app akan tetap kosong (SDK tersambung, tapi belum ada paket untuk dijual)
- [x] Ambil **Public API Key** (Android) — lihat catatan Test Store di atas, ini bukan kunci final

## 5. Yang Claude kerjakan setelah semua ID di atas ada

- [x] Ganti `kBannerAdUnitId` di
      [lib/features/ads/ad_unit_ids.dart:7](../lib/features/ads/ad_unit_ids.dart#L7) — **selesai 2026-09-28**
- [x] Ganti `com.google.android.gms.ads.APPLICATION_ID` di
      [android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) — **selesai
      2026-09-28**
- [x] Ganti `kRevenueCatApiKey` di
      [lib/features/subscription/revenuecat_config.dart:6](../lib/features/subscription/revenuecat_config.dart#L6)
      — **selesai 2026-09-28**, pakai kunci Test Store sementara (lihat catatan bagian 4)
- [x] `flutter analyze` + `flutter test` penuh — **357 tes lolos, analyze bersih** (2026-09-28)
- [ ] Build AAB/APK baru, sanity-check merged manifest punya `com.android.vending.BILLING` (otomatis dari Play
      Billing library, tinggal dipastikan) — belum dilakukan
- [ ] Verifikasi di HP: banner ad tampil (mungkin terbatas selama AdMob masih review), `Purchases.configure()`
      sukses dengan kunci Test Store. Alur beli langganan sungguhan **belum bisa diuji** — menunggu Offering
      (bagian 4) dan license tester (bagian 3)
- [ ] Setelah bagian 3 + sisa bagian 4 selesai: ganti `kRevenueCatApiKey` SEKALI LAGI ke kunci `goog_...`,
      ulangi verifikasi di atas dengan alur beli sungguhan (pakai akun license tester)

Claude tidak bisa membuat akun, mengisi info pembayaran, atau submit apa pun ke Play Console/AdMob/RevenueCat
atas nama pemilik — bagian 1–4 murni tugas pemilik. Bagian 5 sudah dikerjakan sejauh ID yang tersedia
mengizinkan; sisanya menunggu bagian 3 (Play Console) dan sisa bagian 4 (Offering RevenueCat) selesai.
