# Matriks Fitur per Paket Langganan — DompetKu

Disusun 2026-09-30 dari pemeriksaan langsung kode (`lib/`, `backend/`) dan dokumen `docs/`. Angka tes: 416 Flutter + 9 Worker lulus.

**Legenda**
- Paket: ✅ tersedia penuh · 🟡 tersedia dengan batas · ❌ tidak tersedia
- Status implementasi: ✅ selesai dan diverifikasi · 🟡 selesai di kode, verifikasi belum lengkap · 🔴 kode ada tetapi belum bisa dipakai (butuh deploy/produk) · ⬜ belum dibuat

Harga (ditetapkan 2026-09-29): Premium Rp7.500/bulan atau Rp75.000/tahun; Ultimate Rp12.500/bulan atau Rp125.000/tahun.
Produk yang sudah aktif di Play Console dan RevenueCat: hanya **Premium**. Ultimate belum dibuat.

## 1. Fitur inti (semua paket)

| Fitur | Gratis | Premium | Ultimate | Status implementasi |
|---|---|---|---|---|
| Transaksi pemasukan, pengeluaran, transfer | ✅ | ✅ | ✅ | ✅ |
| Multi-dompet / akun | ✅ | ✅ | ✅ | ✅ |
| Kategori, sub-kategori, tag | ✅ | ✅ | ✅ | ✅ |
| Anggaran bulanan + notifikasi | ✅ | ✅ | ✅ | ✅ (bunyi notifikasi belum diuji sampai berbunyi, GAP-ANALISA P4) |
| Dashboard: saldo, arus kas, grafik kategori | ✅ | ✅ | ✅ | ✅ |
| Transaksi berulang (dibuat otomatis saat app dibuka) | ✅ | ✅ | ✅ | ✅ (bukan pekerjaan latar belakang, sengaja) |
| Target tabungan | ✅ | ✅ | ✅ | ✅ |
| Ekspor transaksi CSV | ✅ | ✅ | ✅ | ✅ |
| Backup dan pulihkan lokal (berkas, tidak terenkripsi) | ✅ | ✅ | ✅ | ✅ |
| Kunci aplikasi PIN + biometrik | ✅ | ✅ | ✅ | ✅ (kunci level aplikasi, bukan enkripsi database) |
| Onboarding | ✅ | ✅ | ✅ | ✅ |
| Hapus semua data | ✅ | ✅ | ✅ | ✅ (bug hapus `debts`/agenda/foto struk diperbaiki 30 Sep) |
| Iklan banner (AdMob) | ✅ tampil setelah masa bebas 30 hari | ❌ tanpa iklan | ❌ tanpa iklan | 🟡 ID unit asli terpasang; akun AdMob masih dalam review Google |

## 2. Fitur dengan batas di paket gratis ("cicip")

| Fitur | Gratis | Premium | Ultimate | Status implementasi |
|---|---|---|---|---|
| Analisa Tren per kategori | 🟡 jendela 3 bulan | ✅ 6 dan 12 bulan | ✅ | ✅ Batas juga diklem di provider, bukan hanya UI |
| Agenda (servis kendaraan/AC, biaya pendidikan) | 🟡 3 item aktif | ✅ tanpa batas | ✅ | ✅ Item lama tidak dihapus saat turun ke gratis |
| Pengingat Agenda | 🟡 hanya 3 item tertua | ✅ semua item | ✅ | ✅ Pengingat terjadwal; belum diuji sampai berbunyi |

## 3. Fitur Premium penuh (tanpa versi gratis)

| Fitur | Gratis | Premium | Ultimate | Status implementasi |
|---|---|---|---|---|
| Backup cloud terenkripsi ke Google Drive pengguna (`drive.appdata`, AES) | ❌ | ✅ | ✅ | 🟡 Kode dan restore terverifikasi di HP. Login di build Play bergantung OAuth client Play App Signing (baru didaftarkan 30 Sep) dan penguji harus masuk daftar *Test users* (sudah 5 email) |
| Pengingat transaksi berulang | ❌ (baris upsell) | ✅ | ✅ | ✅ |
| Proyeksi keuangan bulanan (Agenda + transaksi berulang) | ❌ (ajakan upgrade) | ✅ | ✅ | 🟡 Tes lulus; belum diverifikasi manual di HP dengan data nyata |
| Simulasi arus kas harian ("cukup sampai tanggal X") | ❌ | ✅ | ✅ | 🟡 Sama seperti proyeksi bulanan |
| Utang dan Piutang beserta cicilan | ❌ | ✅ | ✅ | ✅ Diverifikasi di HP; uji backup/restore tabel `debts` belum |
| Scan struk (OCR on-device ML Kit, parser heuristik, foto struk tersimpan) | ❌ | ✅ | ✅ | ✅ Diverifikasi di HP. Akurasi turun untuk struk kompleks (mis. SPBU); mode offline ML Kit belum dicek |
| Foto struk ikut backup cloud terenkripsi | ❌ | ✅ | ✅ | ✅ Round-trip backup dan restore diverifikasi |

## 4. Fitur khusus Ultimate

| Fitur | Gratis | Premium | Ultimate | Status implementasi |
|---|---|---|---|---|
| Ekstraksi struk dengan AI: nama toko, kategori, **total, dan tanggal** terisi otomatis (kuota 60 scan/bulan, 15/hari) | ❌ | ❌ | ✅ | 🟡 Kode klien dan Worker selesai (Gemini bawaan, Claude sebagai pembanding; 490 tes Flutter + 38 tes Worker lulus). **Belum bisa dipakai**: Worker belum di-deploy, model belum dipilih (uji 10 struk butuh kunci), bentuk keluaran Gemini belum diverifikasi dengan permintaan nyata; lihat bagian 6 dan [RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md](RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md) |
| **Multi buku kas**: pembukuan terpisah (mis. pribadi vs bisnis), masing-masing punya dompet, kategori, anggaran, transaksi berulang, agenda, utang/piutang, dan target sendiri; sampai 5 buku, pengalih buku di aplikasi | ❌ (satu Buku Utama) | ❌ (satu Buku Utama) | ✅ | 🟡 Kode selesai dan diuji otomatis (skema v10, backup v7, pengalih, Kelola Buku Kas, operasi lintas buku; 30 tes DB + tes UI). **Belum diuji di perangkat nyata** (upgrade dari rilis 3, F7). Rincian: [RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md](RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md) |

Cara kerja ekstraksi AI bila aktif: hasil OCR on-device diisi dulu oleh heuristik, lalu Ultimate meminta AI (Cloudflare Worker) menyempurnakan nama toko dan kategori. Tanpa `AI_EXTRACTION_URL`, fitur mati diam-diam dan scan tetap jalan dengan heuristik.

## 5. Ringkasan cakupan

| Paket | Jumlah fitur | Siap dipakai sekarang |
|---|---|---|
| Gratis | 13 inti + 3 dengan batas | Ya |
| Premium | Semua Gratis + 7 fitur Premium penuh, tanpa iklan, batas dibuka | Ya (produk aktif, RevenueCat valid; uji beli di HP belum dilakukan) |
| Ultimate | Semua Premium + 2 fitur khusus (ekstraksi AI, multi buku kas) | Belum (kode kedua fitur selesai; AI menunggu deploy Worker + pilihan model, multi buku kas menunggu uji di perangkat, dan produk Ultimate belum dibuat di Play/RevenueCat) |

## 6. Yang menghalangi Ultimate (semua belum dikerjakan)

| Butir | Status |
|---|---|
| Deploy Cloudflare Worker + kunci (`ANTHROPIC_API_KEY`, kunci REST RevenueCat, KV `RATE_LIMIT`) | ⬜ |
| Isi `AI_EXTRACTION_URL` saat build (`--dart-define`) | ⬜ |
| Produk Play `dompetku_ultimate` (base plan monthly Rp12.500 dan yearly Rp125.000) | ⬜ |
| Entitlement RevenueCat `ultimate`; produk Ultimate dikaitkan ke `ultimate` **dan** `premium` (lihat `revenuecat_config.dart`) | ⬜ |
| Paket Ultimate ditambahkan ke offering `dompetku` (kartu Ultimate baru muncul di halaman langganan bila paketnya ada) | ⬜ |
| Uji nyata dengan akun Ultimate | ⬜ |
| Kebijakan privasi: aliran AI sudah ditulis dengan penyedia **Anthropic**; harus diubah menjadi **Google (Gemini API berbayar)** saat Worker di-deploy (jangan diubah lebih awal, versi online harus sesuai kenyataan), lalu Data Safety Play disesuaikan | 🟡 |
| Penyedia AI: uji 10 struk (heuristik, 3.1 Flash-Lite, 3.8 Flash, Haiku 4.5), pilih model termurah yang lolos; wajib Gemini **paid tier** dengan project Google Cloud terpisah | ⬜ |
| Bagian Ultimate di deskripsi listing Play sengaja dihapus; tambahkan lagi saat Ultimate rilis | ⬜ |

## 6b. Temuan audit Ultimate (2026-09-30)

Audit dokumen rancangan (`RANCANGAN-AWAL.md`, `RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md`) terhadap kode. Rencana perbaikan tiap temuan ada di [RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md](RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md); kolom terakhir merujuk ke butirnya.

### Celah yang belum tercatat di rencana mana pun

| ID | Temuan | Bukti di kode | Dampak | Rencana |
|---|---|---|---|---|
| T1 | Pelanggan Premium tidak punya jalan untuk upgrade ke Ultimate. Tile Pengaturan untuk pengguna Premium hanya "Premium aktif" + tombol "Kelola" (Play Store); `SubscriptionPage` hanya terbuka lewat gate fitur atau tile "Upgrade ke Premium" yang hanya tampil bagi yang belum Premium | `settings_page.dart:442-451` | Kartu Ultimate hanya terlihat oleh pengguna gratis; Ultimate tidak bisa dijual ke basis Premium | A3 |
| T2 | Pembelian Ultimate saat Premium aktif tidak memakai informasi penggantian produk. Premium dan Ultimate adalah dua langganan Play berbeda, jadi tanpa penggantian pengguna membayar dua langganan sekaligus | `subscription_status.dart:206` (`PurchaseParams.package(native)` polos) | Risiko tagihan ganda, keluhan, dan refund | A2 |
| T3 | Tidak ada penanda Ultimate di UI: pelanggan Ultimate tetap melihat "DompetKu Premium aktif"; judul halaman langganan selalu "DompetKu Premium" | `settings_page.dart:445`, `subscription_page.dart:61` | Pengguna tidak yakin paketnya benar | A3 |
| T4 | Sisa kuota tidak ditampilkan. Worker mengembalikan `remaining` tetapi klien mengabaikannya; pengguna baru tahu kuota habis saat menerima 429 | `handler.ts:112`, `ai_extraction_service.dart` | Pengalaman buruk di ujung bulan | A4 |
| T5 | Tidak ada ajakan upgrade ke Ultimate di alur Scan struk, padahal itu titik paling relevan bagi pelanggan Premium | `transaction_form_page.dart` (hanya `isUltimateProvider` di `_enhanceWithAi`) | Konversi Premium → Ultimate rendah | A5 |
| T6 | Verifikasi Worker memakai `appUserId` anonim RevenueCat tanpa bukti kepemilikan; penghitung kuota di KV tidak atomik; setiap permintaan (termasuk dari non-Ultimate) memicu panggilan ke RevenueCat | `handler.ts:83-105`, `index.ts` | Risiko rendah: ID sulit ditebak dan ada batas 60/bulan, tetapi bukan autentikasi sungguhan dan biaya AI bisa dikuras bila ID bocor | C |

### Kesenjangan rancangan awal vs implementasi

| Rancangan | Implementasi | Rencana |
|---|---|---|
| AI mengekstrak merchant, **total, item**, kategori (`RANCANGAN-AWAL.md` §2 "Fitur AI") | Hanya **nama toko dan kategori** (`Extraction` di `handler.ts`). Total dan tanggal tetap dari heuristik | B |
| — | Kelemahan yang sudah tercatat (total salah pada struk SPBU 2-kolom) tidak dibantu AI, sehingga nilai jual Ultimate terbatas pada kenyamanan mengisi toko dan kategori | B |
| Harga Ultimate Rp12.500/Rp125.000 | Ditetapkan 2026-09-29 tetapi rencana meminta dicek ulang sebelum diajukan ke Play | D (butir keputusan) |

### Fitur rancangan yang belum ada (di luar Ultimate)

Semuanya ❌ dan tanpa desain: sinkronisasi multi-device dan mode berdua/keluarga, laporan bulanan otomatis dan insight, multi-mata uang (di luar cakupan Android-Indonesia), widget home screen dan quick-add, input dari notifikasi bank, asisten AI berbasis chat, ekspor PDF/Excel, opsi lifetime dan uji coba gratis 7 hari, enkripsi database (SQLCipher). Kandidat isi Ultimate berikutnya yang paling dekat dengan gagasan awal: **insight otomatis** dan **asisten chat AI** (belum dijadwalkan).

## 7. Catatan konsistensi

- Halaman langganan menampilkan judul "DompetKu Premium" dan kalimat "Hilangkan iklan dan dukung pengembangan DompetKu"; manfaat per paket ada di `_premiumBenefits` dan `_ultimateBenefits` (`subscription_page.dart`). Butir "Scan struk" ditambahkan ke `_premiumBenefits` pada 2026-09-30 (belum dirilis; berlaku sejak versi 1.0.0+4).
- Deskripsi listing Play menaruh "Scan struk" di bawah Premium, sesuai kode.
- Pengguna Ultimate otomatis lolos semua gate Premium karena produknya dikaitkan ke dua entitlement.
- Akurasi ekstraksi AI, dan apakah kuota 60/bulan cukup, belum pernah diukur dengan data nyata.
