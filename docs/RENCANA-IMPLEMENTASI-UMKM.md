# Rencana Implementasi — Pembukuan dan Pelaporan UMKM

> Dibuat 2026-10-29 atas usulan pemilik: memperkuat fitur pembukuan dan pelaporan untuk pelaku usaha kecil yang
> mengelola usahanya secara amatir, sambil tetap melayani pengguna pribadi. Belum ada kode yang diubah. Dasar: kode di
> `main` (skema **v11**, format backup **v8**, 759 tes Flutter lulus). Melengkapi
> [MATRIKS-FITUR-PAKET.md](MATRIKS-FITUR-PAKET.md) dan [RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md](RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md).

**Selaras dengan pemasaran yang sudah berjalan (28 Okt 2026):** segmen UMKM sudah dibidik lewat
[ASO-DAN-MATERI-UMKM.md](ASO-DAN-MATERI-UMKM.md), [RENCANA-GROWTH-30-HARI.md](RENCANA-GROWTH-30-HARI.md), dan halaman
template buku kas Excel gratis di situs. Janji di materi itu (memisahkan uang pribadi dan usaha, utang piutang) sudah dipenuhi
aplikasi; Fase 1 menutup janji berikutnya yang wajar ditanyakan pengguna dari template itu: "untungnya berapa?". Uji coba
Ultimate sudah dinyalakan (`TRIAL_ENABLED = "1"`), jadi pengguna UMKM baru bisa mencoba buku kas tambahan sebelum membayar.

## 1. Tujuan dan prinsip

**Sasaran pengguna:** pedagang kecil, usaha rumahan, jasa, dan warung yang sekarang mencatat di buku tulis atau tidak sama
sekali. Mereka perlu menjawab tiga pertanyaan: *untung berapa bulan ini? uang usaha ke mana saja? siapa yang belum
bayar / kepada siapa saya berutang?* Bukan akuntan, jadi istilahnya sederhana dan hasilnya langsung bisa dibagikan.

Prinsip yang tidak boleh dilanggar (turunan dari konvensi yang sudah ada):
1. **Tetap sederhana dan berbasis kas.** Bukan akuntansi akrual penuh, bukan jurnal ganda. Setiap laporan memuat
   keterangan bahwa ini catatan manajemen, bukan laporan resmi atau laporan pajak.
2. **Satu sumber kebenaran.** Angka laporan diturunkan dari transaksi; tidak ada kolom total yang bisa tidak sinkron
   (pola yang sama dengan saldo dompet dan `paidAmount`).
3. **Offline-first dan privat.** Semua dihitung di HP. Data pelanggan (Fase 2) tidak dikirim ke server.
4. **Uang = integer Rupiah**, urutan enum yang disimpan sebagai index **tidak boleh diubah**.
5. **Migrasi disiplin** (README, bagian "Migrasi database"): naikkan `schemaVersion`, dump skema, regenerasi tes
   migrasi, naikkan `BackupService.formatVersion` bila format backup berubah.
6. **Pengguna Gratis/Premium hanya punya satu buku.** Pelaku UMKM pemula umumnya memakai satu buku saja, jadi
   fitur usaha harus bisa dihidupkan di Buku Utama, bukan hanya di buku tambahan (Ultimate).

## 2. Keadaan sekarang (diperiksa di kode, 2026-10-29)

| Yang sudah ada | Catatan |
|---|---|
| Multi buku kas (Ultimate, maks 5) | Template buku **Bisnis** sudah ada (`LedgerTemplate.business`, dompet "Kas Usaha", kategori usaha: Pembelian Stok, Gaji Karyawan, Sewa, Listrik/Air/Internet, Ongkir, Pemasaran, Peralatan, Pajak, Cicilan Usaha; pemasukan Penjualan, Jasa, Modal Masuk, Pendapatan Lain) |
| Transaksi, kategori + sub-kategori, tag, foto struk | Kategori tidak punya "kelompok laporan" |
| Utang/piutang beserta cicilan dan jatuh tempo | Pihak lawan hanya teks (`counterpartyName`), tanpa data kontak |
| Excel 5 lembar, Laporan Bulanan (aturan), ringkasan AI Laporan Bulanan | Semua berpola "pemasukan - pengeluaran" |
| Transaksi berulang, Agenda, proyeksi dan simulasi arus kas | Bisa dipakai untuk biaya tetap usaha |

**Celah (urut dampak):** (1) tidak ada Laba Rugi: modal, prive, pembelian peralatan, pelunasan utang, setoran tabungan, dan
penyesuaian saldo bercampur dengan pendapatan dan beban biasa, sehingga "sisa uang" salah dibaca sebagai "laba";
(2) laporan hanya Excel, belum PDF yang enak dibagikan ke bank, pemasok, atau pemilik modal; (3) tidak ada data
pelanggan/pemasok dan tidak ada nota; (4) tidak ada produk/stok/HPP; (5) tidak ada tutup kas harian.

Satu keterbatasan yang harus diakui sejak awal: karena berbasis kas, **penjualan kredit baru terhitung sebagai
pendapatan saat uangnya diterima**. Penanganannya dibahas di Fase 2 (§5, keputusan U8).

## 3. Keputusan yang menunggu pemilik

| # | Keputusan | Rekomendasi |
|---|---|---|
| U1 | Paket untuk Laba Rugi, kelompok laporan, dan PDF | **Premium** (daya tarik naik paket bagi UMKM, tidak butuh server). Buku tambahan tetap Ultimate. Gratis tetap melihat Laporan Bulanan dan CSV |
| U2 | Paket untuk Fase 2 (kontak, nota PDF, tutup kas) | Kontak dan piutang per pelanggan **Premium** (memperluas Utang/Piutang yang sudah Premium); nota/invoice PDF **Premium**; ringkasan AI usaha **Ultimate** |
| U3 | Perlakuan "Peralatan" dan "Cicilan Usaha" | Peralatan = **di luar laba rugi** (pembelian aset, tetap tampil di arus kas). Cicilan Usaha = di luar laba rugi, dengan petunjuk "bunga/denda dicatat terpisah sebagai beban". Alternatif: biaya langsung (lebih sederhana, lebih kasar) |
| U4 | Penyesuaian Saldo dalam Laba Rugi | **Di luar laba rugi** namun ditampilkan di blok rekonsiliasi, supaya koreksi saldo tidak mengubah laba |
| U5 | Mode usaha di Buku Utama | Saklar "Ini buku usaha" per buku, tersedia di semua paket (§4.2). Mengubahnya tidak mengubah data, hanya istilah dan laporan |
| U6 | Waktu rilis | Fase 1 dalam satu rilis bersama daftar di [RENCANA-RILIS-BERIKUTNYA.md](RENCANA-RILIS-BERIKUTNYA.md) (UMP, sapaan "kamu") atau rilis sendiri. Rilis sendiri lebih mudah dilacak, rilis bersama menghemat satu peninjauan Play |
| U7 | Perhitungan PPh final 0,5% (Fase 3) | Hanya **informasi** dengan penafian; tidak boleh tampil sebagai "tagihan pajak". Aturan: PP 55/2022 (pribadi bebas sampai omzet Rp500 juta/tahun). Periksa ulang sumber resmi saat dikerjakan |

## 4. Fase 1 — Mode usaha dan Laba Rugi

### 4.1 Model data (skema v11 → v12)

| Perubahan | Rincian |
|---|---|
| `Categories.reportGroup` | Kolom `intEnum<ReportGroup>` **nullable**. Null = turunan dari jenis (pemasukan → Pendapatan, pengeluaran → Beban operasional), jadi buku pribadi lama tidak perlu data baru |
| Enum `ReportGroup` (indeks tetap!) | `revenue`=0 Pendapatan usaha, `cogs`=1 Harga pokok penjualan (HPP), `opex`=2 Beban operasional, `otherIncome`=3 Pendapatan lain, `otherExpense`=4 Beban lain, `nonPnl`=5 Di luar laba rugi |
| `Ledgers.kind` | `intEnum<LedgerKind>`, bawaan `personal`=0, `business`=1 (§4.2). Indeks tetap |
| Isi awal (migrasi sisip data) | Kategori sistem **Utang, Piutang, Tabungan, Penyesuaian Saldo** → `nonPnl`. Kategori bawaan template Bisnis (cocokkan lewat ID bawaan `ledgerSeedId(...)`): `stok` → `cogs`; `modal`, `peralatan`, `cicilan-usaha` → `nonPnl` (U3); `pendapatan-lain` → `otherIncome`; `pajak` → `opex`. Kategori buatan pengguna tidak disentuh (null) |

Migrasi mengikuti pelajaran di `onUpgrade` (jebakan "duplicate column": tabel yang baru dibuat di migrasi yang sama
sudah memakai definisi terkini). Karena hanya menambah kolom ke tabel yang sudah ada, risikonya rendah; tetap wajib diuji
dari **semua** versi lama (v1–v11) lewat `test/migration_test.dart`.

**Backup v9:** `categories.reportGroup` dan `ledgers.kind` ikut disimpan. Backup lama (v1–v8) tetap terbaca (kolom
kosong = bawaan). Catat bahwa backup v9 tidak terbaca di build lama (sama seperti v8, lihat catatan rilis 1.1.0).

### 4.2 Mode usaha
- Di **Kelola Buku Kas** dan dialog ubah buku: saklar "Buku usaha". Buku yang dibuat dari template Bisnis otomatis
  `business`. Buku Utama bisa dijadikan buku usaha (U5).
- Pada buku usaha: istilah "Pemasukan/Pengeluaran" tampil sebagai "Pendapatan/Beban" **hanya di layar laporan**
  (daftar transaksi dan formulir tidak berubah agar tidak membingungkan), dan menu Laporan Bulanan mendapat tab Laba Rugi.
- Layar Kategori mendapat pilihan "Masuk ke laporan sebagai" (enam kelompok, dengan penjelasan satu kalimat per kelompok).
  Kategori baru pada buku usaha diberi saran otomatis dari namanya (mis. "Beli bahan" → HPP) tetapi **selalu bisa diganti**.

### 4.3 Perhitungan Laba Rugi (cash basis)
Untuk rentang tanggal [a, b] pada satu buku (transfer antar dompet diabaikan, seperti kartu Dashboard):

```
Pendapatan usaha                    = Σ pemasukan kategori revenue
(-) HPP                             = Σ pengeluaran kategori cogs
= Laba kotor                         (margin kotor = laba kotor / pendapatan)
(-) Beban operasional               = Σ pengeluaran kategori opex      (rincian per kategori, urut terbesar)
= Laba operasional
(+) Pendapatan lain / (-) Beban lain = otherIncome - otherExpense
= LABA BERSIH                        (margin bersih = laba bersih / pendapatan)

Rekonsiliasi kas:
Laba bersih
(±) Di luar laba rugi               = nonPnl pemasukan - nonPnl pengeluaran (rincian: modal, prive, aset, utang, tabungan, ...)
= Perubahan kas pada periode        (harus sama dengan Σ pemasukan - Σ pengeluaran semua kategori)
```

Pembanding: periode sebelumnya yang sama panjang dan perubahan persen. Seluruh logika dalam satu fungsi murni di `lib/data/`
(mis. `profit_loss.dart`, tanpa Flutter) supaya mudah diuji, mengikuti pola `insights.dart` dan `cash_flow.dart`.
Baris rekonsiliasi adalah **uji kebenaran** di tes: selisihnya harus selalu nol.

### 4.4 Tampilan dan ekspor
- **Layar Laba Rugi** (di bawah Lainnya > Laporan): pilih bulan atau rentang bebas (bulan ini, bulan lalu, 3 bulan, tahun
  berjalan, kustom), kartu ringkas Laba bersih + margin, tabel bertingkat seperti di §4.3, dan kategori yang belum
  dikelompokkan (null) ditandai agar pengguna sadar pengelompokan otomatis dipakai.
- **Excel:** tambah lembar "Laba Rugi" pada `buildTransactionsXlsx`; lembar lama tidak berubah.
- **PDF (baru):** satu halaman A4 "Laporan Laba Rugi" (nama usaha = nama buku, periode, tabel, keterangan "dibuat oleh
  LaciQ, catatan manajemen, bukan laporan resmi"), dibagikan lewat lembar bagikan yang sudah ada (`share_file.dart`).
  Memakai paket `pdf` 3.13.1 (murni Dart, tanpa izin baru). **Hasil spike (2026-10-29):** font variabel
  `PlusJakartaSans.ttf` yang dibundel **terrender benar** (huruf Latin beraksen, tanda baca, angka, "Rp", dan tersemat di PDF)
  tetapi hanya pada bobot bawaannya (400; `SpaceGrotesk.ttf` bawaannya 300/Light, jadi tidak cocok untuk badan teks PDF).
  Paket `pdf` tidak bisa memilih bobot sumbu variabel, sehingga **huruf tebal memakai instans statis**
  `assets/fonts/pdf/PlusJakartaSans-Bold.ttf` (96 KB, dibuat dengan `fonttools varLib.instancer ... wght=700
  --update-name-table`, lisensi OFL yang sama, tanpa Reserved Font Name). Dideklarasikan di bagian `assets:` pubspec, bukan
  `fonts:`, agar bobot teks di aplikasi tidak berubah. Dijaga oleh `test/pdf_fonts_test.dart`.
- Teks keuangan Indonesia: format Rupiah memakai `lib/core/money.dart`; tanggal `intl` lokal `id`.

### 4.5 Gating dan tampilan paket
Mengikuti pola yang ada (mis. Laporan Bulanan): Gratis melihat ajakan upgrade dengan pratinjau angka terkunci;
Premium dan Ultimate (termasuk masa uji coba) penuh. Turun ke Gratis: kelompok yang sudah ditetapkan **tidak dihapus**,
hanya layar Laba Rugi yang terkunci.

### 4.6 Rencana tes
| Cakupan | Isi |
|---|---|
| Unit `profit_loss` | Semua kelompok, transfer diabaikan, kategori null (turunan jenis), rentang batas tanggal, periode kosong, uji **rekonsiliasi nol** pada data acak (property-style, seed tetap) |
| Migrasi | v1–v11 → v12: data utuh, kategori sistem ter-set `nonPnl`, kategori buatan pengguna tetap null |
| Backup | Putaran penuh v9; pemulihan backup v1–v8; validasi nilai enum di luar rentang ditolak |
| UI | Saklar buku usaha; ubah kelompok kategori; layar Laba Rugi terkunci/terbuka per paket; PDF menghasilkan bytes valid (`%PDF-` dan jumlah halaman) |
| Excel | Lembar baru terbaca (pola `xlsx_export_test.dart`) |
| Kontras tema | Tidak ada warna baru di luar `AppPalette`; jalankan `theme_test.dart` |

### 4.7 Kebijakan privasi dan toko
Fase 1 tidak menambah data yang dikumpulkan, tidak menambah izin, dan tidak memakai jaringan. Data Safety **tidak berubah**;
tetap cocokkan sebelum rilis. Deskripsi listing Play perlu satu paragraf baru (Laba Rugi dan PDF) di
[LISTING-PLAY-STORE.md](LISTING-PLAY-STORE.md).

### 4.8 Urutan kerja Fase 1 (tiap langkah bisa dikomit terpisah)
1. ~~Spike PDF + font~~ **selesai 2026-10-29**: font variabel cukup untuk teks biasa; huruf tebal butuh instans statis (§4.4).
   Belum diuji: tampilan PDF di HP nyata/WhatsApp (masuk daftar uji §8 butir 5), dan ukuran APK setelah paket `pdf` (periksa saat membangun AAB).
2. ~~`ReportGroup`, `LedgerKind`, skema v12, migrasi + tes migrasi + backup v9~~ **selesai 2026-10-29** (783 tes lulus).
   Rincian yang berbeda atau menambah dari rancangan §4.1: (a) migrasi mengisi kelompok untuk kategori bawaan/sistem lewat ID dasar
   (`_seedReportGroups`) **dan** kategori buatan pengguna yang bernama persis Utang/Piutang/Tabungan/Penyesuaian Saldo
   (nama yang dipakai ulang oleh fitur sistem); `pajak` tetap beban operasional; (b) buku yang sudah memuat kategori
   "Penjualan" bawaan template Bisnis otomatis ditandai buku usaha; (c) sub-kategori tidak punya kelompok sendiri (mengikuti
   induk), dijaga di API (`setCategoryReportGroup`, `addCategory`, `updateCategory`) dan di validasi backup; (d) kelompok
   harus cocok dengan jenis (`ReportGroup.allowedFor`), juga divalidasi di backup; (e) API baru `setLedgerKind`;
   (f) backup v9, backup lama tanpa kunci baru tetap terbaca. **Koreksi 2026-10-29 (temuan uji Redmi):** semula backup lama (format < 9) dipulihkan dengan kelompok KOSONG, sehingga setelah pulih dari backup, kategori sistem (Utang, Piutang, Tabungan, Penyesuaian Saldo) dan kategori usaha bawaan jatuh ke bawaan jenis dan pembayaran utang terhitung sebagai beban pada Laba Rugi. Kini `parse` menerapkan aturan yang SAMA dengan migrasi v12 untuk backup format < 9 (`seedReportGroupFor`, `businessLedgerIdsOf`); backup v9 dihormati apa adanya.
3. ~~`profit_loss.dart` + tes unit (belum ada UI)~~ **selesai 2026-10-29** (`lib/data/profit_loss.dart`, `test/profit_loss_test.dart`,
   26 tes). API: `buildProfitLoss(items, categories, from, to)` -> `ProfitLoss` (bagian pendapatan/HPP/beban/lain/di luar laba rugi,
   `grossProfit`, `operatingProfit`, `netProfit`, `nonPnlNet`, `cashChange`, `reconciles`, margin), `previousPeriod`,
   `changePercent`, `effectiveReportGroup`. Catatan: `cashIn/cashOut` dihitung terpisah langsung dari transaksi sehingga
   `reconciles` benar-benar menguji pengelompokan (diuji dengan 60 seed acak, oracle terpisah, uji mutasi, dan database nyata
   dengan template Bisnis, termasuk Utang/Piutang/Penyesuaian Saldo). Baris laporan digabung ke kategori **induk**
   (sub-kategori tidak ditampilkan terpisah di Laba Rugi). Rentang pembanding bulan-utuh mundur tepat sejumlah bulan.
4. ~~Pilihan kelompok di layar Kategori, saklar buku usaha, saran kelompok otomatis~~ **selesai 2026-10-29**
   (836 tes lulus). Keputusan implementasi: (a) **saklar "Mode usaha"** ada di **Lainnya** untuk SEMUA paket (bukan hanya
   Ultimate), karena pelaku UMKM pemula memakai Buku Utama; di Ultimate juga ada saklar "Buku usaha" di dialog buat/ubah buku
   (template Bisnis menyalakannya otomatis, tetapi saklar yang sudah disentuh tidak lagi ikut template); (b) pilihan **"Masuk ke
   laporan sebagai"** dan label kelompok di daftar kategori **hanya muncul di buku usaha** agar pengguna pribadi tidak dibebani
   istilah usaha; (c) **saran dari nama** (`suggestReportGroup`, kata kunci konservatif, "di luar laba rugi" dicek lebih dulu,
   "bahan bakar" bukan HPP) hanya untuk kategori **baru** dan berhenti begitu pengguna memilih sendiri; kategori yang diubah
   namanya tidak berubah kelompoknya; (d) sub-kategori tidak punya pilihan (mengikuti induk); (e) `updateCategory` menerima
   `Value<ReportGroup?>` (absen = tidak diubah). Teks baru memakai "Anda" agar seragam dengan aplikasi sampai sapaan "kamu" diganti.
5. ~~Layar Laba Rugi + gating~~ **selesai 2026-10-29** (`lib/features/reports/profit_loss_page.dart`,
   `profit_loss_providers.dart`, tile "Laba Rugi" di Lainnya; 852 tes lulus). Isi: pilihan periode **Bulan / 3 Bulan / Tahun /
   Kustom** (bulan dan tahun memakai penggeser yang sudah ada), kartu laba/rugi bersih + margin + perbandingan dengan periode
   sebelumnya, tabel bertingkat (bagian kosong disembunyikan), blok "Dari laba ke kas" (rekonsiliasi), catatan "otomatis" untuk
   kategori yang kelompoknya bawaan, dan ajakan menyalakan Mode usaha di buku pribadi (laporan tetap terbaca dengan kelompok
   bawaan). Reaktif: transaksi atau kelompok yang berubah langsung memperbarui layar. **Penyimpangan dari §4.5:** penguncian
   mengikuti pola Laporan Bulanan (Gratis ditawari upgrade dari menu, tanpa pratinjau angka terkunci); pratinjau terkunci bisa
   ditambah kemudian bila ingin. Teks memakai "Anda"/netral. Ekspor Excel dan PDF menyusul di langkah 6.
6. ~~Lembar Excel dan PDF~~ **selesai 2026-10-29** (`profit_loss_statement.dart`, `profit_loss_pdf.dart`, lembar di
   `excel_export.dart`; tombol bagikan di layar Laba Rugi). Satu sumber baris (`profitLossStatement`/`cashBridgeStatement`,
   pengurang bernilai negatif) dipakai Excel dan PDF supaya selalu sama. Excel: lembar **"Laba Rugi"** disisipkan setelah
   Ringkasan **hanya** bila diminta (buku usaha lewat Pengaturan > Ekspor Excel; layar Laba Rugi > Ekspor Excel) sehingga berkas buku
   pribadi tidak berubah; angka asli (bukan teks), persen sebagai pecahan. PDF: A4 tegak, `MultiPage` (rincian panjang meluber
   ke halaman berikutnya), font reguler variabel + tebal statis, kartu laba/rugi bersih + pembanding, tabel, jembatan ke kas,
   penafian, nomor halaman; diperiksa visual dengan `pdftoppm`/`pdftotext` (A4, 1 halaman, huruf tebal tampil). Temuan sampingan
   yang diperbaiki: alur ekspor Excel membaca nama buku dari provider yang bisa belum terisi (Riverpod menjeda yang tidak
   terlihat), sehingga nama bisa jatuh ke "Buku Utama"; kini dibaca langsung dari database. Perubahan 0,0% ditulis "Sama dengan
   periode sebelumnya", bukan "naik 0,0%". Belum diuji di HP/WhatsApp/Excel/Google Sheets nyata (daftar uji §8 butir 5).
7. ~~Perbarui matriks fitur, listing, catatan rilis; uji di HP (daftar §8)~~ **dokumen selesai 2026-10-29**: baris baru di
   [MATRIKS-FITUR-PAKET.md](MATRIKS-FITUR-PAKET.md), butir Premium baru dan kalimat pembuka di [LISTING-PLAY-STORE.md](LISTING-PLAY-STORE.md)
   (deskripsi 2.960 karakter; jangan menimpa listing ASO yang tayang), catatan Data Safety (tidak berubah) dan kata "PDF" di kebijakan
   privasi bagian 7 (perlu di-deploy), rancangan [RILIS-1.2.0+16.md](RILIS-1.2.0+16.md), dan daftar uji [UJI-HP-LABA-RUGI.md](UJI-HP-LABA-RUGI.md)
   (L1-L13, data uji berangka). **Yang BELUM: uji di HP, naik versi di `pubspec.yaml`, membangun AAB.**

**Selesai bila:** pengguna Premium bisa menyalakan mode usaha di Buku Utama, melihat Laba Rugi satu bulan yang
rekonsiliasinya cocok dengan perubahan saldo dompet, membagikannya sebagai PDF, dan semua tes lulus.

## 5. Fase 2 — Pelanggan, pemasok, nota (garis besar; rincikan sebelum dikerjakan)

| Butir | Gagasan | Catatan desain |
|---|---|---|
| Kontak | Tabel `Contacts` (nama, jenis pelanggan/pemasok/keduanya, telepon, catatan, `ledgerId`) dan `Debts.contactId` nullable; `counterpartyName` dipertahankan untuk data lama | Migrasi otomatis: nama yang sama dalam satu buku digabung menjadi kontak (dengan pratinjau, bisa dibatalkan) |
| Piutang dan utang dagang per kontak | Daftar per kontak, **umur piutang** (0-30, 31-60, >60 hari), pengingat tagih lewat WhatsApp dengan teks siap kirim | Hanya membuka WhatsApp lewat tautan atas permintaan pengguna; tidak ada pengiriman otomatis |
| Nota/invoice sederhana | Daftar baris (nama barang, jumlah, harga), diskon, total, PDF dengan nama usaha, dibagikan lewat WhatsApp | Menyimpan nota sebagai tabel sendiri; membuat transaksi pemasukan "Penjualan" saat dibayar |
| Penjualan kredit | Nota belum dibayar → piutang pelanggan; **pendapatan diakui saat nota dibuat** atau saat dibayar | Keputusan terbuka U8: tetap cash basis (sederhana) vs "pendapatan diakui di nota" (lebih benar, lebih rumit). Pilih sebelum Fase 2 |
| Input cepat penjualan | Tombol "Penjualan hari ini" dan template transaksi favorit (mis. "Es teh Rp5.000 x N") | Mengurangi ketukan, penting bagi pedagang |
| Tutup kas harian | Hitung uang fisik di laci vs saldo dompet; selisih dicatat sebagai "Penyesuaian Saldo" | Memakai fitur Sesuaikan saldo yang sudah ada |

**Privasi (wajib sebelum rilis):** nama dan telepon pelanggan/pemasok adalah data pribadi pihak ketiga. Tetap lokal dan ikut
backup Drive terenkripsi; perbarui [kebijakan privasi](kebijakan-privasi/index.html) dan [DATA-SAFETY-PLAY.md](DATA-SAFETY-PLAY.md).
Ringkasan AI untuk usaha (Ultimate, opsional) tetap hanya mengirim **angka agregat**, tanpa nama kontak atau barang.

## 6. Fase 3 — Produk dan stok (garis besar)
- Tabel `Products` (nama, harga jual, harga beli, satuan) dan `StockMovements` (masuk/keluar/koreksi); stok diturunkan dari
  gerakan (tanpa kolom stok).
- **HPP otomatis** dengan rata-rata bergerak; laporan penjualan per produk, barang terlaris, stok menipis (pengingat).
- Neraca sederhana (kas + piutang + persediaan; utang; modal) **hanya bila** Fase 2 dan 3 sudah stabil; disebut "ringkasan
  posisi keuangan" dengan penafian.
- Perkiraan PPh final (U7), laporan 12 bulan untuk pengajuan KUR/pinjaman.
- Di luar jangkauan sampai ada sinkronisasi: multi-kasir/multi-pengguna, banyak perangkat.

## 7. Risiko

| Risiko | Dampak | Penanganan |
|---|---|---|
| Pengguna salah mengelompokkan kategori, Laba Rugi menyesatkan | Keputusan usaha keliru | Saran otomatis, penanda "belum dikelompokkan", rekonsiliasi kas selalu tampil, penafian pada laporan dan PDF |
| Penjualan kredit tidak tercermin pada pendapatan | Laba terlihat lebih kecil dari kenyataan | Catatan jelas di layar dan PDF (basis kas); U8 di Fase 2 |
| Cakupan melebar menjadi aplikasi akuntansi | Aplikasi berat, rilis lambat | Setiap fase dirilis dan diukur dulu; Fase 2-3 hanya dikerjakan bila Fase 1 dipakai (lihat §9) |
| Font PDF rusak | Laporan tidak terbaca | Spike di langkah 1 |
| Klaim hukum/pajak | Risiko reputasi | Penafian tetap; kata "resmi" tidak dipakai; tidak ada saran pajak personal |
| Menambah beban `database.dart` (3.555 baris) | Sulit dirawat | Logika laporan di berkas sendiri (`profit_loss.dart`); jangan menambah query laporan ke `database.dart` |

## 8. Daftar uji di HP (Fase 1)
1. Buat buku Bisnis (atau nyalakan mode usaha di Buku Utama), catat penjualan, beli bahan, sewa, gaji, modal masuk, beli peralatan.
2. Buka Laba Rugi bulan ini: laba kotor, laba operasional, laba bersih sesuai hitungan manual; modal dan peralatan tidak memengaruhi laba.
3. Perubahan kas di rekonsiliasi = selisih saldo dompet sebelum dan sesudah periode.
4. Ubah kelompok satu kategori (mis. Peralatan → Beban operasional): angka berubah sesuai.
5. Bagikan PDF ke WhatsApp dan buka di HP lain: font, tabel, dan Rupiah terbaca; Excel terbuka di Google Sheets.
6. Turun ke Gratis (akun uji): layar Laba Rugi terkunci, data dan pengelompokan utuh; naik lagi: kembali.
7. Backup dan pulihkan (berkas dan Drive): kelompok kategori dan mode usaha utuh.
8. Pembaruan dari build 15 dengan data nyata: tidak ada data hilang; kategori sistem otomatis di luar laba rugi.

## 9. Cara mengukur apakah layak lanjut ke Fase 2
Tidak ada telemetri di aplikasi (sengaja), jadi ukurannya manual: jumlah pengguna Premium baru dalam 30 hari setelah rilis,
ulasan Play yang menyebut Laba Rugi/PDF, pertanyaan dukungan, dan umpan balik 5-10 pelaku UMKM yang dicoba langsung.
Tetapkan ambang sebelum rilis (mis. "5 dari 10 penguji memakai Laba Rugi dua bulan berturut-turut") supaya keputusan
tidak berdasarkan perasaan.
