# Rencana Implementasi — Multi Buku Kas (Ultimate)

> Dibuat 2026-09-30 atas permintaan pemilik: pengguna yang perlu memisahkan pembukuan (mis. pribadi vs bisnis)
> belum terlayani karena aplikasi hanya punya satu pembukuan. Fitur ini juga memperlebar selisih Premium vs Ultimate
> (Ultimate = ekstraksi AI + multi buku kas). Belum ada kode yang diubah. Melengkapi
> [RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md](RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md) dan
> [MATRIKS-FITUR-PAKET.md](MATRIKS-FITUR-PAKET.md). Skema saat ini v9, format backup v6.

## 1. Definisi dan cakupan

**Buku kas** = wadah pembukuan terpisah. Isinya sendiri-sendiri: dompet, kategori (dan sub-kategori), anggaran,
transaksi, transaksi berulang, agenda, utang/piutang, dan target tabungan. Saldo, laporan, tren, dan proyeksi selalu
dihitung per buku aktif, tidak bercampur.

- **Gratis dan Premium**: tepat satu buku, "Buku Utama". Perilaku aplikasi sekarang tidak berubah sama sekali.
- **Ultimate**: sampai 5 buku (batas bisa diubah, lihat K3), dengan pengalih buku di aplikasi.

### Di luar lingkup versi pertama (dicatat, bukan dijanjikan)
| Ide | Alasan ditunda | Solusi sementara |
|---|---|---|
| Ringkasan gabungan semua buku | Mencampur pribadi dan bisnis adalah kebalikan tujuan fitur ini; butuh desain tampilan sendiri | Pindah buku satu per satu |
| Transfer antar buku (mis. tarik modal bisnis ke pribadi) | Butuh pasangan transaksi lintas buku dan aturan pembatalan | Catat manual: pengeluaran di satu buku, pemasukan di buku lain |
| Berbagi buku dengan orang lain / multi-pengguna | Aplikasi belum punya sinkronisasi | — |
| Tag per buku | Lihat K4 | Tag global |

## 2. Keputusan yang menunggu pemilik

| # | Keputusan | Rekomendasi |
|---|---|---|
| K1 | Perilaku saat Ultimate berakhir | **Kunci, jangan hapus**: hanya Buku Utama yang bisa dipakai; buku lain disembunyikan dan datanya tetap utuh (pola sama Agenda: turun ke gratis tanpa memaksa hapus data). Di halaman Kelola buku, buku terkunci tetap terlihat dengan tombol **Ekspor CSV** dan ajakan berlangganan |
| K2 | Transaksi berulang di buku terkunci | Dijeda (tidak menghasilkan transaksi diam-diam di buku tersembunyi). Saat Ultimate aktif lagi, `generateDueRecurring` menyusulnya dari indeks terakhir |
| K3 | Batas jumlah buku | 5. Cukup untuk pribadi + beberapa usaha, dan membatasi beban query serta risiko penyalahgunaan |
| K4 | Tag: global atau per buku | Global untuk versi pertama (tag adalah label bebas; memecahnya menambah pekerjaan tanpa manfaat besar). Bisa dipecah nanti dengan migrasi terpisah |
| K5 | Template buku baru | Tiga pilihan: **Pribadi** (kategori sekarang), **Bisnis** (kategori usaha, lihat §5), **Kosong** (hanya satu dompet Tunai; pengguna membuat kategori sendiri) |
| K6 | Rilis Ultimate menunggu fitur ini? | Rekomendasi: ya, jika ingin Ultimate diluncurkan dengan dua pembeda sekaligus. Bila tidak, Ultimate bisa rilis dulu dengan AI saja dan buku kas menyusul di rilis berikutnya; fase A–E rencana lain tidak bergantung pada fase ini |
| K7 | Harga Ultimate perlu ditinjau ulang karena isinya bertambah | Konfirmasi bersama K3 di rencana lanjutan; jangan diubah sebelum ada data konversi |

## 3. Model data

### 3.1 Tabel baru dan kolom baru (skema v9 → v10)

| Perubahan | Rincian |
|---|---|
| Tabel `Ledgers` | `id` (teks, kunci), `name` (1–40), `icon`, `color`, `sortOrder`, `archived`, `createdAt`, `updatedAt`. Baris bawaan `ledger-main`, nama "Buku Utama" |
| `ledgerId` di `Accounts` | default `ledger-main` |
| `ledgerId` di `Categories` | default `ledger-main`; induk dan sub-kategori wajib satu buku |
| `ledgerId` di `SavingsGoals` | default `ledger-main` |
| `ledgerId` di `AgendaReminders` | default `ledger-main` |
| `ledgerId` di `Debts` | default `ledger-main` |
| Diturunkan, **tanpa kolom baru** | `Transactions` dan `RecurringRules` (lewat `accountId`), `Budgets` (lewat `categoryId`), `GoalContributions` (lewat `goalId`), `TransactionTags` |

Alasan tidak menambah `ledgerId` ke `Transactions`: satu sumber kebenaran, tidak ada dua kolom yang bisa tidak sinkron
(prinsip sama dengan `paidAmount` di `Debts`). Harganya: kueri agregat perlu `JOIN accounts`. Untuk data pribadi
(ribuan baris) itu murah karena `accounts` kecil dan kunci utamanya terindeks.

### 3.2 Aturan yang harus selalu benar (invarian)
1. Sebuah transaksi memakai dompet dan kategori dari **buku yang sama**.
2. Transfer hanya antar dompet **satu buku**.
3. Anggaran hanya untuk kategori pengeluaran di bukunya.
4. Kategori dan sub-kategori induknya satu buku.
5. Setiap buku punya minimal satu dompet aktif dan kategori "Utang" dan "Piutang" (dibutuhkan `recordDebtPayment`).
6. `ledger-main` tidak bisa dihapus atau diarsipkan.

Ditegakkan di dua tempat: validasi di `add*` (melempar error yang jelas) dan pemeriksaan di
`BackupService._checkIntegrity` saat restore.

### 3.3 Migrasi v10 (perhatikan jebakan yang sudah tercatat di kode)
`onUpgrade` di `database.dart` sudah punya catatan jebakan "duplicate column": tabel yang **baru dibuat** dalam
migrasi yang sama sudah memakai definisi terkini (termasuk kolom baru), jadi `addColumn` kedua gagal. Untuk v10:

| Tabel | Dibuat pada versi | Guard `addColumn ledgerId` |
|---|---|---|
| `accounts`, `categories` | v1 | selalu |
| `savingsGoals` | v3 | hanya bila `from >= 3` |
| `agendaReminders` | v5 | hanya bila `from >= 5` |
| `debts` | v8 | hanya bila `from >= 8` |

Urutan di dalam `if (from < 10)`: buat tabel `ledgers` → sisipkan `ledger-main` (`insertOrIgnore`) → tambah kolom
(dengan default `ledger-main`, jadi semua data lama otomatis masuk Buku Utama).

**Cakupan uji (diringankan 2026-09-30):** aplikasi belum dipakai di produksi (baru jalur uji internal), jadi tes
migrasi cukup **v9 → v10** di `test/migration_test.dart`, di samping tes migrasi lama yang sudah ada. Lompatan dari
setiap versi awal (v1…v8 → v10) tidak diuji lagi. Guard `from >=` di atas tetap ditulis karena murah dan mencegah
kegagalan bila lompatan itu terjadi. Migrasi v9 → v10 tetap **wajib**: rilis 3 (skema v9) sudah terpasang di HP
pengembang dan penguji, dan tanpa migrasi aplikasi gagal terbuka setelah pembaruan ke rilis 4.

> **Batas waktu keputusan ini:** sebelum rilis produksi pertama, perubahan skema semurah ini. Setelah ada pengguna
> nyata, setiap perubahan skema wajib punya migrasi dan kompatibilitas backup penuh. Itu alasan fitur ini sebaiknya
> selesai sebelum produksi.

### 3.4 ID baris seed di buku baru
Seed sekarang memakai ID tetap (`cat-exp-makan`, `acc-tunai`, dst.) dan kode/tes merujuknya. ID harus unik global,
jadi:
- Buku Utama **mempertahankan ID lama** (tidak ada data yang berubah).
- Buku baru memakai awalan: `<ledgerId>:cat-exp-makan`, `<ledgerId>:acc-tunai`. Helper `seedId(ledgerId, base)`
  mengembalikan `base` polos untuk `ledger-main`.
- Titik keras yang harus diganti helper: `database.dart:554,566` (migrasi v9, tetap untuk main),
  `transaction_form_page.dart:147-148` (kategori Utang/Piutang saat bayar cicilan), `recordDebtPayment`.

## 4. Lapisan data dan status buku aktif

- **Kompatibilitas tes:** semua `add*` dan `watch*` yang terdampak menerima parameter opsional
  `String ledgerId = kMainLedgerId`. Dengan begitu 416 tes lama (23 berkas merujuk ID tetap) tetap berlaku tanpa
  diubah; tes multi-buku ditulis baru.
- **Kueri yang berubah:** 8 `customSelect` mentah (saldo dompet, total bulanan, tren, pengeluaran per kategori, tren
  kategori, anggaran, dst.) memakai `JOIN accounts a ... WHERE a.ledger_id = ?`; kueri Drift bertipe (`watchCategories`,
  `watchTags` tetap global, `watchGoals`, `watchAgendaReminders`, `watchDebts`, `watchRecurringRules`) mendapat `where`.
  Sekitar 25 dari 59 metode `Future`/`Stream` di `database.dart`.
- **Provider baru** di `providers.dart`:
  - `ledgersProvider` — daftar buku (aktif dan terkunci).
  - `activeLedgerIdProvider` — `Notifier` yang menyimpan pilihan di `KeyValueStore` (kunci `active_ledger_id`).
    Bila nilai tersimpan tidak ada, diarsipkan, atau **terkunci** (K1), jatuh ke `ledger-main`.
  - Provider yang sudah ada (`monthTotalsProvider`, `accountBalancesProvider`, `budgetProgressProvider`, dst.)
    membaca `activeLedgerIdProvider` dan meneruskannya ke database. Widget tidak perlu tahu soal buku.
- **Gerbang Ultimate:** `canUseMultipleLedgers = isUltimateProvider`. Non-Ultimate: `activeLedgerId` dipaksa
  `ledger-main` dan pengalih tidak tampil.

### 4.1 Operasi yang TIDAK boleh mengikuti buku aktif
Kesalahan paling mudah dibuat: semua ini bekerja lintas buku.

| Operasi | Perilaku |
|---|---|
| `generateDueRecurring` (dipanggil saat app dibuka) | Semua buku yang tidak terkunci; buku terkunci dijeda (K2) |
| Penjadwalan pengingat transaksi berulang dan Agenda | Semua buku tidak terkunci. Teks notifikasi menyebut nama buku bila ada lebih dari satu |
| Notifikasi anggaran | Semua buku tidak terkunci; sebut nama buku bila ada lebih dari satu |
| Backup lokal/cloud dan restore | Seluruh database (lihat §6) |
| "Hapus semua data" | Menghapus **semua** buku dan mengembalikan ke satu Buku Utama seed (uji di `test/database_test.dart`, pola perbaikan bug 30 Sep) |
| Ekspor CSV | Pilihan: buku aktif (bawaan), buku tertentu, atau semua buku (kolom tambahan "Buku") |

## 5. Template buku baru

Semua template menyertakan kategori **Utang** (pengeluaran) dan **Piutang** (pemasukan) serta satu dompet.

| Template | Pengeluaran | Pemasukan | Dompet awal |
|---|---|---|---|
| **Pribadi** | 12 kategori yang sama dengan seed sekarang | 6 kategori seed sekarang | Tunai |
| **Bisnis** | Pembelian Stok/Bahan Baku, Gaji Karyawan, Sewa Tempat, Listrik-Air-Internet, Ongkir & Transportasi, Pemasaran & Iklan, Peralatan, Pajak & Perizinan, Cicilan Usaha, Lainnya, Utang | Penjualan, Jasa, Modal Masuk, Pendapatan Lain, Lainnya, Piutang | Kas Usaha |
| **Kosong** | hanya Lainnya + Utang | hanya Lainnya + Piutang | Tunai |

Daftar kategori Bisnis adalah usulan, bisa diubah sebelum implementasi. Ikon memakai kunci ikon yang sudah ada
(`business`, `bills`, `salary`, dst.); tambah ikon baru hanya bila benar-benar perlu.

## 6. Backup dan pemulihan (format v6 → v7)

- Tambah daftar `ledgers` di JSON; `ledgerId` ikut otomatis di `accounts`, `categories`, `savingsGoals`,
  `agendaReminders`, `debts` (Drift menghasilkan `toJson`/`fromJson` untuk semua kolom).
- **Kompatibilitas mundur (minimal, diringankan 2026-09-30):** backup lama tidak punya `ledgers`/`ledgerId`. Aturan
  tunggalnya: bila kunci itu tidak ada di JSON, sisipkan `ledger-main` dan pakai sebagai default untuk semua baris.
  Ini dipertahankan karena backup cloud data contoh (format v6, dari akun uji) masih dipakai untuk pengujian dan
  screenshot. **Uji dengan satu fixture v6** (backup Drive sendiri); fixture v1–v5 tidak dibuat. Kode pembaca untuk
  format lama yang sudah ada tidak dihapus, hanya tidak diuji ulang.
- **Bukan pilihan:** menolak semua backup lama ("putus bersih") tidak diambil, karena menghemat sekitar 15 baris
  tetapi membuat data contoh harus dibuat ulang.
- **Kompatibilitas maju:** backup v7 yang dibuka aplikasi lama ditolak lewat pemeriksaan `version > formatVersion`
  yang sudah ada (pesan yang jelas, bukan data rusak).
- `_checkIntegrity` ditambah invarian §3.2 dan memastikan setiap `ledgerId` merujuk buku yang ada.
- Pemulihan di perangkat non-Ultimate yang backupnya berisi banyak buku: data tetap utuh, buku tambahan terkunci
  (K1). Tidak ada data yang dibuang.
- Backup cloud (Premium) dan foto struk tidak berubah.

## 7. Antarmuka

| Area | Rancangan |
|---|---|
| **Pengalih buku** | Chip di AppBar Dashboard: titik warna + nama buku aktif. Ketuk → bottom sheet daftar buku (nama, saldo total, indikator aktif) + "Kelola buku kas". Hanya tampil untuk Ultimate atau bila sudah ada lebih dari satu buku |
| **Kelola buku kas** (halaman baru, dari Lainnya atau sheet) | Tambah (pilih template §5, nama, warna, ikon), ubah nama/warna, arsipkan, hapus (hanya bila kosong; jika berisi, dialog konfirmasi menyebut jumlah transaksi), urutkan. Buku terkunci tampil abu-abu dengan Ekspor CSV |
| **Cegah salah catat** | Form transaksi menampilkan "Mencatat di: <nama buku>" dengan warna buku. Risiko terbesar fitur ini adalah transaksi masuk ke buku yang salah, jadi ini bukan hiasan |
| **Pengguna Gratis/Premium** | Satu baris di Lainnya/Pengaturan: "Buku kas — pisahkan pembukuan pribadi dan bisnis" (label Ultimate) yang membuka `SubscriptionPage(upgradeOnly: true)`. Hanya tampil bila produk Ultimate tersedia (aturan sama dengan A3 di rencana lanjutan) |
| **Teks langganan** | `_ultimateBenefits` di `subscription_page.dart` ditambah: "Multi buku kas: pisahkan pembukuan pribadi dan bisnis" dan diperbarui bersama butir AI |
| **AI** | Daftar kategori yang dikirim ke Worker otomatis kategori buku aktif (lewat `allCategoriesProvider`), jadi saran kategori di buku Bisnis memakai kategori usaha tanpa perubahan Worker |
| **Onboarding** | Tidak berubah |

## 8. Fase pengerjaan

Ukuran: S ≈ setengah hari, M ≈ 1–2 hari, L ≈ 3+ hari (perkiraan kasar, belum diuji).

| Fase | Isi | Ukuran | Keluaran yang diverifikasi |
|---|---|---|---|
| **F0** | Putuskan K1–K7, finalkan daftar kategori Bisnis | S | Keputusan tertulis di §2 |
| **F1** | Skema v10 + migrasi (§3.3) | M | Tes migrasi v9 → v10 (+ tes migrasi lama tetap lulus); data lama utuh di `ledger-main`; `flutter analyze` bersih |
| **F2** | API data ber-buku, helper `seedId`, penegakan invarian, pembuatan buku dari template | L | Tes: saldo/total/tren/anggaran terpisah antar buku; transaksi lintas buku ditolak; 416 tes lama tetap lulus tanpa diubah |
| **F3** | Operasi lintas buku (§4.1): berulang, pengingat, notifikasi anggaran, hapus semua, CSV | M | Tes tiap baris tabel §4.1, termasuk buku terkunci |
| **F4** | Backup v7 + kompatibilitas mundur minimal + integritas | S–M | Tes round-trip v7; membaca satu fixture backup v6; backup v7 ditolak aplikasi lama |
| **F5** | Provider buku aktif, gerbang Ultimate, UI (§7) | L | Tes widget: pengalih, kelola, "Mencatat di", kondisi terkunci; uji tampilan manual |
| **F6** | Upsell, teks manfaat, listing Play (`docs/LISTING-PLAY-STORE.md`) | S | Teks konsisten dengan matriks |
| **F7** | Verifikasi di HP dengan **data nyata** dan rilis | M | §9 |

F1 harus selesai sebelum yang lain; F2 sebelum F3–F5. F4 bisa paralel dengan F5 setelah F2.

## 9. Verifikasi dan risiko

### Uji di perangkat (sebelum rilis)
1. Pemeriksaan singkat: pasang build baru **di atas** rilis 3 di HP Redmi (datanya hasil restore dari backup cloud).
   Pastikan aplikasi terbuka dan angka utama (saldo, total bulan ini) sama dengan sebelum update. Tidak perlu uji
   menyeluruh: aplikasi belum dipakai di produksi.
2. Ekspor backup sebelum update sebagai jalan mundur; skema tidak bisa diturunkan. Backup cloud contoh di Drive sudah
   berfungsi sebagai cadangan.
3. Buat buku Bisnis (template Bisnis): catat transaksi, anggaran, transaksi berulang, agenda, utang; pastikan angka
   Buku Utama tidak berubah.
4. Backup cloud → restore di keadaan bersih → semua buku kembali.
5. Simulasikan Ultimate berakhir (akun lisensi uji dibatalkan): buku tambahan terkunci, Buku Utama normal, CSV masih bisa.
6. Notifikasi berulang/anggaran dari buku non-aktif tetap berbunyi dan menyebut nama buku.

### Risiko
| Risiko | Mitigasi |
|---|---|
| Migrasi merusak data (skema tidak bisa diturunkan) | Tes v9 → v10, pemeriksaan di Redmi (§9.1), backup Drive sebagai cadangan. Belum ada pengguna produksi, jadi dampaknya terbatas pada data uji |
| Transaksi masuk ke buku yang salah | Header "Mencatat di" berwarna, warna buku konsisten di seluruh app |
| Operasi lintas buku tanpa sengaja terikat buku aktif (mis. berulang hanya jalan di buku aktif) | Daftar §4.1 dijadikan checklist tes; review khusus semua pemanggil `generateDueRecurring` dan pengingat |
| ID seed bentrok atau kode masih merujuk ID tetap | Helper `seedId`; cari semua string `'cat-'`/`'acc-'` di `lib/` sebelum selesai F2 |
| Backup v7 tidak terbaca versi lama | Pemeriksaan versi sudah ada; dokumentasikan bahwa restore ke aplikasi lama tidak didukung |
| Lingkup melebar (gabungan, transfer antar buku) | Tegakkan §1 "di luar lingkup" |
| Beban kueri karena `JOIN` | Data pribadi kecil; ukur dengan 10.000 transaksi di tes, tambah indeks `accounts(ledger_id)` bila perlu |

## 10. Checklist

Status per 2026-09-30 (K1–K7 memakai rekomendasi; lihat §11).

- [x] F0 keputusan K1–K7 (rekomendasi dipakai) · daftar kategori Bisnis final (11 pengeluaran, 6 pemasukan)
- [x] F1 tabel `Ledgers` + kolom `ledgerId` + migrasi v10 + tes migrasi v1…v9 → v10 (semua versi lulus)
- [x] F2 API ber-buku (parameter opsional) · `ledgerSeedId` · invarian · template · tes (`test/ledgers_db_test.dart`, 30 tes)
- [x] F3 berulang (buku terjeda) · pengingat · notifikasi anggaran · hapus semua · CSV per buku (dari Kelola Buku Kas)
- [x] F4 backup v7 · default `ledger-main` bila kunci tidak ada · integritas lintas buku · tes (fixture v6 disintesis dari ekspor)
- [x] F5 `ledgersProvider`/`activeLedgerIdProvider` · gerbang Ultimate · pengalih · Kelola buku kas · "Mencatat di" · kondisi terkunci
- [x] F6 teks manfaat Ultimate (halaman langganan) · tile Buku Kas (upsell/terkunci) · draf teks listing Play (belum dipasang)
- [ ] F7 pemeriksaan singkat di Redmi (upgrade dari rilis 3) · backup sebelum update · rilis

## 11. Catatan implementasi (2026-09-30)

Keputusan yang dipakai (rekomendasi §2): K1 buku tambahan terkunci saat Ultimate berakhir, data utuh, Ekspor CSV
tetap bisa · K2 transaksi berulang di buku terkunci dijeda dan disusul saat terbuka · K3 batas 5 buku aktif ·
K4 tag global · K5 template Pribadi/Bisnis/Kosong · K6 Ultimate dirilis bersama fitur ini · K7 harga tidak berubah.

Hal-hal yang berbeda dari rencana atau baru ditemukan saat mengerjakan:
- **Tanpa foreign key di `ledgerId`.** SQLite menolak `ALTER TABLE ADD COLUMN ... REFERENCES` berdefault non-NULL
  saat foreign key aktif, jadi kolom itu tidak bisa ditambahkan lewat migrasi kalau diberi referensi. Integritas
  dijaga di kode (`_checkSameLedger`, `_requireLedger`) dan `BackupService._checkIntegrity`.
- **Default kolom memakai literal `'ledger-main'`**, bukan konstanta `kMainLedgerId`: berkas skema tergenerasi untuk
  tes migrasi menyalin ekspresi default apa adanya dan tidak bisa mengimpor konstanta.
- **Parameter `ledgerId` pada watcher bertipe `String?`**: bawaan Buku Utama; `null` = semua buku (dipakai
  penjadwal pengingat dan notifikasi anggaran yang harus lintas buku). `getTransactions` bawaannya `null`.
- **Pembuatan transaksi berulang lewat `recurringGeneratorProvider`**, bukan `generateDueRecurring()` langsung,
  supaya buku terkunci selalu dijeda. Ada empat pemanggil (app, form Catat, halaman berulang, restore).
- **Harness tes:** `FakeSubscriptionStatus` kini mengirim nilai awal lewat generator `async*` (bukan `onListen`
  pada stream broadcast). Riverpod menjeda langganan saat rantai provider baru dibuat, dan event broadcast yang
  datang saat itu hilang, sehingga provider macet di loading. Implementasi produksi sudah memakai `async*`.
- **Pengalih buku hanya untuk Ultimate.** Pengguna yang Ultimate-nya berakhir tetap melihat buku tambahan di
  halaman Kelola Buku Kas (terkunci, dengan Ekspor CSV), bukan di pengalih.
- Belum diverifikasi di perangkat nyata (F7). Migrasi dari skema v9 ke v10 diuji otomatis dari semua versi lama.
