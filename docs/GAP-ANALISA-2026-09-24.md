# Gap Analisa — Rancangan vs Implementasi (24 September 2026)

Pembaruan dari [GAP-ANALISA-2026-09-23.md](GAP-ANALISA-2026-09-23.md) setelah satu sesi kerja tambahan (23–24
September, enam bagian berturut-turut). Dasar perbandingan sama seperti sebelumnya:
[RANCANGAN-AWAL.md](RANCANGAN-AWAL.md) (usulan asisten, bukan PRD yang disetujui). Kondisi kode diperiksa langsung
di sumber pada tanggal dokumen ini: **357 tes lolos** (naik dari 253), skema DB **v6** (naik dari v4), format
backup **v5** (naik dari v4). Detail lengkap tiap bagian ada di
[CATATAN-SESI-2026-09-24.md](CATATAN-SESI-2026-09-24.md).

## 1. Ringkasan perubahan sejak 23 September

| Cakupan | 23 Sep | 24 Sep |
|---|---|---|
| Inti MVP (9 butir) | 9 lengkap | **Tidak berubah** — masih 9/9, sesi ini tidak menyentuh MVP |
| Jalur rilis (Play Console) | Signing + hapus data selesai, privasi/Data Safety/closed testing belum | **Tidak berubah sama sekali** — nol progres, ditambah 1 gap baru (lihat §3) |
| **Monetisasi** | ❌ Belum ada apa pun | 🟡 **Hampir lengkap secara kode** — lompatan terbesar sesi ini |
| Fase 2/3 (rancangan awal) | Hanya target tabungan selesai | Tidak berubah |
| Fase 2/3 (di luar rancangan awal) | — | **2 fitur baru**: proyeksi bulanan, simulasi arus kas harian |

**Prioritas gap analisa 23 Sep vs kenyataan**: dokumen sebelumnya menempatkan monetisasi di **P3** ("tunggu
sinyal dari uji tertutup dulu") dan jalur rilis di **P0**. Sesi ini justru mengerjakan **P3 duluan** — keputusan
produk yang masuk akal (fitur premium perlu ada sebelum RevenueCat berguna), tapi konsekuensinya jalur rilis
(termasuk masa tunggu 12×14 hari closed testing yang "sebaiknya mulai sesegera mungkin") **mundur satu sesi
penuh**.

## 2. Monetisasi dan fitur premium — dari nol jadi hampir lengkap

Ini bagian yang paling banyak berubah dari analisa 23 Sep, jadi dirinci terpisah dari tabel keamanan/MVP.

| Komponen | Status | Catatan |
|---|---|---|
| Model freemium | ✅ | Iklan (AdMob banner) untuk pengguna gratis, masa tenggang 30 hari sebelum iklan muncul |
| Batas gratis per fitur ("cicip") | ✅ | Agenda gratis 3 item aktif, Analisa Tren gratis jendela 3 bulan; keduanya turun ke gratis tanpa memaksa hapus data |
| Fitur premium penuh | ✅ | Backup Cloud, pengingat transaksi berulang, pengingat Agenda, proyeksi bulanan, simulasi arus kas — sengaja TIDAK dapat versi "cicip" |
| `SubscriptionPage` | ✅ | Daftar manfaat eksplisit (`_BenefitList`, 5 butir) — sebelumnya cuma "Hilangkan iklan" |
| **Integrasi RevenueCat** | 🔴 **Placeholder** | [lib/features/subscription/revenuecat_config.dart:6](../lib/features/subscription/revenuecat_config.dart#L6) — `kRevenueCatApiKey = 'PLACEHOLDER_REVENUECAT_API_KEY'`. Belum ada satu pun pembelian sungguhan yang diuji |
| **Integrasi AdMob** | 🔴 **ID uji Google** | App ID (`AndroidManifest.xml`) dan ad unit ID ([lib/features/ads/ad_unit_ids.dart:7](../lib/features/ads/ad_unit_ids.dart#L7)) masih `ca-app-pub-3940256099942544/...` — ID uji resmi Google, bukan akun AdMob asli |
| Harga langganan | ❌ | Belum ditentukan sama sekali — rancangan awal cuma perkiraan kasar (Rp 19–29rb/bulan, Rp 149–199rb/tahun), belum diuji atau dikonfirmasi pemilik |

**Temuan baru (belum ada di gap analisa 23 Sep karena monetisasi belum mulai dikerjakan saat itu)**: menambahkan
`google_mobile_ads`, `purchases_flutter`, `google_sign_in`, dan `googleapis` ke `pubspec.yaml` berarti aplikasi
sekarang punya jalur jaringan aktif untuk pertama kalinya sejak awal proyek. Dicek langsung: paket
`google_mobile_ads` mendeklarasikan izin `INTERNET` di manifest-nya sendiri
(`~/.pub-cache/hosted/pub.dev/google_mobile_ads-9.1.0/android/src/main/AndroidManifest.xml`), yang akan
tergabung otomatis ke manifest final APK produksi lewat manifest merging Android — **walau
`android/app/src/main/AndroidManifest.xml` milik proyek sendiri tidak mendeklarasikannya secara eksplisit**. Ini
berarti klaim di draf kebijakan privasi (dibuat 23 Sep, per gap analisa sebelumnya: *"secara eksplisit menyebut
aplikasi TIDAK punya izin INTERNET di manifest sebagai bukti data tak bisa dikirim keluar"*) **kemungkinan besar
sudah tidak akurat** dan perlu ditulis ulang sebelum dipublikasikan — bukan cuma soal isi 2 placeholder yang
sudah dicatat sebelumnya.

## 3. Fitur MVP (status terkini)

Tidak ada perubahan dari analisa 23 Sep — semua 9 butir MVP tetap lengkap secara fungsional, sesi ini murni
menambah fitur premium/finansial di atasnya.

## 4. Keamanan dan kepatuhan

| Rancangan | Status | Perubahan sejak 23 Sep |
|---|---|---|
| Database terenkripsi (SQLCipher) | ❌ | Tidak berubah — makin mendesak karena data yang disimpan makin bernilai (estimasi biaya Agenda, dll.) |
| PIN dan biometrik | ✅ | Tidak berubah |
| `allowBackup=false` | ✅ | Tidak berubah |
| Fitur hapus akun dan data | ✅ | Tidak berubah |
| **Kebijakan privasi** | 🟡→🔴 | **Memburuk secara faktual** — draf lama mengklaim tanpa izin INTERNET, sekarang klaim itu kemungkinan tidak lagi benar (lihat §2). Masih ada 2 placeholder (nama pengembang, email) + belum publik |
| Syarat layanan, persetujuan UU PDP | ❌ | Tidak berubah |
| Data Safety (Play Console) | ❌ | Belum dimulai — sekarang HARUS mencantumkan pengumpulan data lewat AdMob/RevenueCat/Google Drive, bukan cuma "tidak ada" seperti asumsi sebelumnya |
| `FLAG_SECURE` (recent-apps) | 🟡 | Tidak berubah — masih best-effort |

## 5. Model data — skema naik 4 versi (v4 → v9)

- **v4 → v5**: `RecurringRules.reminderEnabled`/`reminderDaysBefore` (baru), tabel baru `AgendaReminders`.
- **v5 → v6**: `AgendaReminders.estimatedAmount` (baru), `Frequency.once` (frekuensi baru untuk rencana
  insidental), `Transactions.agendaId` (tautan transaksi ke agenda asalnya, tanpa foreign key — pola sama
  `recurringId`).
- **v7 → v8**: tabel baru `Debts` (utang/piutang, lihat §6), `Transactions.debtId` (tautan transaksi pelunasan
  ke utang/piutang asalnya, tanpa foreign key — pola sama `agendaId`/`recurringId`).
- **v8 → v9**: dua kategori bawaan baru "Utang" (pengeluaran) dan "Piutang" (pemasukan) disisipkan lewat
  migrasi (bukan cuma `_seed()`), supaya pembayaran utang/piutang mudah dilacak terpisah dari kategori lain —
  migrasi pertama di app ini yang murni sisip data seed, bukan perubahan struktur tabel.
- `deleted_at` **masih belum berubah** — tetap hanya di 2 dari sekarang 12 tabel (`transactions`,
  `goal_contributions`); `AgendaReminders` dan `Debts` pun tidak dapat soft-delete. Utang teknis sinkronisasi ini
  makin menumpuk seiring jumlah tabel bertambah.
- `device_id` dan lapisan repository/domain: tidak berubah, masih tidak ada.
- **Format backup**: v4 → v6 (`AgendaReminders` disertakan di v5 setelah sempat jadi gap tersembunyi — lihat
  CATATAN-SESI-2026-09-24.md §13; `Debts` disertakan di v6 sejak awal, tidak sempat jadi gap).

## 6. Fase 2 dan 3

**Dari rancangan awal** (RANCANGAN-AWAL.md):
- **Scan struk OCR — ✅ selesai (2026-09-29)**, fitur Premium: capture kamera/galeri, ML Kit on-device, parser
  heuristik, foto tersimpan + ikut backup Drive terenkripsi. Diverifikasi penuh di HP nyata (lihat
  [RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md §2.8](RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md)) termasuk siklus penuh
  backup→simulasi ganti HP→restore dengan akun Google & data sungguhan. **Catatan akurasi**: parser heuristik
  total/nama-toko terbukti kurang akurat untuk struk berlayout kompleks (struk SPBU dengan beberapa sub-total) —
  pengguna tetap harus mengoreksi manual di kasus ini, bukan gagal total. Ekstraksi tanggal terbukti akurat.
  Cek mode offline ML Kit belum sempat dilakukan.
- **Utang/piutang — ✅ selesai (2026-09-29)**, fitur Premium penuh (tanpa versi gratis): tabel `Debts` +
  `Transactions.debtId`, `recordDebtPayment()` atomic (insert transaksi + update `paidAmount` sekaligus, pola
  sama `executeAgenda()`), halaman list + form, mode `fromDebtPayment` di `TransactionFormPage`, tile Pengaturan
  gating premium, tersertakan di backup (`formatVersion` 6). Diverifikasi penuh di HP nyata (lihat
  [RENCANA-IMPLEMENTASI-UTANG-PIUTANG.md §7](RENCANA-IMPLEMENTASI-UTANG-PIUTANG.md)): tambah utang & piutang,
  pembayaran sebagian (mengurangi sisa + transaksi nyata tercatat), pelunasan penuh (status "Lunas", aksi
  pembayaran hilang dari menu, urutan daftar berubah sesuai desain). **Susulan sama hari** (§8 di dokumen
  rencana): kategori bawaan baru "Utang"/"Piutang" (skema v9) diprapilih otomatis di form pembayaran supaya
  mudah dilacak terpisah dari kategori lain, tapi tetap bisa diganti pengguna — juga diverifikasi di HP nyata.
  397/397 test lulus. **Belum sempat**: uji siklus backup/restore Drive khusus tabel `debts` (risiko dianggap
  rendah, pola identik tabel premium lain yang sudah teruji Drive round-trip-nya).
- **Ekstraksi AI struk (tier Ultimate) — kode selesai 29 Sep**: Cloudflare Worker (`backend/receipt-extraction-worker/`,
  verifikasi entitlement `ultimate` ke RevenueCat, 60 scan/bulan, Claude Haiku 4.5), klien (`lib/features/ai/`),
  halaman langganan dua tingkat (Premium/Ultimate, harga Rupiah dari toko). 416 test Flutter + 9 test Worker
  lulus. **Belum**: deploy Worker + kunci, produk Ultimate di RevenueCat/Play Console, uji nyata dengan akun
  Ultimate, revisi kebijakan privasi.
- Sisanya tidak berubah dari 23 Sep: sinkronisasi multi-device, laporan otomatis/insight, multi-mata uang,
  widget home screen, input notifikasi bank, asisten AI chat — semuanya masih ❌. Target tabungan tetap satu-satunya
  butir lama (selain utang/piutang di atas) yang sudah selesai.

**Di luar rancangan awal** (arah baru yang muncul dari diskusi produk sesi ini, belum tercatat di
RANCANGAN-AWAL.md sama sekali):
- **Proyeksi keuangan bulanan** (`monthlyProjectionProvider`) — total pengeluaran terjadwal (Agenda + transaksi
  berulang) dalam bulan kalender berjalan. Premium penuh.
- **Simulasi arus kas harian** (`simulateDailyBalance()`) — mensimulasikan saldo hari demi hari, menjawab "cukup
  gak duitnya sampai tanggal X". Premium penuh.

Keduanya turunan murni dari data yang sudah ada (tidak ada query DB baru), tapi keduanya **belum diverifikasi
manual di HP** dengan data pengguna nyata — beda dari kebanyakan fitur lain sesi ini yang sudah diverifikasi
langsung (lihat catatan terbuka §8).

## 7. Jalur rilis — nol progres, satu gap baru

| Langkah | Status 23 Sep | Status 24 Sep |
|---|---|---|
| Application ID + nama tampilan | ✅ | ✅ Tidak berubah |
| Signing rilis | ✅ | ✅ Tidak berubah |
| Fitur hapus akun/data | ✅ | ✅ Tidak berubah |
| Kebijakan privasi | 🟡 Draf, 2 placeholder | 🔴 **Draf + isi kemungkinan tidak akurat lagi** (§2, §4) |
| Data Safety form (Play Console) | ❌ | ❌ Belum dimulai, lingkupnya bertambah (AdMob/RevenueCat/Drive) |
| Uji tertutup (12 tester × 14 hari) | ❌ | ❌ Belum dimulai — makin mundur |
| Rilis v1 | ❌ | ❌ |

Sesi ini murni fitur produk, tidak menyentuh satu pun langkah jalur rilis.

## 8. Next step yang diputuskan (2026-09-27)

Pemilik produk memutuskan: **setup akun RevenueCat dan AdMob sungguhan** adalah pekerjaan berikutnya yang akan
dikerjakan (P1 butir 3–4 di §9), mendahului P2 (Data Safety/closed testing) dan P0 (revisi kebijakan privasi
menunggu tahu persis data apa yang benar-benar dikirim ke dua layanan ini). Ini menjawab keputusan terbuka #2 di
§10.

Terpisah, pemilik mengingatkan **fitur scan struk OCR** (RANCANGAN-AWAL.md Fase 2) masih belum diimplementasikan
sama sekali — tetap tercatat sebagai backlog Fase 2 (lihat §6), tidak berubah urutan prioritas: RevenueCat/AdMob
tetap next step, OCR belum dijadwalkan.

## 9. Prioritas yang diusulkan (pembaruan)

**P0 — sebelum kebijakan privasi bisa dipublikasikan**
1. Tulis ulang draf kebijakan privasi: hapus/koreksi klaim "tanpa izin INTERNET", cantumkan dengan jujur data apa
   yang mengalir lewat AdMob (iklan), RevenueCat (status langganan), dan Google Drive (backup opsional).
2. Isi 2 placeholder (nama pengembang, email dukungan) dan publikasikan ke URL publik.

**P1 — selesaikan integrasi monetisasi sebelum rilis**
3. Setup akun RevenueCat sungguhan, ganti `kRevenueCatApiKey`, uji minimal satu pembelian sungguhan (sandbox Play
   Billing).
4. Setup akun AdMob sungguhan, ganti App ID + ad unit ID dari ID uji Google.
5. Tentukan harga langganan sungguhan (belum pernah dikonfirmasi pemilik sejak rancangan awal).

**P2 — jalur rilis Play Console (bisa paralel dengan P1)**
6. Isi Data Safety form (lingkup sudah bertambah dari sebelumnya).
7. Mulai uji tertutup 12×14 hari — makin awal makin baik karena masa tunggunya independen dari P1.

**P3 — gap keamanan lama yang tersisa**
8. Enkripsi database (SQLCipher), `FLAG_SECURE`, `deleted_at` di seluruh tabel + `device_id`, lapisan
   repository/domain.

**P4 — verifikasi yang belum sempat dilakukan**
9. Verifikasi manual di HP untuk proyeksi bulanan & simulasi arus kas harian dengan data nyata.
10. Tunggu/uji notifikasi terjadwal (Analisa Tren/pengingat) sampai benar-benar **berbunyi**, bukan cuma
    terdaftar di AlarmManager.

## 10. Keputusan yang menunggu pemilik

1. ~~Harga langganan sungguhan~~ — **diputuskan 2026-09-29 (final, setelah beberapa revisi)**: strategi berubah
   dari 1 tier jadi **2 tier** menyusul keputusan menambah tier Ultimate untuk fitur ekstraksi AI (lihat
   [RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md](RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md)):
   **Premium Rp 7.500/bulan, Rp 75.000/tahun**; **Ultimate Rp 12.500/bulan, Rp 125.000/tahun**. Dicek dulu
   terhadap benchmark kompetitor (Rekapin, app Indonesia AI scan struk paling sebanding: Rp 15.000/bulan
   sungguhan, dicek pemilik langsung) — kedua tier di bawahnya. Masih di bawah perkiraan rancangan awal
   (Rp 19–29rb/bulan). Belum ada opsi lifetime. Detail di `docs/CHECKLIST-REVENUECAT-ADMOB.md` §2.
2. ~~Kapan akun RevenueCat dan AdMob asli disiapkan~~ — **diputuskan 2026-09-27**: jadi next step sekarang, lihat
   §8.
3. Apakah kebijakan privasi ditulis ulang dulu sebelum atau sesudah akun RevenueCat/AdMob asli didaftarkan
   (urutan memengaruhi berapa kali harus direvisi).
4. Apakah closed testing (P2) dimulai sekarang dengan fitur premium yang belum production-ready secara akun
   (RevenueCat/AdMob placeholder), atau ditunda sampai P1 selesai — trade-off antara mulai masa tunggu 12×14 hari
   lebih cepat vs tester mencoba fitur berbayar yang belum benar-benar bisa dibeli.
5. P3 (SQLCipher dll.) tetap belum mendesak untuk rilis — sama seperti keputusan 23 Sep, "tidak terenkripsi" bisa
   dijawab jujur di Data Safety form.
6. Kapan fitur scan struk OCR (Fase 2, RANCANGAN-AWAL.md) mulai dikerjakan — diingatkan kembali oleh pemilik
   2026-09-27, belum dijadwalkan, tetap di belakang RevenueCat/AdMob dalam urutan prioritas saat ini.

## Pembaruan 30 Sep 2026 — kebijakan privasi
- Kebijakan privasi ditulis ulang sebagai HTML statis: `docs/kebijakan-privasi/index.html` (pengembang hardan-ti,
  support@hardan-ti.com). Mencakup INTERNET/AD_ID, AdMob, RevenueCat, Backup Drive (drive.appdata, AES), dan aliran AI
  Ultimate (Cloudflare → Anthropic). **Belum**: dihosting ke URL publik; URL itu dibutuhkan Play Console.
- Bug ditemukan & diperbaiki: "Hapus semua data" tidak menghapus tabel `debts`, `agendaReminders`, dan foto struk
  (`documents/receipts`). Kini ikut terhapus (test ditambah di `test/database_test.dart`).
- Hapus data lokal TIDAK menghapus cadangan di Drive; ini dinyatakan di kebijakan.
- Catatan: belum ada dialog persetujuan iklan (UMP). Aplikasi khusus Indonesia sehingga tidak wajib GDPR, tapi cek
  formulir "Ads" dan Data Safety saat rilis.
- **Kebijakan privasi sudah online (30 Sep):** https://dompetku.hardan-ti.com/privacy — vhost nginx
  `/etc/nginx/sites-available/dompetku.hardan-ti.com.conf`, berkas di `/var/www/dompetku.hardan-ti.com/privacy/`,
  sertifikat Let's Encrypt (kedaluwarsa 2026-12-29, auto-renew certbot). Tanpa geo-block agar reviewer Play bisa akses.
  Server dituju lewat VPN `10.9.0.208` (SSH publik port 22 tertutup).
