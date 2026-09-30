# Gap Analisa — Rancangan vs Implementasi (21 September 2026)

Membandingkan rancangan awal Dompet Pintar dengan kondisi kode saat ini, untuk menentukan apa yang masih
kurang sebelum rilis. Catatan sesi (keputusan, batasan, pelajaran) ada di
[CATATAN-SESI-2026-09-21.md](CATATAN-SESI-2026-09-21.md).

## 1. Dasar perbandingan

Tidak ada dokumen perencanaan berupa berkas di proyek. Rancangannya hanya ada di riwayat sesi Claude pertama
(`~/.claude/projects/-home-dimas-Claude-Dompet-Pintar/2c734d1c-0c68-46a6-ac29-89e9a77b10b0.jsonl`, pesan pertama
asisten, 21 Sep 2026 04:22), berupa:

1. **Rancangan awal**: fitur MVP/Fase 2/Fase 3, arsitektur, model data, monetisasi, syarat store, roadmap.
2. **Rencana tahap Android**: 5 langkah (project Flutter, struktur + Drift + Riverpod, skema, layar MVP, analyze/tes/APK).

Catatan agar tidak salah membaca hasilnya:

- Keduanya **usulan asisten dalam percakapan**, bukan PRD yang disetujui. Salinan apa adanya kini tersimpan di
  [RANCANGAN-AWAL.md](RANCANGAN-AWAL.md), jadi analisa ini tidak lagi bergantung pada berkas riwayat sesi.
- Batasan yang ditambahkan pemilik kemudian dianggap koreksi resmi: dikerjakan sendiri dengan bantuan AI, khusus
  Indonesia, Android dulu. Karena itu **iOS, multi-mata uang, dan Sign in with Apple bukan gap**.
- Fakta kebijakan store dan harga di rancangan berasal dari pengetahuan umum saat itu dan **perlu diverifikasi ulang**.
- Status kode diperiksa langsung di sumber (skema, `pubspec.yaml`, manifest, pencarian kata kunci). Kondisi saat
  dianalisa: 199 tes lolos, analyzer bersih, ±7.750 baris Dart di `lib/`, 19 berkas tes.

## 2. Ringkasan

| Cakupan | Hasil |
|---|---|
| Inti MVP (8 butir) | 5 lengkap, 3 sebagian |
| Fase 2 (7 butir) | 1 lengkap (target tabungan) |
| Fase 3 | belum ada |
| Monetisasi | belum ada |
| Persiapan rilis dan kepatuhan | belum dimulai |

Gap terbesar bukan fitur, melainkan **jalur rilis**: uji tertutup Play Store butuh 12 tester × 14 hari (verifikasi
ulang kebijakannya) dan masa tunggu itu berjalan sendiri, jadi makin awal dimulai makin baik.

## 3. Fitur MVP

| Rancangan | Status | Gap |
|---|---|---|
| Transaksi: pemasukan, pengeluaran, transfer, "maks. 3 tap" | ✅ | Jumlah tap belum diukur |
| Multi-dompet (tunai, bank, e-wallet, kartu) | ✅ | Ubah dan arsip dompet selesai 21 Sep |
| Kategori, sub-kategori, tag | 🟡 | Kategori kustom ada (tambah/ubah/arsip). **Sub-kategori dan tag tidak ada**: skema tanpa `parent_id` dan tabel tag |
| Anggaran bulanan per kategori + notifikasi | 🟡 | Progress bar (oranye 80%, merah bila lewat) ada. **Notifikasi tidak ada**: tidak ada paket notifikasi di `pubspec.yaml` |
| Dashboard: saldo, arus kas, grafik kategori, tren 6 bulan | 🟡 | Tiga pertama ada. **Tren 6 bulan tidak ada** |
| Transaksi berulang | ✅ | Dicatat saat aplikasi dibuka/dilanjutkan, bukan pekerjaan latar belakang |
| Ekspor CSV, backup dan restore | ✅ | Backup dan CSV tidak terenkripsi |
| PIN atau biometrik | ✅ | Kunci level aplikasi, bukan enkripsi data |
| Onboarding singkat (langkah 4 rencana Android) | ❌ | Tidak ada halaman onboarding |

## 4. Arsitektur dan model data

### Sesuai rancangan
Flutter, Riverpod (v3), SQLite via Drift, offline-first, uang sebagai integer Rupiah, ID UUID v7 dari klien, saldo
dihitung (bukan disimpan), backup JSON berversi, migrasi terverifikasi lintas versi (v1, v2, v3).

### Menyimpang
| Rancangan | Kenyataan | Dampak |
|---|---|---|
| Layer Presentation / Application / Domain / Repository | Kode datar. `lib/data/database.dart` (±1.380 baris) memuat skema, query, dan aturan domain; halaman memakai `AppDatabase` lewat provider | Utang teknis: sinkronisasi (`Remote`) tidak punya tempat yang jelas |
| Soft delete + `updated_at` di semua tabel | `deleted_at` hanya ada di `transactions` dan `goal_contributions`. Aturan berulang, target, dan anggaran **dihapus permanen** | Sinkronisasi tidak bisa menyebarkan penghapusan. **README ([README.md:31](../README.md)) salah mengklaim "di semua tabel"** |
| `recurring_rule.rrule` | Frekuensi + tanggal mulai + indeks kejadian berikutnya | Sengaja: lebih sederhana dan tes membuktikan tidak ada drift tanggal (31 Jan → 28 Feb → 31 Mar) |
| `goal.terkumpul` disimpan | Dihitung dari setoran dikurangi penarikan | Sengaja: tidak bisa tidak sinkron |
| `budget.periode` | Satu nilai per kategori yang berlaku tiap bulan | Tidak ada riwayat atau nilai berbeda per bulan |
| `transaction.device_id` | Tidak ada | Dibutuhkan untuk sinkronisasi |
| `account.mata_uang`, `category.parent_id`, tabel `attachment` | Tidak ada | `attachment` dibutuhkan untuk OCR struk (Fase 2) |
| Sinkronisasi (last-write-wins, hybrid clock) | Belum ada | Perhatian: Drift menyimpan `DateTime` presisi detik |
| Package aplikasi `id.dompetpintar.app` (rencana Android) | `id.dompetpintar.dompet_pintar` (otomatis dari nama project) | Permanen setelah rilis; belum diputuskan |

### Tidak dibangun (Fase 2/3 dan infrastruktur)
Supabase (backend, Auth, RLS), Firebase Analytics/Crashlytics, FCM dan notifikasi lokal, RevenueCat, CI/CD
(GitHub Actions/Fastlane). Proyek ini belum berupa repositori git.

## 5. Keamanan dan kepatuhan

| Rancangan | Status |
|---|---|
| Database terenkripsi (SQLCipher), kunci di Keystore | ❌ Tidak ada. Hash PIN memang di Keystore |
| PIN dan biometrik (`local_auth`) | ✅ PBKDF2-SHA256, penguncian bertingkat sampai 15 menit |
| Kunci privasi: `allowBackup=false` | ✅ Terverifikasi di manifest |
| Fitur **hapus akun dan data** (wajib di store) | ❌ Tidak ada (pencarian di `lib/`) |
| Kebijakan privasi, syarat layanan, persetujuan UU PDP | ❌ |
| Data Safety (Play) | ❌ |
| Penutup tampilan "recent apps" | 🟡 Best-effort, belum `FLAG_SECURE` |

## 6. Monetisasi

Belum ada satu pun: paywall, RevenueCat, batas gratis (3 dompet, 3 anggaran, riwayat 3 bulan), iklan, referral, dan
analitik konversi. Aplikasi saat ini tanpa pembatasan. Konsekuensinya batas gratis belum bisa diuji ke pengguna,
dan struktur harga masih hipotesis.

## 7. Rilis dan roadmap

| Fase rancangan | Status |
|---|---|
| 0. Validasi (wawancara 10–15 calon pengguna, analisis kompetitor) | ❌ Tidak ada bukti dikerjakan. Positioning (privasi / lokalisasi / kecepatan) **belum dipilih** |
| 1. Desain (Figma, design system, onboarding) | 🟡 Design system ada di kode (`theme.dart`, gelap-dulu, tes kontras). Tanpa Figma dan tanpa onboarding |
| 2. MVP | 🟡 Lihat bagian 3 |
| 3. Beta tertutup (20–50 tester) | ❌ |
| 4. Rilis v1 | ❌ |

Prasyarat rilis yang belum ada: keputusan Application ID, signing rilis (masih kunci debug,
`android/app/build.gradle.kts`), ikon kustom, halaman kebijakan privasi, email dukungan, akun developer (belum
diverifikasi).

## 8. Fase 2 dan 3

| Butir | Status |
|---|---|
| Scan struk (OCR) | ❌ |
| Target tabungan | ✅ Model penanda dana (tidak mengubah saldo dompet), belum disetujui eksplisit oleh pemilik |
| Utang/piutang | ❌ |
| Sinkronisasi dan mode berdua | ❌ |
| Laporan bulanan otomatis dan insight | ❌ |
| Multi-mata uang | ❌ (di luar cakupan: khusus Indonesia) |
| Widget home screen dan quick-add | ❌ |
| Fase 3: input dari notifikasi bank, agregator, asisten AI | ❌ |

## 9. Di luar rancangan (sudah dibangun)

Tema gelap-dulu dengan pemilih tema, arsip kategori dan dompet, validasi backup penuh (konsistensi tipe transaksi,
isi minimum), penguncian PIN bertingkat, tes kontras WCAG, dan lokalisasi awal (kategori "Bonus / THR", "Sedekah &
Donasi"). Tiga cacat visual yang hanya terlihat di HP juga sudah diperbaiki.

## 10. Prioritas yang diusulkan

**P0 — menentukan jadwal rilis (bisa mulai sekarang)**
1. Putuskan Application ID; siapkan signing rilis dan ikon.
2. Kebijakan privasi dan fitur hapus data (syarat uji tertutup dan Data Safety).
3. Mulai uji tertutup secepatnya.

**P1 — menutup janji MVP**
4. Notifikasi anggaran mendekati batas.
5. Tren 6 bulan di Ringkasan.
6. Onboarding singkat.
7. Enkripsi database (SQLCipher) sebelum ada klaim "aman".

**P2 — utang teknis sebelum sinkronisasi**
8. `deleted_at` di semua tabel dan `device_id`; koreksi klaim di README.
9. Lapisan repository/domain.
10. Anggaran per periode (bila dibutuhkan).

## 11. Keputusan yang menunggu pemilik

1. Application ID permanen.
2. Apakah sub-kategori dan tag tetap masuk rencana atau sengaja dilewatkan.
3. Apakah Fase 0 (validasi pengguna) dijalankan atau dilewati, dan memilih satu positioning utama.
4. Persetujuan eksplisit atas model target tabungan (penanda dana).
5. Struktur harga dan batas gratis, sebelum paywall dibangun.
