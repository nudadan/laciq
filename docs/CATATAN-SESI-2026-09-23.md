# Catatan Sesi — DompetKu (23 September 2026)

Rekaman informasi kunci dari sesi hari ini: keputusan beserta alasannya, status, bug & pelajaran, dan hal yang
masih terbuka. Sesi ini fokus ke **monetisasi** (iklan, langganan, backup cloud) dan **jalur rilis P0**
(kebijakan privasi, setup Google Cloud Console). Lanjutan dari `docs/CATATAN-SESI-2026-09-21.md` — status app
saat itu: MVP lengkap, skema v4, jalur rilis baru signing+hapus-data yang selesai. Gap analisa awal sesi ini ada
di `docs/GAP-ANALISA-2026-09-23.md` (ditulis SEBELUM fitur monetisasi di bawah dibangun — sudah agak usang untuk
bagian monetisasi, catatan ini yang jadi rujukan terkini).

---

## 1. Ringkasan

Tiga fitur monetisasi dibangun dari nol sampai **terverifikasi sungguhan di HP dengan akun nyata**: iklan tier
gratis, langganan Premium (RevenueCat), dan backup cloud terenkripsi (Google Drive, pola WhatsApp). Kebijakan
privasi direvisi tiga kali mengikuti tiap fitur. Setup Google Cloud Console untuk Google Sign-In selesai
(termasuk satu koreksi penting yang baru ketahuan saat uji nyata — lihat bagian 4). 268 tes lolos (dari 253 di
awal sesi), analyzer bersih di sepanjang sesi.

## 2. Keputusan monetisasi & arsitektur (beserta alasan)

| Keputusan | Alasan |
|---|---|
| **Iklan (Google AdMob)** untuk tier gratis, masa tenggang 15 hari sejak pemakaian pertama | Permintaan pemilik; SDK iklan sengaja **lazy-init** (baru `initialize()` saat iklan benar-benar akan tampil) supaya masa tenggang juga bebas jaringan, bukan cuma bebas tampilan |
| **RevenueCat** untuk verifikasi pembelian langganan, bukan kode server sendiri | Solo developer — hindari menulis+menjaga verifikasi Play Billing sendiri (perbandingan trade-off Supabase vs Firebase vs RevenueCat dibahas eksplisit dengan pemilik) |
| RevenueCat **eager-init** di `main.dart` (beda dari iklan) | Status premium harus diketahui SEBELUM frame pertama, supaya pelanggan tidak sempat melihat iklan sama sekali |
| Backup cloud: **PIVOT dari Supabase ke Google Drive** milik pengguna sendiri, pola WhatsApp | Ide datang dari pemilik di tengah sesi. Implementasi Supabase sempat selesai dibangun (Auth email+OTP, Storage `appDataFolder`-setara lewat bucket+RLS) tapi macet loading spinner tak terjelaskan saat verifikasi — dibuang total, bukan didiagnosis lebih lanjut, karena Drive ternyata solusi yang lebih sederhana DAN klaim privasinya lebih kuat |
| Kunci enkripsi backup **ikut tersimpan di Drive yang sama** (bukan kode pemulihan manual E2E) | Konsisten dengan preferensi pemilik yang sudah terlihat lebih awal: pengguna lupa kode pemulihan tidak boleh berarti kehilangan data selamanya. Klaim kebijakan privasi karenanya "terenkripsi saat disimpan", BUKAN "zero-knowledge" |
| Backup cloud **lazy-init** (beda dari RevenueCat) | Fitur opt-in, hanya disentuh dari Pengaturan — tidak ada yang bergantung padanya sebelum frame pertama |
| Backend cloud backup: `appDataFolder` Drive, BUKAN tabel SQL/RLS terpisah | `storage.objects`-setara di Drive (folder tersembunyi per-app-per-user) sudah otomatis privat; tidak perlu infrastruktur server sendiri sama sekali |
| Tidak pakai paket jembatan `extension_google_sign_in_as_googleapis_auth` | Ada laporan GitHub soal ketidakcocokan dengan `google_sign_in` v7; ditulis sendiri `http.BaseClient` kecil (~15 baris) yang menyuntik `authorizationHeaders()` — lebih mudah dilacak |
| Penegakan status Premium **hanya di sisi klien** (untuk iklan maupun backup cloud) | Sinkronisasi RevenueCat→server sendiri untuk penegakan sisi-server adalah fitur terpisah, belum dikerjakan — dicatat eksplisit sebagai lubang yang diketahui, bukan kelalaian |

## 3. Status fitur baru (semua terverifikasi di HP)

- **Iklan tier gratis** (`lib/features/ads/`): `AdEligibilityService` (murni Dart, testable), `HomeAdSlot`/`_HomeBannerAd` (AdMob, lazy). Diverifikasi dengan masa tenggang dipersingkat sementara (10 detik) → banner "Test Ad" tampil rapi di dark & light mode → kode dikembalikan ke 15 hari asli dan diverifikasi ulang tidak ada iklan/ruang kosong.
- **Langganan Premium** (`lib/features/subscription/`): `SubscriptionStatus` interface + `RevenueCatSubscriptionStatus`, halaman `SubscriptionPage`. Section "Langganan" baru di Pengaturan. Diverifikasi dengan API key placeholder: gagal dengan pesan jelas, **tidak crash** (belum diuji pembelian sungguhan — perlu akun RevenueCat asli, lihat bagian 6).
- **Backup Cloud** (`lib/features/cloud_backup/`): `CloudBackupService` interface + `GoogleDriveCloudBackupService`, `BackupEncryptor` (AES-256-GCM, murni Dart, dites langsung tanpa fake), halaman `CloudBackupPage`, section "Backup cloud terenkripsi" di Pengaturan (gated premium, sama pola `_SubscriptionTile`). **Diuji sungguhan oleh pemilik**: masuk dengan akun Google asli (nudadan@gmail.com), backup, dan pulihkan — semua berjalan baik.
- Refactor kecil pendukung: `lib/features/settings/restore_confirm.dart` (fungsi `confirmAndRestore` diekstrak dari `SettingsPage._restore` supaya jalur restore file lokal dan restore cloud sama-sama pakai dialog konfirmasi yang identik, bukan duplikasi).

Total tes: 253 → 259 (iklan) → 263 (langganan) → 268 (backup cloud, jalur Google Drive — nomor sempat naik ke
268 juga untuk percobaan Supabase yang lalu dibuang, jadi angkanya kebetulan sama).

## 4. Bug & pelajaran hari ini

| Kejadian | Akar masalah | Pelajaran |
|---|---|---|
| Halaman Backup Cloud (Supabase) macet loading spinner selamanya | Tidak sempat didiagnosis — diputuskan pivot ke Google Drive sebelum menelusuri lebih jauh | Kadang mengganti pendekatan lebih murah daripada debug pendekatan yang sudah terlanjur rumit, terutama kalau ada alternatif yang juga lebih sederhana secara desain |
| "Masuk dengan Google" terlihat **tidak merespons sama sekali** (tanpa error, tanpa log) pada beberapa percobaan pertama | `adb install -r` menimpa APK di atas proses app yang **masih berjalan**, tanpa `force-stop` dulu — state Dart VM lama tertinggal, tap tidak benar-benar diproses oleh kode baru | **Selalu `am force-stop <package>` sebelum `adb install -r` saat menguji build baru** — bukan cuma sekali di awal sesi flutter run, tapi di SETIAP siklus install-ulang manual |
| Sign-in Google gagal terus dengan pesan generik meski SHA-1+package sudah terdaftar benar | `google_sign_in` v7 (Android Credential Manager) **tetap mewajibkan** satu OAuth client tipe **Web application** sebagai `serverClientId`, meski app tidak punya server sungguhan — dokumentasi/tutorial lama tidak menyebutkan ini untuk Android murni | Error aslinya baru kelihatan lewat `GoogleSignInExceptionCode`+`description` (`"serverClientId must be provided on Android"`) — pesan generik `CloudBackupException` di lapisan atas menyembunyikannya. Print sementara di titik tangkap exception paling dalam jauh lebih cepat menemukan akar masalah daripada menebak dari gejala di UI |
| Bagian baru "Langganan Premium"/"Backup Cloud" di dokumen Claude Docs (kebijakan privasi) ter-*nest* salah — masuk ke dalam satu item bullet list "Iklan", bukan jadi bagian sendiri | `insert ... side:"after"` menarget id **listItem** (bukan id **list**-nya) — konektor menaruh konten baru sebagai anak listItem itu, bukan sebagai saudara setelah seluruh list | Saat menambah bagian baru setelah sebuah bullet list di Claude Docs, target `side:"after"` harus ke id **list**-nya sendiri, bukan listItem terakhirnya. Diperbaiki lewat hapus-lalu-insert-ulang ke target yang benar |
| Satu blok `date` chip ("Terakhir diperbarui") di dokumen Claude Docs tidak bisa dihapus/diganti sendiri (`unknown_id`/`not_minted`) walau id sudah disusun benar | Tidak ditemukan penyebabnya — kemungkinan chip tipe khusus punya skema id berbeda dari teks/paragraf biasa | Tidak dikejar lebih jauh (kosmetik, beda satu hari) — teks di sekitarnya diubah jadi `"Terakhir diperbarui: "` polos supaya tidak ada duplikasi tanggal yang aneh saat dibaca |

## 5. Kebijakan privasi — status

Dokumen (Claude Docs, `https://claude.ai/artifact/V5BR5baPrt6CcLBS5t6yHG`) direvisi **3 kali** hari ini:
1. Setelah iklan: bagian baru "Iklan", update "Data yang Kami Kumpulkan"/"Izin Aplikasi"/"Berbagi dengan Pihak
   Ketiga" untuk AdMob.
2. Kedua placeholder diisi: nama pengembang **Solusi Siaga Mandiri**, email dukungan **dadan@hardan-ti.com**.
   Catatan "isi ini sebelum publikasi" dihapus.
3. Setelah RevenueCat + Google Drive: semua bagian di atas diperbarui lagi untuk menyebut ketiga pihak ketiga
   (AdMob, RevenueCat, Google Sign-In/Drive), klaim "masa tenggang bebas jaringan" diperjelas hanya berlaku untuk
   SDK iklan (RevenueCat tetap konek tiap app dibuka), bagian baru **"Langganan Premium"** dan **"Backup Cloud
   (Fitur Premium)"** ditambahkan — yang terakhir menegaskan jujur ini BUKAN enkripsi zero-knowledge.

Dokumen sekarang diyakini lengkap secara konten. **Masih privat** — Anda perlu mempublikasikannya sendiri ke URL
publik (Claude tidak bisa mengubah pengaturan berbagi artifact orang lain).

## 6. Keputusan yang masih TERBUKA (butuh pemilik)

1. **Publikasikan kebijakan privasi** ke URL publik — dibutuhkan Play Console.
2. **Isi Data Safety form** di Play Console (sekarang mencakup: iklan/AdMob, pembelian/RevenueCat, backup opsional
   ke Drive milik pengguna sendiri).
3. **Setup akun RevenueCat** (tautkan ke Play Console, buat produk langganan, tambah license tester) — belum
   dikerjakan; `kRevenueCatApiKey` di `lib/features/subscription/revenuecat_config.dart` masih placeholder.
4. **Mulai uji tertutup** Play Store (12 tester × 14 hari — masa tunggu berjalan sendiri).
5. P1/P2 lama yang belum bergerak: enkripsi database (SQLCipher), `FLAG_SECURE` recent-apps, `deleted_at` belum
   di semua tabel, lapisan repository/domain.

## 7. Setup Google Cloud Console (selesai, dengan detail penting)

Project Google Cloud: Drive API diaktifkan, OAuth consent screen (External, scope `drive.appdata`), dua OAuth
client Android:
- Rilis (`android/app/upload-keystore.jks`, alias `upload`): SHA-1
  `86:E7:F6:D6:FD:67:0A:E4:D1:DC:AD:20:6E:01:30:F6:21:2E:A2:60`
- Debug (`~/.android/debug.keystore`, alias `androiddebugkey`): SHA-1
  `68:AF:B0:14:B4:57:7E:6A:9E:F3:C9:80:0D:83:53:A4:C1:A9:9E:3C`

**Ternyata belum cukup** — lihat bagian 4. Satu OAuth client tambahan tipe **Web application** dibuat, Client
ID-nya (`979979579481-f1p8l6gu75gr32lo67ahajmk49cg7mfm.apps.googleusercontent.com`, PUBLIK, bukan client secret,
tanpa file JSON) ditaruh sebagai `kGoogleServerClientId` di `lib/features/cloud_backup/cloud_backup_config.dart`,
dipakai lewat `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)`. Kalau keystore rilis
berganti kelak, SHA-1 baru harus didaftarkan sebagai client Android ketiga (jangan hapus yang lama selama masih
dipakai untuk build yang beredar).

## 8. Lingkungan pengembangan — tambahan dari sesi ini

Semua praktik aman dari `docs/CATATAN-SESI-2026-09-21.md` (cek layar sebelum sentuh, jangan `keyevent BACK`, cari
elemen lewat `uiautomator`, dst.) masih berlaku dan dipakai berulang kali. Tambahan:
- **Selalu `adb shell am force-stop <package>` sebelum `adb install -r`** saat menguji ulang manual di siklus
  cepat — lihat bug di bagian 4.
- HP berulang kali masuk mode layar mati/terkunci di tengah sesi (VPN + layar mati lama membuat koneksi putus,
  sesuai catatan lama) — pola yang dipakai: cek `dumpsys display`/`dumpsys window` dulu, kalau mati/terkunci
  berhenti dan tunggu konfirmasi "HP sudah menyala" dari pemilik, jangan pernah menebak/mencoba membangunkan.
- Print debug sementara (`print('DEBUG ...')` + `// ignore: avoid_print`) di titik-titik kritis adalah cara
  tercepat mendiagnosis kegagalan native/plugin yang gagal tanpa exception jelas ke UI — selalu dibersihkan lagi
  sebelum menganggap fitur selesai.

## 9. Perintah penting

```bash
source ~/development/env.sh
flutter pub add <paket>                      # biarkan pub resolve versi, jangan hardcode
flutter pub remove <paket>
flutter analyze && flutter test               # 268 tes, ±55 dtk
flutter build apk --debug
adb -s <ip:port> shell am force-stop com.hardanti.lacipintar   # WAJIB sebelum install ulang manual
adb -s <ip:port> install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s <ip:port> shell am start -n com.hardanti.lacipintar/.MainActivity
adb -s <ip:port> logcat -d --pid=<pid>        # cek DEBUG print / error plugin native

# SHA-1 keystore (untuk Google Cloud Console / Play Console)
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload -storepass <dari key.properties>
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

## 10. Lokasi berkas baru sesi ini

- `lib/features/ads/` — `ad_eligibility_service.dart`, `ad_unit_ids.dart`, `banner_ad_widget.dart`
- `lib/features/subscription/` — `subscription_status.dart`, `revenuecat_config.dart`, `subscription_page.dart`
- `lib/features/cloud_backup/` — `cloud_backup_service.dart`, `cloud_backup_config.dart`,
  `backup_encryptor.dart`, `cloud_backup_page.dart`
- `lib/features/settings/restore_confirm.dart` (ekstraksi dari `settings_page.dart`)
- Tes baru: `test/ad_eligibility_service_test.dart`, `test/ads_test.dart`, `test/subscription_page_test.dart`,
  `test/backup_encryptor_test.dart`, `test/cloud_backup_page_test.dart`
- Dokumen: `docs/GAP-ANALISA-2026-09-23.md` (gap analisa awal sesi, sebagian usang untuk bab monetisasi — catatan
  ini yang terkini), `docs/CATATAN-SESI-2026-09-23.md` (berkas ini)
- Memory (untuk sesi Claude berikutnya): `~/.claude/projects/-home-dimas-Claude-Dompet-Pintar/memory/`,
  terutama `dompet-pintar-monetization-plan.md` dan `dompet-pintar-project.md`
