# Setup Pengembangan di PC Lokal

> Dibuat 2026-09-30 saat migrasi proyek dari server `10.9.0.201:/home/dimas/Claude/Dompet-Pintar/` ke
> `E:\Developments\DompetKu`. Server tidak diubah dan masih menyimpan salinan aslinya (termasuk `build/`).

## Mulai bekerja
```bash
source /e/Developments/tools/dev-env.sh        # Git Bash
# atau PowerShell:  . E:\Developments\tools\dev-env.ps1
```
Skrip ini memasang PATH (Flutter 3.47.5, Node.js, JDK 17) dan truststore JVM. Tanpa itu, `flutter` di PATH bawaan
adalah 3.44.3 (C:\flutter) yang terlalu lama untuk proyek ini.

## Perintah harian
| Tujuan | Perintah |
|---|---|
| Ambil dependensi | `flutter pub get` |
| Analisa | `flutter analyze` |
| Tes Flutter | `flutter test` |
| Jalankan di HP (USB debugging) | `flutter run` |
| Build AAB rilis | `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` |
| Tes Worker | `cd backend/receipt-extraction-worker && npm ci && npm test` |

## Hasil verifikasi migrasi (2026-09-30)
- 213 file identik dengan server (SHA-256).
- `flutter analyze`: 1 info lint lama (`database.dart` curly braces), tidak ada error.
- `flutter test`: 416/416 lulus (saat migrasi 415 + 1 gagal karena tanggal; sudah diperbaiki, lihat di bawah).
- Tes Worker: 9/9 lulus.
- `flutter build appbundle --release`: berhasil (85,2 MB), ditandatangani kunci upload yang sama dengan AAB yang sudah
  diunggah ke Play Console (SHA-256 `C3:E7:62:D8:…:53:9B`).

## Kegagalan tes yang sempat ada (sudah diperbaiki)
`test/dashboard_projection_card_test.dart` → "premium dengan agenda + transaksi berulang bulan ini" gagal pada hari
terakhir bulan karena `startDate = now + 1 hari` jatuh di bulan berikutnya (di luar proyeksi bulan berjalan). Bukan
akibat migrasi. Diperbaiki 2026-09-30: ekspektasi kini mengikuti kalender. Setelah perbaikan: 416/416 lulus.

## Keanehan lingkungan PC ini (sudah diatasi, jangan dihapus tanpa tahu alasannya)
1. **Avast Web/Mail Shield mencegat HTTPS.** JVM (Gradle, wrapper) tidak percaya sertifikatnya →
   `PKIX path validation failed`. Diatasi lewat `E:\Developments\tools\certs\cacerts-with-avast` (salinan cacerts
   JBR Android Studio + sertifikat Avast) yang dipasang di `JAVA_TOOL_OPTIONS` oleh `dev-env`. Bila Avast diperbarui
   dan sertifikat rootnya berganti, buat ulang berkas itu (`keytool -importcert` ke salinan cacerts).
   `winget` juga terpengaruh untuk sumber `msstore`; pakai `--source winget`.
2. **Proyek di drive E:, cache di C:.** Kompilasi Kotlin inkremental gagal lintas drive ("Could not close
   incremental caches"). Diatasi dengan `kotlin.incremental=false` di `android/gradle.properties`.
3. **`android/local.properties`** dibuat manual (sdk.dir + flutter.sdk ke Flutter 3.47.5). Berkas ini tidak ikut
   disalin dari server karena berisi path khusus mesin; jangan dimasukkan ke version control.

4. **Login Google (Backup Cloud) butuh SHA-1 kunci penanda tangan terdaftar di Google Cloud.** Build debug dari PC ini
   memakai `~/.android/debug.keystore` milik PC ini, SHA-1 `42:80:14:01:8E:04:9C:E9:7B:6F:32:27:45:E1:D9:88:7A:34:8C:B8`,
   berbeda dari kunci debug server (`68:AF:B0:14:…:9E:3C`). Sebelum didaftarkan, login gagal dengan
   `UNREGISTERED_ON_API_CONSOLE`; setelah didaftarkan sebagai OAuth client Android ke-3 (2026-09-30) restore dari
   Drive berhasil di HP. Daftar client Android yang harus ada: rilis `86:E7:F6:D6:…`, debug server `68:AF:B0:14:…`,
   debug PC ini `42:80:14:01:…`, dan **Play App Signing** `21:30:93:26:02:43:4C:7C:57:B9:B2:2C:15:65:05:A6:7B:F2:61:45`
   (client "DompetKu - Play App Signing", didaftarkan 2026-09-30; aktif setelah 5 menit sampai beberapa jam).
   **Layar persetujuan OAuth masih berstatus Testing**: hanya *test user* (saat ini hanya nudadan@gmail.com, kuota 100)
   yang bisa login Google/Backup Cloud. Tester lain harus ditambahkan di Google Auth Platform → Audience → Test users,
   atau aplikasi dipublikasikan (scope `drive.appdata` non-sensitif; butuh Branding lengkap).
5. **HP uji lewat adb nirkabel.** Xiaomi/HyperOS menolak pemasangan (`INSTALL_FAILED_USER_RESTRICTED`) kecuali
   "Instal via USB" diaktifkan di Opsi pengembang. Ganti kunci penanda tangan berarti harus uninstall dulu
   (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), yang menghapus data lokal; backup ke cloud dulu.

## Rahasia yang ikut dimigrasi
`android/key.properties` dan `android/app/upload-keystore.jks` (kunci upload Play Store). Kehilangan keduanya berarti
tidak bisa merilis pembaruan. Simpan salinan cadangan di luar PC ini (mis. password manager). Berkas-berkas ini
sudah dikecualikan git oleh `android/.gitignore`; jangan dibagikan.

## Belum dilakukan
- Repositori git belum ada (server juga tidak punya `.git`). Disarankan `git init` + commit pertama sebelum
  pengembangan lanjut.
- Uji di perangkat: `adb devices` kosong saat migrasi (belum ada HP tersambung).
- Deploy Cloudflare Worker (`wrangler`) belum dicoba dari PC ini.
