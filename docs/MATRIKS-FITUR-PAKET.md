# Matriks Fitur per Paket Langganan — DompetKu

Disusun 2026-09-30 dari pemeriksaan langsung kode (`lib/`, `backend/`) dan dokumen `docs/`; **diperbarui 2026-10-01** setelah Ultimate selesai dikode dan infrastrukturnya dipasang. Angka tes: 490 Flutter + 38 Worker lulus.

**Legenda**
- Paket: ✅ tersedia penuh · 🟡 tersedia dengan batas · ❌ tidak tersedia
- Status implementasi: ✅ selesai dan diverifikasi · 🟡 selesai di kode, verifikasi belum lengkap · 🔴 kode ada tetapi belum bisa dipakai (butuh deploy/produk) · ⬜ belum dibuat

Harga (ditetapkan 2026-09-29): Premium Rp7.500/bulan atau Rp75.000/tahun; Ultimate Rp12.500/bulan atau Rp125.000/tahun.
Produk aktif di Play Console: **Premium** (`dompetku_premium`) dan **Ultimate** (`dompetku_ultimate`, base plan `monthly` dan `yearly`, hanya Indonesia, aktif 2026-09-30/10-01). Di RevenueCat kedua produk, entitlement `ultimate`, dan paket Custom `ultimate_monthly`/`ultimate_annual` di offering `dompetku` sudah disiapkan pemilik. Aplikasi yang beredar (rilis 3) belum memuat Ultimate; itu menunggu rilis 4.

## 1. Fitur inti (semua paket)

| Fitur | Gratis | Premium | Ultimate | Status implementasi |
|---|---|---|---|---|
| Transaksi pemasukan, pengeluaran, transfer | ✅ | ✅ | ✅ | ✅ |
| Multi-dompet / akun | ✅ | ✅ | ✅ | ✅ |
| Kategori, sub-kategori, tag | ✅ | ✅ | ✅ | ✅ |
| Anggaran bulanan + notifikasi | ✅ | ✅ | ✅ | ✅ Notifikasi anggaran terbukti di Galaxy Z Fold6 (2026-10-01): muncul saat aplikasi dibuka ulang (dicek tiap buka/kembali dari latar, bukan layanan latar), sekali per kategori per ambang |
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
| Backup cloud terenkripsi ke Google Drive pengguna (`drive.appdata`, AES) | ❌ | ✅ | ✅ | ✅ Terbukti di build Play (2026-10-01, Galaxy Z Fold6: login, cadangkan, pulihkan). Butuh client OAuth dengan SHA-1 APK terpasang (`DompetKu - Play (terpasang)`) dan scope `drive.appdata` di Data Access. Layar persetujuan OAuth sudah **In production** (2026-10-01; branding: beranda dompetku.hardan-ti.com, kebijakan privasi, domain hardan-ti.com; tanpa logo agar tidak perlu verifikasi; scope non-sensitif `drive.appdata`) |
| Pengingat transaksi berulang | ❌ (baris upsell) | ✅ | ✅ | ✅ |
| Proyeksi keuangan bulanan (Agenda + transaksi berulang) | ❌ (ajakan upgrade) | ✅ | ✅ | 🟡 Tes lulus; belum diverifikasi manual di HP dengan data nyata |
| Simulasi arus kas harian ("cukup sampai tanggal X") | ❌ | ✅ | ✅ | 🟡 Sama seperti proyeksi bulanan |
| Utang dan Piutang beserta cicilan | ❌ | ✅ | ✅ | ✅ Diverifikasi di HP; uji backup/restore tabel `debts` belum |
| Scan struk (OCR on-device ML Kit, parser heuristik, foto struk tersimpan) | ❌ | ✅ | ✅ | ✅ Diverifikasi di HP. Akurasi turun untuk struk kompleks (mis. SPBU); mode offline ML Kit belum dicek |
| Foto struk ikut backup cloud terenkripsi, dengan saklar "Sertakan foto struk" (default aktif; mati = foto tidak diunggah dan tidak diunduh saat restore) | ❌ | ✅ | ✅ | ✅ Round-trip backup dan restore diverifikasi di HP; saklar baru lulus tes otomatis (2026-10-02), belum dicoba di HP. Teks kebijakan privasi di repo sudah diperbarui, BELUM di-deploy ke server |
| Ekspor laporan Excel (.xlsx): lima lembar (Ringkasan, Transaksi dengan filter dan baris judul beku, Per Kategori, Per Bulan, Per Dompet); rentang bulan terpilih, 3 bulan terakhir, atau seluruh riwayat; dibuat di HP dan dibagikan lewat lembar bagikan (tanpa izin baru, tanpa server). CSV tetap gratis untuk backup/pindah data | ❌ | ✅ | ✅ | 🟡 Tes otomatis lulus dan berkas diuji terbuka di openpyxl (2026-10-04); belum dibuka di Excel/Google Sheets/HP nyata. Kebijakan privasi di repo diperbarui (bagian 7), BELUM di-deploy; Data Safety tidak berubah |
| Laporan Bulanan (Lainnya > Laporan Bulanan): total, sisa, sorotan otomatis berbasis aturan (naik/turun vs bulan lalu pada tanggal yang sama, kategori terbesar/naik/turun, anggaran terlampaui/hampir habis, taksiran akhir bulan, hari tanpa pengeluaran, rata-rata harian). Tanpa AI dan tanpa jaringan | ❌ | ✅ | ✅ | 🟡 Tes otomatis lulus; belum diuji di HP dengan data nyata. Tidak mengubah kebijakan privasi maupun Data Safety |
| Melihat kembali foto struk: ikon di daftar transaksi, baris "Foto struk" di formulir ubah (lihat/hapus), penampil layar penuh dengan zoom; tetap bisa dilihat walau paket turun ke Gratis; foto yatim dibersihkan saat app dibuka | ✅ (foto yang sudah ada) | ✅ | ✅ | ✅ Terbukti di perangkat nyata (build 10, 2026-10-03). 2026-10-03: miniatur foto kini langsung tampil di daftar transaksi dan pratinjau di formulir scan/ubah (build 11, belum diuji di perangkat) |

## 4. Fitur khusus Ultimate

| Fitur | Gratis | Premium | Ultimate | Status implementasi |
|---|---|---|---|---|
| Ekstraksi struk dengan AI: nama toko, kategori, **total, dan tanggal** terisi otomatis (kuota 300 scan/bulan, 15/hari) | ❌ | ❌ | ✅ | ✅ Terbukti di perangkat nyata (2026-10-01, lima scan 200, ≈ Rp4,6/scan; lihat RENCANA-ULTIMATE-LANJUTAN §9). Kode klien dan Worker selesai (Gemini saja, model `gemini-3.1-flash-lite` hasil eval 10 struk sintetis; Claude dibuang; 490 tes Flutter + 38 tes Worker lulus). **Worker sudah di-deploy** di `https://dompetku-api.hardan-ti.com/extract` (2026-10-01; cek entitlement ke RevenueCat terbukti jalan: id tak dikenal dijawab 403 `not_ultimate`). Jalur Gemini lewat Worker terbukti ujung ke ujung di perangkat nyata; akurasi pada banyak struk dan kecukupan kuota 300/bulan masih perlu diukur dari pemakaian sungguhan. Lihat [RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md](RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md) |
| **Multi buku kas**: pembukuan terpisah (mis. pribadi vs bisnis), masing-masing punya dompet, kategori, anggaran, transaksi berulang, agenda, utang/piutang, dan target sendiri; sampai 5 buku, pengalih buku di aplikasi | ❌ (satu Buku Utama) | ❌ (satu Buku Utama) | ✅ | ✅ Terbukti di perangkat nyata (2026-10-01, Galaxy Z Fold6, butir G1-G12 daftar centang lulus semua). Kode selesai dan diuji otomatis (skema v10, backup v7, pengalih, Kelola Buku Kas, operasi lintas buku; 30 tes DB + tes UI). Migrasi dari data rilis 3 sudah terjalani saat update di HP uji. Rincian: [RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md](RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md) |

Cara kerja ekstraksi AI bila aktif: hasil OCR on-device diisi dulu oleh heuristik, lalu Ultimate meminta AI (Cloudflare Worker) menyempurnakan nama toko dan kategori. Tanpa `AI_EXTRACTION_URL`, fitur mati diam-diam dan scan tetap jalan dengan heuristik.

## 5. Ringkasan cakupan

| Paket | Jumlah fitur | Siap dipakai sekarang |
|---|---|---|
| Gratis | 13 inti + 3 dengan batas | Ya |
| Premium | Semua Gratis + 7 fitur Premium penuh, tanpa iklan, batas dibuka | Ya (produk aktif, RevenueCat valid; uji beli di HP belum dilakukan) |
| Ultimate | Semua Premium + 2 fitur khusus (ekstraksi AI, multi buku kas) | Belum bisa dibeli pengguna: kode, Worker, produk Play, dan RevenueCat siap, tetapi aplikasi yang beredar belum memuatnya. Menunggu rilis 4 dan uji beli/uji migrasi di perangkat |

## 6. Yang menghalangi Ultimate (diperbarui 2026-10-01)

| Butir | Status |
|---|---|
| Deploy Cloudflare Worker + kunci (`GEMINI_API_KEY`, kunci REST RevenueCat V1, KV `RATE_LIMIT`) | ✅ 2026-10-01, domain `dompetku-api.hardan-ti.com`. Kunci Gemini belum terbukti ujung ke ujung |
| Isi `AI_EXTRACTION_URL` saat build (`--dart-define`) | ⬜ ikut rilis 4 |
| Produk Play `dompetku_ultimate` (base plan monthly Rp12.500 dan yearly Rp125.000) | ✅ aktif |
| Entitlement RevenueCat `ultimate`; produk Ultimate dikaitkan ke `ultimate` **dan** `premium` (lihat `revenuecat_config.dart`) | ✅ dikerjakan pemilik (belum saya verifikasi di dasbor) |
| Paket Ultimate ditambahkan ke offering `dompetku` (Custom: `ultimate_monthly`, `ultimate_annual`) | ✅ dikerjakan pemilik |
| Uji nyata dengan akun Ultimate | ✅ 2026-10-01 (lima scan 200; beberapa struk berbeda valid) |
| Kebijakan privasi: Anthropic → Google (Gemini API berbayar), buku kas, kuota harian | ✅ online 2026-10-01 (klaim tentang ketentuan Google perlu dicocokkan pemilik) |
| Data Safety Play | ✅ disimpan 2026-10-01 (belum dikirim untuk ditinjau; ikut rilis 4). Lihat [DATA-SAFETY-PLAY.md](DATA-SAFETY-PLAY.md) |
| Penyedia AI: eval 10 struk sintetis, model `gemini-3.1-flash-lite` dipilih; wajib Gemini **paid tier** dengan project Google Cloud terpisah | ✅ (eval); anggaran biaya Cloud Billing ⬜ |
| Teks Ultimate di deskripsi listing Play | 🟡 teks final siap di [LISTING-PLAY-STORE.md](LISTING-PLAY-STORE.md); dipasang bersama rilis 4 |
| Rilis 4 (`1.0.0+4`): build AAB, uji internal, uji migrasi Redmi (F7), uji beli + penggantian Premium → Ultimate | ⬜ |
| Cek target audiens Play (klausul di bawah 18 tahun pada ketentuan Gemini) | ⬜ |

## 6b. Temuan audit Ultimate (2026-09-30)

Audit dokumen rancangan (`RANCANGAN-AWAL.md`, `RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md`) terhadap kode. Rencana perbaikan tiap temuan ada di [RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md](RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md); kolom terakhir merujuk ke butirnya.

> **Status 2026-10-01:** semua temuan di bagian ini sudah dikerjakan di kode dan lulus tes otomatis. T1 (jalur upgrade Premium → Ultimate), T2 (penggantian produk, `oldProductId`), T3 (penanda Ultimate), T4 (sisa kuota), T5 (ajakan upgrade di Scan struk), T6 (cache entitlement, batas harian 15, pembatas IP opsional) dan kesenjangan AI (total + tanggal kini diekstrak). Yang tersisa hanya **verifikasi di perangkat nyata**, terutama penggantian produk (`oldProductId`) yang baru bisa dipastikan lewat uji beli.

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
- Akurasi ekstraksi AI, dan apakah kuota 300/bulan cukup, belum pernah diukur dengan data nyata.
