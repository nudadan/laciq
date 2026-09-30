# DompetKu

Aplikasi manajemen keuangan pribadi untuk pengguna di Indonesia. Tahap awal: **Android**, offline-first.

## Dokumen

Folder [`docs/`](docs/) berisi dokumen proyek. Yang paling operasional dibaca lebih dulu.

| Dokumen | Isi |
|---|---|
| [`CATATAN-SESI-2026-09-21.md`](docs/CATATAN-SESI-2026-09-21.md) | Keputusan produk dan alasannya, konvensi yang tidak boleh dilanggar, keputusan yang masih terbuka, lingkungan pengembangan, pelajaran dari kesalahan, serta pemisahan yang terbukti vs yang baru diasumsikan. |
| [`GAP-ANALISA-2026-09-21.md`](docs/GAP-ANALISA-2026-09-21.md) | Perbandingan rancangan awal dengan implementasi: apa yang sudah, sebagian, dan belum ada, beserta prioritas menuju rilis. |
| [`RANCANGAN-AWAL.md`](docs/RANCANGAN-AWAL.md) | Rancangan awal (fitur, arsitektur, monetisasi, syarat store, roadmap), disalin apa adanya. Ini usulan, bukan PRD yang disetujui. |

## Menjalankan

Toolchain (Flutter, JDK 17, Android SDK) terpasang di `~/development`.

```bash
source ~/development/env.sh
flutter pub get
dart run build_runner build      # generate kode Drift (wajib setelah mengubah lib/data/database.dart)
flutter test
flutter run                      # perangkat/emulator Android
flutter build apk --debug        # build/app/outputs/flutter-apk/app-debug.apk
```

## Arsitektur

```
lib/
  core/      format Rupiah, gaya kategori, widget bersama
  data/      database.dart (skema + query Drift), providers.dart (Riverpod)
  features/  dashboard, transactions, budget, accounts
```

- **Offline-first**: SQLite lokal (Drift) adalah sumber kebenaran. Tidak ada backend di MVP.
- **Uang = integer Rupiah** (tanpa desimal), tidak pernah `double`.
- **Soft delete** (`deleted_at`) dan `updated_at` di semua tabel, disiapkan untuk sinkronisasi.
- **ID = UUID v7** dibuat di klien; kategori/dompet bawaan memakai ID tetap (`cat-exp-makan`, `acc-tunai`).
- Urutan enum `TxType`/`AccountKind` disimpan sebagai index: **jangan diubah urutannya**.
- Saldo dompet dihitung dari saldo awal + transaksi (bukan disimpan), jadi tidak bisa tidak sinkron.

## Desain (tampilan)

Gelap-dulu, aksen elektrik cyan-violet, sudut sangat membulat, angka besar bergaya teknis.
Semua warna/bentuk terpusat agar layar konsisten:

- `lib/core/theme.dart`: ColorScheme terang/gelap, `AppPalette` (warna makna keuangan: pemasukan, pengeluaran, transfer,
  peringatan; ambil dengan `context.palette`), tipografi, dan gaya komponen Material.
- `lib/core/glass.dart`: `AmbientBackground`, `GlassCard`, `GlassBar` (navigasi melayang), `GradientFab`, `AnimatedAmount`,
  `RingProgress`, `CategoryBadge`. `lib/core/widgets.dart`: `FieldTile`, `GradientBar`, `notify`.
- Font variabel dibundel di `assets/fonts/` (Space Grotesk untuk angka/judul, Plus Jakarta Sans untuk teks; lisensi OFL
  ada di folder yang sama). Bobot lewat `FontVariation('wght')`, bukan `FontWeight` saja.
- Mode tema (Sistem/Terang/Gelap) disimpan di penyimpanan aman; bawaan **gelap**.
- **Kontras dijaga oleh `test/theme_test.dart`** (WCAG: teks 4,5:1, hint/aksen 3:1). Kalau mengganti warna, tes ini yang
  memberi tahu apakah masih terbaca. Jangan pakai `Colors.green`/`scheme.error` untuk makna pemasukan/pengeluaran.
- Halaman tab memberi ruang bawah `kBottomPad` agar tidak tertutup navigasi melayang; halaman yang di-push membungkus isi
  dengan `SafeArea(top: false)` karena aplikasi edge-to-edge.

## Keamanan & data

- **Kunci PIN 6 digit** (+ opsional sidik jari/wajah). PIN di-hash PBKDF2-HMAC-SHA256 + salt acak di Android Keystore
  (`flutter_secure_storage`). 5 kali salah beruntun mengunci input 30 dtk, berlipat ganda tiap putaran, maks. 15 menit,
  dan bertahan setelah aplikasi ditutup. Terkunci lagi setelah >30 dtk di latar belakang; isi ditutup di app switcher.
- **Batasan penting:** ini kunci di level aplikasi, BUKAN enkripsi database. Data di penyimpanan privat aplikasi tetap
  tidak terenkripsi (perangkat ter-root / akses fisik bisa membacanya). Enkripsi database (SQLCipher) belum ada.
- PIN **tidak bisa dipulihkan**. Lupa PIN = hapus data aplikasi, jadi backup rutin penting.
- `allowBackup="false"`: Android tidak menyalin database ke Google Drive secara otomatis. Satu-satunya jalur
  cadangan adalah fitur Backup di Pengaturan.
- **Ekspor CSV**: pemisah `;` + BOM UTF-8 (agar Excel regional Indonesia langsung membaca kolom), sel teks dinetralkan
  dari formula injection.
- **Backup/Restore**: JSON berversi (`format`, `version`), divalidasi penuh sebelum menyentuh data, dipulihkan dalam
  satu transaksi (gagal = data lama utuh). File backup TIDAK terenkripsi.

## Transaksi berulang

- Aturan (`RecurringRules`) menyimpan **tanggal mulai + indeks kejadian berikutnya**; tanggal dihitung dari jangkar
  (`occurrenceAt`), bukan dari kejadian sebelumnya. Jadi "tiap tgl 31" jadi 28 Feb lalu kembali 31 Mar (tanpa drift).
- Transaksi nyata dibuat oleh `generateDueRecurring` saat aplikasi dibuka dan saat kembali dari latar belakang.
  Bukan pekerjaan latar belakang: kalau aplikasi tidak dibuka, transaksi baru tercatat saat dibuka lagi
  (dengan tanggal yang benar).
- **Idempoten**: ID transaksi = `rec-<aturan>-<indeks>`, jadi menjalankan generator berulang tidak menggandakan.
  Transaksi hasil generate yang dihapus pengguna tidak dibuat ulang.
- Mengubah aturan hanya berlaku untuk transaksi berikutnya. Jadwal (mulai/frekuensi) tidak bisa diubah; buat aturan baru.
- Dijeda lalu dilanjutkan: periode yang terlewat dilewati, tidak dicatat mundur.

## Migrasi database (WAJIB dibaca sebelum mengubah skema)

Skema sudah di **v2** dan ada di perangkat pengguna. Setiap perubahan skema:
1. Naikkan `schemaVersion` dan tulis langkah di `onUpgrade` (`lib/data/database.dart`).
2. `dart run drift_dev schema dump lib/data/database.dart drift_schemas/`
3. `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`
4. Tambah/ubah tes di `test/migration_test.dart` (mengisi data di skema lama, migrasi, cek data utuh).
5. Naikkan `BackupService.formatVersion` bila format backup berubah, dan pertahankan pembacaan versi lama.

Jangan pernah mengedit `drift_schemas/drift_schema_v*.json` yang sudah dirilis.

## Status

Selesai: dompet, kategori, catat pemasukan/pengeluaran/transfer, daftar transaksi (geser untuk hapus + batal),
anggaran bulanan, ringkasan + grafik, kunci PIN/biometrik, ekspor CSV, backup/restore, ubah transaksi,
transaksi berulang (mingguan/bulanan/tahunan, tanggal berakhir, jeda).

## Roadmap

1. Edit kategori, target tabungan, pengingat tagihan (notifikasi)
2. Application ID final + signing + rilis tertutup Play Store (12 tester x 14 hari)
3. Enkripsi backup (kata sandi) dan database (SQLCipher)
4. Langganan Premium (RevenueCat), sinkronisasi cloud (Supabase), scan struk
