# Gap Analisa — Rancangan vs Implementasi (23 September 2026)

Pembaruan dari [GAP-ANALISA-2026-09-21.md](GAP-ANALISA-2026-09-21.md) setelah dua sesi kerja tambahan (22–23
September). Dasar perbandingan sama seperti sebelumnya: [RANCANGAN-AWAL.md](RANCANGAN-AWAL.md) (usulan asisten,
bukan PRD yang disetujui). Kondisi kode diperiksa langsung di sumber pada tanggal dokumen ini: **253 tes lolos**
(naik dari 199), skema DB **v4** (naik dari v3), ±18.000 baris Dart di `lib/` (termasuk kode hasil generate Drift),
26 berkas tes.

## 1. Ringkasan perubahan sejak 21 September

| Cakupan | 21 Sep | 23 Sep |
|---|---|---|
| Inti MVP (9 butir) | 5 lengkap, 3 sebagian, 1 tidak ada | **8 lengkap**, 1 sebagian (jumlah tap belum diukur — tidak krusial) |
| Jalur rilis | belum dimulai | **Signing selesai**, hapus-data selesai, draf kebijakan privasi hampir selesai (menunggu 2 placeholder) |
| Monetisasi | belum ada | tetap belum ada |
| Fase 2/3 | 1 lengkap (target tabungan) | tidak berubah |

**Selesai di sesi 22–23 September** (lihat `~/.claude/projects/.../memory/dompet-pintar-project.md` untuk detail):
1. **Notifikasi anggaran** — lokal, dicek saat app dibuka/resume, dedup per kategori/bulan/ambang (80%/100%).
2. **Sub-kategori & tag** (skema v3→v4) — `Categories.parentId` (satu level), tabel `Tags`/`TransactionTags`.
3. **Tren 6 bulan** — grafik batang di Ringkasan, bucket bulan dihitung di Dart (bukan `strftime` SQL) untuk
   menghindari bug zona waktu WIB vs UTC.
4. **Onboarding singkat** — 3 slide, tampil sekali via `_StartupGate`, bisa dibuka ulang dari Pengaturan.
5. **Signing rilis** — keystore upload dibuat, `key.properties` di-gitignore, terverifikasi lewat `apksigner`.
6. **Fitur hapus semua data** — reset total (data keuangan + PIN + tema + status onboarding), PIN-gated,
   diverifikasi di HP sungguhan (data uji nyata dihapus dengan izin eksplisit pemilik).
7. **Application ID diputuskan**: `com.hardanti.lacipintar`. **Nama tampilan**: "DompetKu" (bukan lagi "Dompet
   Pintar" di UI/label — identitas internal seperti nama paket Dart dan nama berkas DB sengaja tidak diubah).
8. **Draf kebijakan privasi** — dibuat sebagai dokumen Claude Docs (bahasa Indonesia, akurat terhadap kode: secara
   eksplisit menyebut aplikasi TIDAK punya izin `INTERNET` di manifest sebagai bukti data tak bisa dikirim keluar).
   **Belum final**: 2 placeholder (nama pengembang, email dukungan) menunggu diisi, dan dokumen masih privat —
   perlu URL publik untuk Play Console Data Safety form.
9. Bug lama ditemukan saat verifikasi manual (SnackBar bisa nyangkut di layar) — **sudah diperbaiki**
   (`clearSnackBars()` sebelum `showSnackBar()` di [lib/core/widgets.dart:165](../lib/core/widgets.dart:165)).

## 2. Fitur MVP (status terkini)

| Rancangan | Status | Catatan |
|---|---|---|
| Transaksi: pemasukan, pengeluaran, transfer | ✅ | Jumlah tap belum diukur, tidak dianggap gap |
| Multi-dompet | ✅ | |
| Kategori, sub-kategori, tag | ✅ | **Selesai 22 Sep** — sebelumnya sebagian |
| Anggaran bulanan + notifikasi | ✅ | **Notifikasi selesai 22 Sep** — sebelumnya tanpa notifikasi |
| Dashboard: saldo, arus kas, grafik kategori, tren 6 bulan | ✅ | **Tren 6 bulan selesai 22 Sep** |
| Transaksi berulang | ✅ | Masih dicatat saat app dibuka, bukan pekerjaan latar belakang (sengaja, offline-first) |
| Ekspor CSV, backup dan restore | ✅ | Backup dan CSV tetap tidak terenkripsi |
| PIN atau biometrik | ✅ | Kunci level aplikasi, bukan enkripsi data |
| Onboarding singkat | ✅ | **Selesai 22 Sep** |

Semua 9 butir MVP kini lengkap secara fungsional.

## 3. Keamanan dan kepatuhan

| Rancangan | Status | Perubahan |
|---|---|---|
| Database terenkripsi (SQLCipher) | ❌ | Belum — masih gap terbesar yang tersisa dari sisi keamanan |
| PIN dan biometrik | ✅ | Tidak berubah |
| `allowBackup=false` | ✅ | Tidak berubah |
| **Fitur hapus akun dan data** | ✅ | **Selesai 22 Sep** — sebelumnya tidak ada |
| **Kebijakan privasi** | 🟡 | **Draf selesai, belum final** — 2 placeholder + perlu URL publik |
| Syarat layanan, persetujuan UU PDP | ❌ | Tidak berubah |
| Data Safety (Play Console) | ❌ | Belum dimulai — butuh akun Play Console pemilik |
| Penutup tampilan "recent apps" (`FLAG_SECURE`) | 🟡 | Tidak berubah — masih best-effort |

## 4. Model data — masih menyimpang dari rancangan awal

`deleted_at` masih hanya ada di 2 dari 9 tabel sekarang (`transactions`, `goal_contributions`) — **belum berubah**
sejak 21 Sep, walau jumlah tabel bertambah (`Tags`/`TransactionTags` baru, keduanya sengaja hard-delete). Tabel
lain yang dihapus permanen: `recurring_rules`, `budgets`, `savings_goals`, `categories`, `accounts`. Ini tetap
utang teknis untuk sinkronisasi di masa depan, bukan bug aktif. `device_id`, lapisan repository/domain, dan
`account.mata_uang` juga masih tidak ada — tidak berubah dari analisa sebelumnya.

## 5. Monetisasi — tidak berubah

Masih belum ada satupun: paywall, RevenueCat, batas gratis, iklan, referral, analitik konversi. Belum jadi
prioritas karena jalur rilis awal (closed testing) tidak mensyaratkannya.

## 6. Fase 2 dan 3 — tidak berubah

Scan struk (OCR), utang/piutang, sinkronisasi, laporan otomatis/insight, widget home screen, input dari notifikasi
bank — semuanya masih ❌, sama seperti 21 September. Target tabungan tetap satu-satunya butir Fase 2 yang selesai.

## 7. Jalur rilis — progres detail

| Langkah | Status |
|---|---|
| Application ID + nama tampilan | ✅ Diputuskan dan diterapkan (`com.hardanti.lacipintar`, "DompetKu") |
| Ikon kustom | ✅ (dari sesi 21 Sep) |
| Signing rilis | ✅ Selesai 22 Sep, terverifikasi `apksigner` |
| Fitur hapus akun/data | ✅ Selesai 22 Sep, diverifikasi di HP |
| Kebijakan privasi | 🟡 Draf lengkap, menunggu 2 placeholder + publikasi URL |
| Data Safety form (Play Console) | ❌ Belum dimulai — perlu akun pemilik |
| Uji tertutup (12 tester × 14 hari) | ❌ Belum dimulai — perlu akun pemilik terverifikasi |
| Rilis v1 | ❌ |

Gap terbesar yang tersisa di jalur rilis kini murni **pekerjaan di Play Console yang hanya bisa dilakukan pemilik**
(butuh login akun developer): mengisi Data Safety form dan memulai uji tertutup. Masa tunggu 12×14 hari itu
sebaiknya mulai berjalan sesegera kebijakan privasi final dan punya URL publik.

## 8. Prioritas yang diusulkan (pembaruan)

**P0 — selesaikan jalur rilis (bisa mulai sekarang)**
1. Isi placeholder kebijakan privasi (nama pengembang, email dukungan) dan publikasikan ke URL publik.
2. Isi Data Safety form di Play Console.
3. Mulai uji tertutup — makin awal makin baik karena masa tunggunya berjalan sendiri.

**P1 — menutup gap keamanan yang tersisa**
4. Enkripsi database (SQLCipher) sebelum ada klaim "aman" di kebijakan privasi/materi pemasaran.
5. `FLAG_SECURE` untuk mencegah cuplikan layar di "recent apps" menampilkan data keuangan.

**P2 — utang teknis sebelum sinkronisasi (tidak mendesak untuk rilis)**
6. `deleted_at` di seluruh tabel + `device_id`; perbaiki klaim README bila masih salah.
7. Lapisan repository/domain (kode saat ini masih flat, `database.dart` memuat skema + query + aturan domain).

**P3 — setelah rilis awal berjalan**
8. Monetisasi (struktur harga, batas gratis, RevenueCat) — tunggu sinyal dari uji tertutup dulu.
9. Fase 2 (OCR struk, sinkronisasi) sesuai prioritas yang terlihat dari feedback tester.

## 9. Keputusan yang menunggu pemilik

1. Nama pengembang/perusahaan dan email dukungan untuk kebijakan privasi (satu-satunya blocker langsung saat ini).
2. Struktur harga dan batas gratis, sebelum paywall dibangun (belum mendesak).
3. Apakah Fase 0 (validasi pengguna) dijalankan sebelum atau paralel dengan uji tertutup.
4. Prioritas P1 vs P0 — apakah SQLCipher dikerjakan sebelum atau sesudah mulai uji tertutup (tidak memblokir Data
   Safety form karena "tidak terenkripsi" bisa dijawab jujur di sana).
