# Rancangan Awal — Dompet Pintar

> **Status dokumen:** salinan **apa adanya** dari percakapan perencanaan pertama (21 September 2026), disimpan agar
> punya acuan tetap. Isinya **usulan asisten**, bukan PRD yang disetujui pemilik. Perbandingannya dengan
> implementasi ada di [GAP-ANALISA-2026-09-21.md](GAP-ANALISA-2026-09-21.md).
>
> - **Sumber:** riwayat sesi Claude pertama
>   (`~/.claude/projects/-home-dimas-Claude-Dompet-Pintar/2c734d1c-0c68-46a6-ac29-89e9a77b10b0.jsonl`).
> - **Isi rancangan tidak diubah.** Bagian A, C, dan judul pembungkus hanya konteks yang ditambahkan saat menyimpan; Bagian B dan D adalah teks asli.
> - **Perlu diverifikasi ulang:** kebijakan store, harga, dan regulasi di bawah berasal dari pengetahuan umum saat
>   itu, bukan dari sumber yang dicek.

## Bagian A — Permintaan awal pemilik (2026-09-21 04:21 UTC)

> saya berencana membangun project aplikasi "Personal Cash Management", aplikasi ini ditujukan untuk membantu pengguna (perorangan) dalam mengelola keuangannya. Aplikasi dikembangkan dengan platform mobile  (android & ios). aplikasi akan di publikasikan di playstore dan appstore untuk tujuan monetisasi. bantu saya merancang aplikasi tersebut baik teknis implementasinya juga cara monetisasi dari aplikasi tersebut.

## Bagian B — Rancangan (jawaban asisten, 2026-09-21 04:22 UTC)

# Rancangan Aplikasi "Dompet Pintar" (Personal Cash Management)

Saya berasumsi target pasar awalnya Indonesia (Rupiah, bahasa Indonesia) dan tim kecil, 1–3 developer. Asumsi ini bisa diubah.

## 1. Fitur

**MVP (rilis v1, 3–4 bulan)**
- Pencatatan transaksi (pemasukan, pengeluaran, transfer antar dompet) dengan input cepat: maksimal 3 tap.
- Multi-akun/dompet: tunai, rekening bank, e-wallet (GoPay, OVO, dan sejenisnya).
- Kategori dan sub-kategori kustom, plus tag.
- Anggaran (budget) bulanan per kategori, dengan notifikasi saat mendekati batas.
- Dashboard: saldo total, arus kas bulan ini, grafik per kategori, tren 6 bulan.
- Transaksi berulang (gaji, cicilan, langganan).
- Ekspor CSV, backup dan restore.
- Keamanan: PIN atau biometrik.

**Fase 2 (pembeda dan pemicu upgrade)**
- Scan struk dengan OCR (ML Kit on-device, lalu LLM untuk ekstraksi item dan kategori).
- Target tabungan (goals) dan pelacakan utang/piutang.
- Sinkronisasi multi-device dan mode berdua (pasangan/keluarga).
- Laporan bulanan otomatis dan insight, misalnya "pengeluaran makan naik 23% dari bulan lalu".
- Multi-mata uang.
- Widget home screen dan quick-add dari notifikasi.

**Fase 3 (opsional)**
- Input dari notifikasi bank atau e-wallet. Ini hanya bisa di Android via `NotificationListenerService`. iOS tidak mengizinkannya.
- Integrasi agregator rekening (Open Banking). Di Indonesia ini masih terbatas dan mahal, jadi jangan dijadikan andalan di awal.
- Asisten AI berbasis chat: "berapa pengeluaran kopi saya bulan ini?"

## 2. Arsitektur Teknis

### Stack yang direkomendasikan

| Lapisan | Pilihan | Alasan |
|---|---|---|
| Mobile | **Flutter** (Dart) | Satu codebase untuk Android dan iOS, performa grafik baik, UI konsisten. React Native + Expo juga layak jika tim Anda kuat di JavaScript. |
| State management | Riverpod | Testable dan skalabel. |
| DB lokal | **SQLite** via Drift | Query relasional dan agregasi cepat, cocok untuk data keuangan. |
| Backend | **Supabase** (Postgres + Auth + Storage + Edge Functions) | Murah di awal, SQL, Row Level Security, tanpa perlu mengelola server. Alternatifnya Firebase. |
| Auth | Sign in with Apple, Google, email OTP | Sign in with Apple wajib di iOS jika Anda menawarkan login pihak ketiga. |
| Langganan | **RevenueCat** | Menyatukan Google Play Billing dan StoreKit, ada paywall dan analitik, gratis sampai omzet tertentu. |
| Analitik dan crash | Firebase Analytics + Crashlytics, PostHog (opsional) | Diperlukan untuk mengukur konversi. |
| Notifikasi | FCM + notifikasi lokal | Pengingat budget dan pencatatan. |
| CI/CD | GitHub Actions + Fastlane (atau Codemagic) | Build dan rilis otomatis ke Play Store dan TestFlight. |

### Prinsip utama: offline-first
Aplikasi keuangan harus bisa dipakai tanpa internet. SQLite lokal adalah sumber kebenaran utama. Sync ke cloud bersifat opsional dan hanya untuk pengguna Premium.

```
┌─────────────────────────────────────────┐
│  Presentation (Flutter widgets)         │
├─────────────────────────────────────────┤
│  Application (Riverpod, use-cases)      │
├─────────────────────────────────────────┤
│  Domain (entity, aturan budget, dll)    │
├─────────────────────────────────────────┤
│  Data: Repository                       │
│   ├─ Local: SQLite (Drift)  ◄─ sumber utama
│   └─ Remote: Supabase sync  ◄─ opsional (Premium)
└─────────────────────────────────────────┘
```

### Model data inti
```
user(id, nama, mata_uang_default, created_at)
account(id, nama, tipe[cash|bank|ewallet|kartu], saldo_awal, mata_uang, arsip)
category(id, nama, tipe[income|expense], parent_id, ikon, warna)
transaction(id, account_id, category_id, tipe, jumlah, tanggal,
            catatan, transfer_ke_account_id, recurring_id,
            updated_at, deleted_at, device_id)
budget(id, category_id, periode, jumlah)
recurring_rule(id, template_transaksi, rrule, next_run)
goal(id, nama, target, terkumpul, deadline)
attachment(id, transaction_id, path_struk)
```

**Catatan penting:**
- Simpan uang sebagai **integer** (satuan terkecil) dan jangan pernah `double`. Contoh: Rp 15.000 disimpan sebagai `15000`. Untuk multi-mata uang, simpan juga kode ISO.
- ID berupa **UUID v7** yang dibuat di klien, sehingga bisa dibuat offline tanpa konflik.
- Gunakan **soft delete** (`deleted_at`) dan `updated_at` agar sinkronisasi bisa dilakukan.

### Strategi sinkronisasi
- Pendekatan sederhana: *last-write-wins* per baris berdasarkan `updated_at` (hybrid logical clock lebih aman daripada jam perangkat). Ini cukup untuk 1 pengguna dengan beberapa perangkat.
- Alur: klien mengirim perubahan sejak `last_sync_at`, lalu menarik perubahan dari server.
- Jika nanti butuh mode berdua dengan edit bersamaan, pertimbangkan PowerSync atau ElectricSQL daripada membangun sendiri.

### Keamanan dan privasi
Data keuangan itu sensitif, dan ini juga bisa dijadikan nilai jual.
- Database lokal dienkripsi (SQLCipher) dan kunci disimpan di Keychain/Keystore.
- Kunci PIN dan biometrik memakai `local_auth`.
- Semua komunikasi lewat TLS. Aktifkan RLS Supabase, sehingga tiap pengguna hanya bisa membaca barisnya sendiri.
- Fitur **hapus akun dan data** wajib ada. Apple dan Google mengharuskannya.
- Patuhi **UU PDP No. 27/2022**: sediakan kebijakan privasi, persetujuan eksplisit, dan hak hapus data.
- Untuk fitur OCR/AI: jelaskan dengan jelas data apa yang dikirim ke server. Gambar struk sebaiknya diproses on-device jika memungkinkan.
- Jangan minta akses SMS atau kredensial bank. Ini berisiko ditolak store dan merusak kepercayaan pengguna.

### Fitur AI (biaya terkendali)
- OCR: ML Kit on-device (gratis). Hasil teks dikirim ke LLM kecil dan murah lewat Edge Function untuk ekstraksi terstruktur (merchant, total, item, kategori).
- **Jangan pernah menyimpan API key LLM di aplikasi.** Panggil lewat backend Anda, dengan rate limit per pengguna.
- Fitur AI hanya untuk Premium atau dengan kuota gratis kecil, supaya biayanya tertutup.

## 3. Monetisasi

### Model utama: Freemium + Langganan
Aplikasi pencatatan keuangan biasanya punya retensi rendah. Jadi versi gratis harus benar-benar berguna dan tidak terasa "dijebak".

| | **Gratis** | **Premium** |
|---|---|---|
| Pencatatan transaksi | Tidak terbatas | Tidak terbatas |
| Dompet/akun | 3 | Tidak terbatas |
| Budget | 3 kategori | Tidak terbatas |
| Riwayat laporan | 3 bulan | Seluruh riwayat |
| Sync multi-device dan backup cloud | ❌ | ✅ |
| Scan struk (OCR/AI) | 5 per bulan | Tidak terbatas |
| Transaksi berulang, goals | Terbatas | ✅ |
| Ekspor PDF/Excel | ❌ | ✅ |
| Mode berdua/keluarga | ❌ | ✅ (paket Keluarga) |
| Tanpa iklan | ❌ | ✅ |

### Harga (perkiraan untuk Indonesia, perlu diuji)
- Bulanan: Rp 19.000–29.000
- **Tahunan: Rp 149.000–199.000** (jadikan opsi utama; diskon 35–50% dari total bulanan)
- **Lifetime: Rp 399.000–499.000** (pembelian sekali bayar. Populer di Indonesia dan cepat menghasilkan kas, tetapi tidak berulang.)
- Gratis uji coba 7 hari untuk paket tahunan.
- Gunakan harga regional lewat App Store Connect dan Play Console.

### Sumber pendapatan tambahan
1. **Iklan (untuk pengguna gratis)**: banner native atau interstitial yang sangat terbatas (AdMob). Jangan tampilkan iklan saat mencatat transaksi. Iklan dan konteks keuangan mudah membuat pengguna curiga, jadi pakai dengan hemat.
2. **Affiliate/referral finansial (paling bernilai tapi harus berhati-hati)**: rekomendasi kontekstual ke reksa dana, tabungan digital, asuransi, atau pinjaman berizin OJK. Beri label "sponsor" dengan jelas. Hanya pakai mitra berizin OJK. Jangan jual data pengguna.
3. **In-app purchase sekali beli**: paket tema, ikon kategori, atau widget premium.
4. **B2B2C (jangka panjang)**: kerja sama dengan koperasi, perusahaan (benefit literasi keuangan karyawan), atau komunitas.

### Strategi konversi
- Tampilkan paywall di **momen bernilai**: saat mencapai batas dompet, saat mencoba scan struk ke-6, atau saat menyelesaikan laporan bulanan pertama. Jangan tampilkan di layar pertama.
- Onboarding pendek, dengan pengguna mencatat transaksi pertama di bawah 60 detik.
- Bangun kebiasaan lewat pengingat harian, streak pencatatan, dan ringkasan mingguan.
- Ukur: D1/D7/D30 retention, trial-to-paid, dan churn. Target awal yang realistis adalah konversi gratis ke berbayar 2–5%.

### Gambaran ekonomi kasar
Misalnya 50.000 pengguna aktif, konversi 3%, dan rata-rata Rp 150.000/tahun per pelanggan:
1.500 pelanggan × Rp 150.000 ≈ **Rp 225 juta/tahun**, sebelum potongan store sekitar 15% (program small business) dan biaya infrastruktur. Biaya cloud di skala ini biasanya sangat kecil (Supabase sekitar Rp 400–800 ribu/bulan). Biaya AI perlu diawasi.

## 4. Persyaratan Publikasi Store

- **Apple Developer**: US$99/tahun. **Google Play**: US$25 sekali bayar.
- Google Play mewajibkan tes tertutup: **12 tester selama 14 hari** untuk akun perorangan baru sebelum rilis produksi.
- Isi Data Safety (Play) dan Privacy Nutrition Label (Apple) dengan jujur.
- Aplikasi Anda hanya **mencatat**, tidak memindahkan uang. Jangan tambahkan fitur pinjaman atau pembayaran tanpa izin OJK/BI, karena itu ranah yang teregulasi.
- Apple mewajibkan pembelian digital lewat IAP, jadi jangan arahkan pembayaran ke luar aplikasi.
- Siapkan halaman kebijakan privasi, syarat layanan, dan email dukungan.

## 5. Roadmap

| Fase | Durasi | Hasil |
|---|---|---|
| 0. Validasi | 2 minggu | Wawancara 10–15 calon pengguna, analisis kompetitor (Money Lover, Finansialku, Wallet, Monefy, Buku Warung). Cari celahnya. |
| 1. Desain | 2–3 minggu | Wireframe di Figma, design system, alur onboarding. |
| 2. MVP | 8–10 minggu | Fitur inti offline-first, PIN, ekspor. |
| 3. Beta tertutup | 3–4 minggu | 20–50 tester, perbaikan bug, uji paywall. |
| 4. Rilis v1 | — | Rilis gratis + langganan sederhana. |
| 5. Iterasi | Berkelanjutan | Sync, OCR, laporan, lalu ukur dan perbaiki retensi. |

**Pembeda yang bisa Anda tonjolkan** (aplikasi serupa sudah banyak): privasi (data tetap di perangkat), lokalisasi Indonesia (e-wallet, THR, arisan, patungan), dan pencatatan sangat cepat. Pilih satu sebagai positioning utama.

## Langkah Berikutnya

Saya bisa lanjutkan ke salah satu dari ini:
1. **Scaffold project Flutter** di `/home/dimas/Claude/Dompet-Pintar`: struktur folder, skema Drift, dan layar dasar.
2. **Dokumen desain lengkap** (PRD + arsitektur) yang bisa dibagikan ke tim.
3. **Skema database detail + migrasi Supabase** beserta kebijakan RLS.
4. **Wireframe layar utama.**

Beberapa hal yang menentukan arah ke depan: apakah Anda mengerjakan sendiri atau bersama tim? Apakah Anda sudah punya pengalaman Flutter atau React Native? Apakah targetnya khusus Indonesia atau global? Jawaban ini akan mengubah pilihan stack dan harga.

## Bagian C — Batasan dari pemilik sesudahnya (2026-09-21 05:53 UTC)

> saya akan mengerjakan project ini sendiri di bantu oleh agent AI, target khusus unutk indonesia. untuk tahap awal lakukan pengembangan untuk android.

Akibatnya: **iOS, multi-mata uang, dan Sign in with Apple** tidak dihitung sebagai gap terhadap rancangan ini, dan
pertanyaan penutup pada Bagian B (sendiri atau tim, pengalaman, target pasar) sudah terjawab.

## Bagian D — Rencana tahap Android (2026-09-21 05:54 UTC)

Rencana setelah itu, untuk tahap Android:
1. Membuat project Flutter `dompet_pintar` (package `id.dompetpintar.app`, hanya target Android).
2. Menyiapkan struktur clean architecture, Drift (SQLite), dan Riverpod.
3. Membuat skema database: akun, kategori, transaksi, dan budget. Nominal disimpan sebagai integer, dengan seed kategori bahasa Indonesia.
4. Membuat layar MVP: onboarding singkat, dashboard, tambah transaksi cepat, daftar transaksi, dan budget.
5. Menjalankan `flutter analyze` dan tes unit, lalu build APK debug untuk verifikasi.
