# Rencana Implementasi UMKM — Fase 2 (pelanggan, pemasok, nota, tutup kas)

> Dibuat 2026-10-29, melanjutkan [RENCANA-IMPLEMENTASI-UMKM.md](RENCANA-IMPLEMENTASI-UMKM.md) §5 setelah Fase 1 (Mode usaha, Laba Rugi, PDF/Excel) teruji di HP nyata
> dan dikirim ke Produksi 50% (menunggu tinjauan Google). Belum ada kode Fase 2. Dasar: skema **v12**, format backup **v9**, 875 tes Flutter.
> Prinsip tetap sama dengan Fase 1 (§1 di rencana utama): sederhana dan berbasis kas, satu sumber kebenaran, offline-first, uang = integer Rupiah,
> migrasi disiplin, enum disimpan sebagai indeks (jangan diubah).

## 0. Syarat mulai (jangan mulai sebelum terpenuhi)
Fase 2 menambah data pihak ketiga (nama dan telepon pelanggan/pemasok), jadi mulai hanya bila **semua** berikut benar:
1. Fase 1 sudah tayang 100% dan stabil (Android vitals, ulasan, RevenueCat) minimal 2 minggu.
2. Ada sinyal pemakaian: ambang yang ditetapkan di rencana utama §9 (mis. 5 dari 10 penguji UMKM memakai Laba Rugi dua bulan berturut-turut) **atau** permintaan fitur nyata
   (ulasan/pesan) untuk catat pelanggan, tagih piutang, atau nota. Tanpa sinyal, Fase 2 hanya menebak.
3. Keputusan di §2 sudah ditetapkan pemilik.

## 1. Temuan penting dari kode (mengubah rancangan awal)

**T1: pembayaran piutang di kode sekarang tidak pernah menjadi pendapatan.** `recordDebtPayment` memakai kategori "Piutang" (`cat-inc-piutang`), dan sejak v12 kategori itu
berkelompok **di luar laba rugi**. Jadi bila pemilik usaha mencatat penjualan kredit sebagai piutang lalu menerima pelunasannya, uang itu **tidak muncul sebagai pendapatan**
di Laba Rugi (hanya di "Dari laba ke kas"). Untuk piutang berupa pinjaman ke teman itu benar; untuk **penjualan** kepada pelanggan itu salah. Fase 2 harus membedakan keduanya
(§3.3). Ini sekaligus inti keputusan U8.

**T2: pihak lawan hanya teks.** `Debts.counterpartyName` (1-60 karakter) tanpa identitas. Nama yang sama diketik berbeda ("Pak Budi", "pak budi ") menjadi dua pihak berbeda; tidak ada
telepon; tidak ada rekap per pihak.

**T3: fondasi sudah ada.** Sesuaikan saldo (kategori sistem "Penyesuaian Saldo" di luar laba rugi) cukup untuk **tutup kas**; `url_launcher` sudah dipakai (membuka WhatsApp tanpa
izin baru); `profit_loss.dart` + `profit_loss_pdf.dart` + font tebal statis bisa dipakai ulang untuk nota; `Debts` sudah punya jatuh tempo, cicilan, dan buku kas (`ledgerId`).

## 2. Keputusan yang menunggu pemilik

| # | Keputusan | Rekomendasi | Alasan |
|---|---|---|---|
| U8 | Pengakuan pendapatan penjualan kredit | **Tetap basis kas** (pendapatan saat uang diterima) + baris informasi **"Piutang belum diterima"** di Laba Rugi dan PDF | Konsisten dengan prinsip 1; tidak memaksa pengguna paham akrual; angka tetap cocok dengan saldo dompet. Alternatif (pendapatan diakui di tanggal nota) lebih "benar" tetapi memerlukan baris rekonsiliasi tambahan dan penjelasan; tunda sampai ada permintaan |
| U9 | Paket untuk kontak, piutang per pelanggan, nota PDF, tutup kas | **Premium** (memperluas Utang/Piutang yang sudah Premium); "Catat cepat" **Gratis** maksimal 3 pintasan, Premium tanpa batas (pola "cicip") | Penjualan harian cepat adalah pemicu pemasangan UMKM; fitur yang bernilai bagi pemilik usaha (nota, tagih) menjadi alasan naik paket |
| U10 | Telepon pelanggan | **Opsional** dan hanya angka; disimpan lokal; tidak diminta izin kontak HP (ketik manual atau tempel) | Hindari izin `READ_CONTACTS` (Data Safety "Kontak", tinjauan Play) |
| U11 | Nomor nota | Otomatis berurutan per buku per tahun ("INV-2026-0001"), dapat diubah tangan sebelum disimpan | Cukup untuk usaha kecil; tidak perlu format pajak (bukan faktur pajak) |
| U12 | Penafian nota | Wajib di PDF: "Nota/tanda terima ini dibuat dengan LaciQ, bukan faktur pajak" | Menghindari salah paham hukum/pajak |
| U13 | Pesan penagihan WhatsApp | Teks siap kirim, sopan, **dapat diedit** sebelum dikirim; tidak ada pengiriman otomatis; tautan `https://wa.me/<62...>?text=...` dibuka atas ketukan pengguna | Tanpa API, tanpa izin, tanpa server |

## 3. Model data dan perilaku

### 3.1 Fase 2A: Kontak dan piutang per pelanggan (skema v13, backup v10)
Tabel baru `Contacts`: `id`, `name` (1-60), `kind` (`intEnum<ContactKind>`: `customer`=0, `supplier`=1, `both`=2; **indeks tetap**), `phone` (null atau angka 8-15, disimpan
dinormalkan tanpa spasi), `note` (null), `ledgerId` (default `ledger-main`), `archived`, `createdAt`, `updatedAt`. Nama unik per buku tanpa membedakan huruf dan spasi tepi.
Kolom baru `Debts.contactId` (null). `counterpartyName` **dipertahankan** (tampilan dan kompatibilitas backup lama).

Migrasi v12 → v13: sisipkan kontak dari nama pihak lawan yang sudah ada, **otomatis** dengan pencocokan nama setelah dirapikan (huruf kecil, spasi digabung) per buku;
jenis: utang = `supplier`, piutang = `customer`, nama di kedua = `both`. `Debts.contactId` diisi. Idempoten dan diuji dari v1-v12 (pola `test/migration_test.dart` +
gotcha "duplicate column": tabel yang dibuat di migrasi yang sama sudah berdefinisi terkini).

Perilaku:
- Form utang/piutang: kolom nama diganti **pemilih kontak** (ketik untuk mencari; "Tambah kontak baru" di tempat). Pembayaran dan jatuh tempo seperti sekarang.
- Layar **Kontak** (Lainnya): daftar dengan total piutang dan utang terbuka per kontak, urut terbesar; detail kontak = riwayat utang/piutang dan pembayaran.
- **Umur piutang** (0-30, 31-60, >60 hari terlambat dari jatuh tempo; tanpa jatuh tempo dihitung dari tanggal dibuat): ringkasan di atas layar Piutang.
- **Tagih lewat WhatsApp** (U13): tombol di baris piutang; teks: "Halo {nama}, mengingatkan {catatan/tagihan} sebesar Rp X yang jatuh tempo {tanggal}. Terima kasih. - {nama buku}".
  Tanpa telepon: tombol "Salin pesan".
- Backup v10 memuat `contacts` dan `debts.contactId`; backup < v10 dipulihkan dengan kontak dibuat otomatis seperti migrasi (fungsi bersama, belajar dari bug pemulihan backup v8 di Fase 1).

### 3.2 Fase 2B: Nota/invoice PDF (skema v14, backup v11)
Tabel `Invoices` (`id`, `number`, `contactId` null, `customerName` salinan teks, `date`, `dueDate` null, `note` null, `discount` int ≥ 0, `revenueCategoryId` null,
`debtId` null, `ledgerId`, `createdAt`, `updatedAt`) dan `InvoiceItems` (`id`, `invoiceId`, `name` 1-80, `quantity` int ≥ 1, `unit` null, `unitPrice` int ≥ 0, `sortOrder`).
Jumlah dan total **diturunkan** dari butir dikurangi diskon (tanpa kolom total). Batas: 50 butir per nota; total maksimal 1.000.000.000 (sama dengan batas transaksi).

Alur: buat nota → pilih "Sudah dibayar" (langsung mencatat satu transaksi pemasukan berkategori pendapatan, mis. Penjualan) **atau** "Belum dibayar" (membuat piutang
terhubung kontak/nota dengan jatuh tempo). PDF A4 (nama usaha, nomor, tanggal, pelanggan, tabel butir, diskon, total, status, catatan, penafian U12) memakai
`profit_loss_pdf.dart` sebagai pola dan font yang sama; dibagikan lewat lembar bagikan.

### 3.3 Menjawab T1: pembayaran piutang nota
Piutang yang berasal dari nota membawa `revenueCategoryId` (bawaan "Penjualan" di buku itu, boleh diganti). **Pembayaran piutang nota dicatat ke kategori pendapatan itu**,
bukan kategori "Piutang". Akibatnya, dengan basis kas: pendapatan tercatat saat uang diterima, Laba Rugi benar, dan rekonsiliasi kas tetap cocok. Piutang pinjaman biasa
(bukan nota) tetap memakai "Piutang" di luar laba rugi. `recordDebtPayment` mendapat parameter kategori (bawaan lama tetap berlaku) dengan tes untuk dua jalur.

Baris informasi (U8): **"Piutang belum diterima (nota)"** = jumlah sisa piutang nota per akhir periode, ditampilkan di Laba Rugi dan PDF di bawah "Dari laba ke kas"
sebagai catatan, **tidak** masuk perhitungan laba.

### 3.4 Fase 2C: Tutup kas harian dan Catat cepat (skema v15, backup v12)
- Tabel `CashClosings` (`id`, `ledgerId`, `accountId`, `date`, `systemBalance`, `countedBalance`, `difference` turunan dari kedua angka sehingga tidak disimpan,
  `note`, `createdAt`). Alur: pilih dompet tunai → sistem menampilkan saldo → pengguna mengisi hitungan fisik → selisih ≠ 0 mencatat Sesuaikan saldo (transaksi
  Penyesuaian Saldo di luar laba rugi) dan satu baris riwayat. Riwayat menampilkan selisih per hari (jejak sederhana kebocoran kas).
- Tabel `QuickEntries` (`id`, `ledgerId`, `title`, `type`, `amount`, `categoryId`, `accountId`, `sortOrder`): pintasan satu ketuk di formulir Catat dan Ringkasan untuk
  transaksi berulang harian ("Es teh 5.000"); membuat transaksi bertanggal hari ini. Gratis maksimal 3 (U9).

## 4. Pembagian rilis dan urutan kerja
Satu fase = satu rilis (skema dan backup naik tiap fase; mudah dilacak dan dibatalkan). Tiap fase: skema + migrasi + tes dulu, lalu logika murni dengan tes unit (termasuk
uji properti seperti rekonsiliasi di Fase 1), lalu UI, lalu ekspor/dokumen, lalu uji HP dengan data uji berangka (pola [UJI-HP-LABA-RUGI.md](UJI-HP-LABA-RUGI.md)).

| Fase | Isi | Skema/backup | Perkiraan |
|---|---|---|---|
| 2A | Kontak, piutang/utang per kontak, umur piutang, tagih WhatsApp | v13 / v10 | Terbesar nilainya, risiko rendah (mirip Utang/Piutang yang ada) |
| 2B | Nota PDF + pembayaran nota sebagai pendapatan (T1) + "Piutang belum diterima" | v14 / v11 | Butuh keputusan U8 dan uji hati-hati rekonsiliasi |
| 2C | Tutup kas, Catat cepat | v15 / v12 | Ringan |

Urutan 2A → 2B → 2C. 2C bisa naik lebih dulu bila Catat cepat ingin dijadikan alat akuisisi gratis.

## 5. Tes yang wajib per fase (ringkas)
- Migrasi dari **semua** versi lama; data utuh; kontak hasil migrasi benar (nama beda huruf/spasi digabung; dua buku tidak tergabung).
- Backup: putaran penuh versi baru; backup lama dipulihkan dengan nilai bawaan yang **sama** dengan migrasi (fungsi bersama + tes, pelajaran Fase 1); nilai enum/rujukan rusak ditolak.
- Logika murni: umur piutang (batas hari, tanpa jatuh tempo), total nota (diskon, batas), nomor nota berurutan per buku per tahun, normalisasi telepon (0812…, +62812…, 62812…).
- Rekonsiliasi: pembayaran nota → pendapatan masuk Laba Rugi; piutang pinjaman tetap di luar laba rugi; jembatan ke kas selalu cocok (uji properti data acak).
- UI: pemilih kontak, buat kontak di tempat, nota (simpan/PDF), gating paket (Gratis diajak upgrade; turun paket: data tetap, hanya layar terkunci), tombol tagih.
- Aksesibilitas dan tema: kontras dari `AppPalette`; uji huruf besar di HP.

## 6. Privasi dan toko (wajib sebelum rilis 2A)
- Nama dan telepon pelanggan/pemasok adalah **data pribadi pihak ketiga**. Tetap di HP; ikut backup berkas dan backup Drive terenkripsi (sudah dideklarasikan sebagai data pengguna);
  **tidak** dikirim ke server kami. Perbarui [kebijakan privasi](kebijakan-privasi/index.html) (bagian data yang disimpan di perangkat dan bagian backup) dan periksa ulang
  [DATA-SAFETY-PLAY.md](DATA-SAFETY-PLAY.md): tanpa izin `READ_CONTACTS`, kategori "Kontak" Play tidak berlaku (data diketik pengguna, tidak dibaca dari buku alamat), tetapi **tulis alasannya**.
- Tautan WhatsApp dibuka hanya atas ketukan pengguna; nomor dan teks pesan dikirim ke WhatsApp oleh pengguna sendiri, bukan oleh LaciQ. Sebutkan di kebijakan.
- Ringkasan AI untuk usaha (Ultimate, opsional, belum dirancang) tetap hanya **angka agregat**; nama pelanggan/barang tidak pernah dikirim.
- Penafian nota (U12) dan bukan faktur pajak; tidak ada klaim kepatuhan pajak.

## 7. Risiko
| Risiko | Penanganan |
|---|---|
| Penggabungan kontak otomatis keliru (dua orang bernama sama jadi satu) | Pencocokan hanya nama persis (setelah dirapikan) **per buku**; layar Kontak punya "Pisahkan/Gabungkan" sederhana di 2A.1; tidak ada penghapusan data |
| Pengguna mengira nota = faktur pajak | Penafian di PDF dan layar; tidak memakai kata "faktur pajak" |
| Basis kas membingungkan pemilik usaha yang berjualan kredit | Catatan jelas + baris "Piutang belum diterima"; U8 dapat ditinjau ulang setelah umpan balik |
| Cakupan melebar jadi aplikasi kasir/POS | Batas tegas: tanpa stok (Fase 3), tanpa multi-kasir, tanpa pajak; Fase 2 hanya 2A/2B/2C |
| Migrasi besar gagal pada sebagian perangkat | Satu skema per rilis, uji dari semua versi, gladi emulator dengan data nyata sebelum rilis (seperti Fase 1), jeda peluncuran |
| Beban `database.dart` (3.600+ baris) | Logika baru di berkas sendiri (`contacts.dart`, `invoices.dart`, `receivables.dart`); jangan menambah query ke `database.dart` selain CRUD tabel |

## 8. Fase 3 (garis besar, tidak berubah)
Produk dan stok sederhana, HPP otomatis rata-rata bergerak, laporan per produk, ringkasan posisi keuangan, perkiraan PPh final 0,5% sebagai informasi (U7). Dirinci setelah 2A-2C terbukti dipakai.

## 9. Cara mengukur
Tidak ada telemetri di aplikasi (sengaja). Ukuran manual: jumlah pengguna Premium baru 30 hari setelah tiap rilis, ulasan dan pesan yang menyebut kontak/nota/tagih,
10 pelaku UMKM yang dicoba langsung (target: 5 memakai fitur dua minggu berturut-turut). Tetapkan ambang **sebelum** rilis.
