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
| Ekstraksi struk dengan AI: nama toko dan kategori terisi otomatis (kuota 60 scan/bulan) | ❌ | ❌ | ✅ | 🔴 Kode klien dan Worker selesai (Claude Haiku 4.5; tes 416 + 9 lulus). **Belum bisa dipakai**: lihat bagian 6 |

Cara kerja bila aktif: hasil OCR on-device diisi dulu oleh heuristik, lalu Ultimate meminta AI (Cloudflare Worker) menyempurnakan nama toko dan kategori. Tanpa `AI_EXTRACTION_URL`, fitur mati diam-diam dan scan tetap jalan dengan heuristik.

## 5. Ringkasan cakupan

| Paket | Jumlah fitur | Siap dipakai sekarang |
|---|---|---|
| Gratis | 13 inti + 3 dengan batas | Ya |
| Premium | Semua Gratis + 7 fitur Premium penuh, tanpa iklan, batas dibuka | Ya (produk aktif, RevenueCat valid; uji beli di HP belum dilakukan) |
| Ultimate | Semua Premium + 1 fitur AI | Belum |

## 6. Yang menghalangi Ultimate (semua belum dikerjakan)

| Butir | Status |
|---|---|
| Deploy Cloudflare Worker + kunci (`ANTHROPIC_API_KEY`, kunci REST RevenueCat, KV `RATE_LIMIT`) | ⬜ |
| Isi `AI_EXTRACTION_URL` saat build (`--dart-define`) | ⬜ |
| Produk Play `dompetku_ultimate` (base plan monthly Rp12.500 dan yearly Rp125.000) | ⬜ |
| Entitlement RevenueCat `ultimate`; produk Ultimate dikaitkan ke `ultimate` **dan** `premium` (lihat `revenuecat_config.dart`) | ⬜ |
| Paket Ultimate ditambahkan ke offering `dompetku` (kartu Ultimate baru muncul di halaman langganan bila paketnya ada) | ⬜ |
| Uji nyata dengan akun Ultimate | ⬜ |
| Kebijakan privasi: aliran AI (Cloudflare → Anthropic) sudah ditulis, tetapi Data Safety Play perlu disesuaikan saat Ultimate rilis | 🟡 |
| Bagian Ultimate di deskripsi listing Play sengaja dihapus; tambahkan lagi saat Ultimate rilis | ⬜ |

## 7. Catatan konsistensi

- Halaman langganan menampilkan judul "DompetKu Premium" dan kalimat "Hilangkan iklan dan dukung pengembangan DompetKu"; manfaat per paket ada di `_premiumBenefits` dan `_ultimateBenefits` (`subscription_page.dart`). Butir "Scan struk" ditambahkan ke `_premiumBenefits` pada 2026-09-30 (belum dirilis; berlaku sejak versi 1.0.0+4).
- Deskripsi listing Play menaruh "Scan struk" di bawah Premium, sesuai kode.
- Pengguna Ultimate otomatis lolos semua gate Premium karena produknya dikaitkan ke dua entitlement.
- Akurasi ekstraksi AI, dan apakah kuota 60/bulan cukup, belum pernah diukur dengan data nyata.
