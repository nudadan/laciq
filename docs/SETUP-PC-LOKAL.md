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
- `flutter test`: 415 lulus, 1 gagal (lihat di bawah).
- Tes Worker: 9/9 lulus.
- `flutter build appbundle --release`: berhasil (85,2 MB), ditandatangani kunci upload yang sama dengan AAB yang sudah
  diunggah ke Play Console (SHA-256 `C3:E7:62:D8:…:53:9B`).

## Kegagalan tes yang diketahui
`test/dashboard_projection_card_test.dart` → "premium dengan agenda + transaksi berulang bulan ini". Tes memakai
`DateTime.now() + 1 hari` sebagai `startDate` aturan berulang; pada tanggal 30/31 setiap bulan "besok" jatuh di bulan
berikutnya sehingga tidak masuk proyeksi bulan berjalan. Bukan akibat migrasi; lulus lagi mulai tanggal 1. Perbaikan
permanen: hitung `startDate` relatif terhadap sisa hari bulan itu, bukan `now + 1`.

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

## Rahasia yang ikut dimigrasi
`android/key.properties` dan `android/app/upload-keystore.jks` (kunci upload Play Store). Kehilangan keduanya berarti
tidak bisa merilis pembaruan. Simpan salinan cadangan di luar PC ini (mis. password manager). Berkas-berkas ini
sudah dikecualikan git oleh `android/.gitignore`; jangan dibagikan.

## Belum dilakukan
- Repositori git belum ada (server juga tidak punya `.git`). Disarankan `git init` + commit pertama sebelum
  pengembangan lanjut.
- Uji di perangkat: `adb devices` kosong saat migrasi (belum ada HP tersambung).
- Deploy Cloudflare Worker (`wrangler`) belum dicoba dari PC ini.
