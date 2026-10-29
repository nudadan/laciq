# Daftar uji HP: Mode usaha dan Laba Rugi (Fase 1 UMKM)

> Dibuat 2026-10-29. Membuktikan di HP nyata hal yang baru lulus tes otomatis (873 tes): migrasi skema v12, pengelompokan kategori, angka Laba Rugi,
> PDF dan Excel. Rencana: [RENCANA-IMPLEMENTASI-UMKM.md](RENCANA-IMPLEMENTASI-UMKM.md). Rilis: [RILIS-1.2.0+16.md](RILIS-1.2.0+16.md).
> Butir bertanda **WAJIB** harus lulus sebelum rilis.

## 0. Aturan berhenti
Hentikan dan JANGAN rilis bila terjadi:

| Temuan | Artinya | Tindakan |
|---|---|---|
| **L1** gagal: data, saldo dompet, atau jumlah transaksi berubah setelah memperbarui dari build 15 | Migrasi v12 merusak data | Pulihkan dari backup berkas; periksa `onUpgrade` (langkah v12) dan `_applyReportGroupDefaults` |
| **L5** gagal: "Perubahan kas" tidak sama dengan selisih saldo dompet | Pengelompokan atau perhitungan salah | Bandingkan dengan data uji; jalankan `flutter test test/profit_loss_test.dart` dan tambah kasusnya |
| **L8** gagal: PDF tidak terbuka, huruf kosong/kotak, atau terpotong | Font atau tata letak PDF rusak di perangkat | Periksa `assets/fonts/pdf/` terpasang di bundel dan `profit_loss_pdf.dart` |

## 1. Persiapan
- [ ] Bangun: `source ~/development/env.sh && flutter build apk --debug` (uji cepat) **atau** AAB dari uji internal (lebih mendekati rilis).
- [ ] **Pasang build 15 dulu** (dari Play) dengan data nyata atau data uji yang cukup (beberapa dompet, kategori buatan sendiri, Utang/Piutang, Tabungan bila Ultimate).
      Catat **saldo setiap dompet dan Total Saldo**, jumlah transaksi, dan nama kategori.
- [ ] **Ekspor backup berkas** dari build 15 (Pengaturan > Data > Backup data). Simpan di luar HP.
- [ ] Untuk uji kelompok kategori penuh di buku usaha: butuh **Ultimate atau uji coba 30 hari** (template Bisnis). Tanpa itu, kerjakan jalur Buku Utama (L2, L3) saja.
- [ ] Akun uji: satu Premium (atau Ultimate/trial), satu Gratis (untuk L10).

## 2. Data uji (bulan berjalan)
Catat di **buku usaha baru "Warung uji"** (template Bisnis; dompet "Kas Usaha"). Catat **saldo Kas Usaha sebelum** (harus 0 untuk buku baru).

| # | Jenis | Kategori | Nominal |
|---|---|---|---|
| 1 | Pemasukan | Penjualan | 1.000.000 |
| 2 | Pengeluaran | Pembelian Stok / Bahan Baku | 200.000 |
| 3 | Pengeluaran | Sewa Tempat | 300.000 |
| 4 | Pemasukan | Pendapatan Lain | 50.000 |
| 5 | Pengeluaran | Utang | 100.000 |
| 6 | Pemasukan | Modal Masuk | 500.000 |
| 7 | Pengeluaran | Peralatan | 150.000 |

**Hasil yang diharapkan** (hitung ulang bila Anda mengubah data):

| Baris laporan | Nilai |
|---|---|
| Pendapatan usaha | Rp 1.000.000 |
| HPP | -Rp 200.000 |
| Laba kotor | Rp 800.000 (80,0%) |
| Beban operasional | -Rp 300.000 |
| Laba operasional | Rp 500.000 (50,0%) |
| Pendapatan lain | Rp 50.000 |
| **Laba bersih** | **Rp 550.000** (55,0% dari pendapatan usaha) |
| Di luar laba rugi | Modal Masuk +500.000; Utang -100.000; Peralatan -150.000 |
| **Perubahan kas** | **Rp 800.000** (= 550.000 + 500.000 - 100.000 - 150.000) |
| Saldo Kas Usaha sesudah | Rp 800.000 (jika saldo awal 0) |

## 3. Butir uji
### Migrasi dan data
- [ ] **L1 WAJIB** Perbarui dari build 15 ke build baru **tanpa menghapus data**. Setelah dibuka: semua dompet, saldo, Total Saldo, jumlah transaksi, kategori,
      anggaran, Utang/Piutang, dan (bila ada) buku/tabungan **sama persis** dengan catatan di 1. Tidak ada layar kesalahan atau minta onboarding ulang.
- [ ] **L1b** Di layar Kategori (buku usaha, bila ada): kategori Utang, Piutang, Tabungan, Penyesuaian Saldo menampilkan **"Di luar laba rugi"**. Buku yang dibuat dari
      template Bisnis sebelumnya otomatis berstatus **Mode usaha** menyala.
- [ ] **L11 WAJIB** Backup berkas lalu **Pulihkan** ke build baru (dan, bila Premium, Backup Cloud lalu pulihkan): kelompok kategori dan Mode usaha utuh; angka Laba Rugi sama.
      Backup dari build 15 (v8) tetap bisa dipulihkan.

### Mode usaha dan kategori
- [ ] **L2** Lainnya > **Mode usaha** (akun Gratis/Premium, Buku Utama): menyala; Kategori kini menampilkan kelompok di bawah nama ("Beban operasional · otomatis", dst.); mati: hilang.
      Data tidak berubah. Di Ultimate: dialog Buku Baru/Ubah punya saklar "Buku usaha"; template Bisnis menyalakannya otomatis.
- [ ] **L3** Kategori baru di buku usaha: ketik **"Beli stok"** → otomatis **HPP** + tulisan "Disarankan dari nama kategori"; **"Prive"** → Di luar laba rugi; **"Sewa kios"** → Otomatis.
      Pilih kelompok lain secara manual lalu ubah nama: pilihan tidak berubah. Jadikan sub-kategori: pilihan kelompok diganti catatan "mengikuti induk".
- [ ] **L6** Ubah kelompok satu kategori yang sudah terpakai (mis. Peralatan → Beban operasional): angka Laba Rugi berubah sesuai (laba turun 150.000), lalu kembalikan.

### Laporan
- [ ] **L4 WAJIB** Lainnya > **Laba Rugi** (akun Premium): semua angka cocok dengan tabel hasil yang diharapkan di bagian 2. Kartu atas: "Laba bersih Rp 550.000", "55,0% dari pendapatan usaha".
- [ ] **L5 WAJIB** Blok "Dari laba ke kas": **Perubahan kas = Rp 800.000** dan sama dengan selisih saldo Kas Usaha (sebelum → sesudah). Bandingkan juga untuk buku/dompet lain bila memakai Buku Utama:
      Total Saldo sesudah - sebelum = Perubahan kas (transfer antar dompet tidak memengaruhi).
- [ ] **L7** Periode: **3 Bulan** (menyertakan dua bulan sebelumnya), **Tahun**, panah bulan/tahun, **Kustom** (pilih tanggal; label rentang di bawah tombol benar, hari terakhir ikut).
      Bulan tanpa transaksi: keadaan kosong. Bandingkan "▲/▼ ... dibanding periode sebelumnya" dengan hitungan manual bila ada data bulan lalu.
- [ ] **L7b** Buku pribadi (Mode usaha mati): muncul ajakan **Nyalakan Mode usaha**; laporan tetap terbaca dengan kelompok bawaan.
- [ ] **L10** Akun **Gratis**: tile "Laba Rugi" menampilkan "Fitur Premium" dan membuka halaman upgrade. Turun dari Premium ke Gratis: kelompok kategori dan Mode usaha **tetap**; hanya layar laporan terkunci.

### Ekspor
- [ ] **L8 WAJIB** Laba Rugi > ikon bagikan > **Bagikan PDF** → kirim ke WhatsApp/Drive, buka di HP lain: judul = nama buku, periode benar, huruf **tebal tampil**, simbol "Rp" dan titik ribuan benar,
      tabel tidak terpotong, 1 halaman A4, catatan "bukan laporan resmi" dan nomor halaman ada. Coba juga dengan rincian panjang (tambahkan ±40 kategori beban): halaman kedua rapi.
- [ ] **L9** **Ekspor Excel** (dari Laba Rugi, dan dari Pengaturan > Ekspor laporan Excel pada buku usaha): lembar **"Laba Rugi"** di urutan kedua; angka berupa angka (bisa dijumlahkan), pengurang negatif,
      persen berformat persen; buka di Google Sheets/Excel. Buku pribadi lewat Pengaturan: **tanpa** lembar Laba Rugi.

### Tampilan
- [ ] **L12** Tema terang dan gelap, ukuran huruf sistem besar, dan layar lipat/kecil (Fold6 tertutup): tabel dan tombol tidak terpotong, kontras terbaca, tidak ada overflow kuning-hitam.
- [ ] **L13** Ukuran: catat ukuran AAB/APK dibanding +15 (87,4 MB). Catat bila naik > 1 MB.

## 3b. Gladi di emulator (2026-10-29): migrasi pembaruan di tempat
Dilakukan SEBELUM uji di Redmi, dengan APK debug di emulator Android 15 (`aisha_api35`), bukan pengganti uji Play (L1) di HP nyata.

**Cara:** baseline persis 1.1.0+15 (commit `3fa6f29`, skema v11) dibangun debug di worktree terpisah dan dipasang; DB-nya diisi data realistis
(2 buku, 19 transaksi, 38 kategori termasuk kategori buatan pengguna bernama "Tabungan", sub-kategori, utang dengan pembayaran, transfer);
aplikasi baseline dibuka dan membaca data dengan benar (Total Saldo Rp 10.307.000 = Tunai -343.000 + BCA 10.650.000); lalu APK baru dipasang
**di atasnya** (`adb install -r`, `firstInstallTime` tetap, `lastUpdateTime` berubah) dan dibuka.

| Pemeriksaan | Hasil |
|---|---|
| `PRAGMA user_version` | 11 → **12** |
| Kolom baru | `categories.report_group` dan `ledgers.kind` ada |
| Jumlah baris | transaksi 19, kategori 38, dompet 3, utang 1: **sama** sebelum dan sesudah |
| Saldo dompet (dihitung ulang dari DB) | Tunai -343.000, BCA 10.650.000, Kas Usaha 1.350.000: **sama** |
| Kelompok kategori terisi | Utang, Piutang (utama dan buku usaha), Pembelian Stok = HPP (1), Peralatan, Cicilan Usaha, Modal Masuk, Utang/Piutang buku usaha = di luar laba rugi (5), Pendapatan Lain = lain (3); **kategori buatan "Tabungan" = di luar laba rugi**; sisanya kosong; sub-kategori "Warteg" kosong (mengikuti induk) |
| Sifat buku | Buku Utama = pribadi (0); "Warung Bu Sari" (punya kategori "Penjualan" bawaan) = **usaha (1)** otomatis |
| UI Lainnya | Tile "Mode usaha" ada (mati); "Buku Kas · 1 buku terkunci" (benar tanpa Ultimate); "Laba Rugi · Fitur Premium" |
| UI Kategori setelah Mode usaha dinyalakan | Subjudul "Beban operasional · otomatis" di kategori utama; sub-kategori tanpa subjudul |
| UI Kategori Baru, ketik "Beli stok" | Otomatis terpilih **Harga pokok penjualan (HPP)** + penjelasan + "Disarankan dari nama kategori. Ubah bila perlu." |

**Belum tercakup gladi ini (tetap perlu uji HP):** layar Laba Rugi dan ekspor PDF/Excel (butuh Premium; emulator tanpa langganan), pembaruan dari build **Play**
yang bertanda tangan Play (L1 sebenarnya), tampilan di layar HP nyata, WhatsApp/Excel/Google Sheets.

## 3c. Hasil uji Redmi (2026-10-29, rilis internal 1.2.0+16)
Pemilik menghapus aplikasi build 15 dari Redmi, memasang 1.2.0 dari jalur internal Play, lalu **memulihkan backup berkas** (format v8): **saldo dan angka sama** dengan sebelum
(menutup pemulihan backup lama ke v12). Karena aplikasi dihapus lebih dulu (terbukti dari `firstInstallTime` = `lastUpdateTime`), **pembaruan di tempat di Redmi tidak teruji**; itu tercakup gladi emulator (3b).

**Temuan dari uji ini (bug, sudah diperbaiki di kode):** backup format < 9 dipulihkan dengan kelompok laporan kosong, jadi kategori sistem tidak berstatus "di luar laba rugi" dan buku usaha
kembali pribadi. Perbaikan: `BackupService.parse` menerapkan kelompok bawaan yang sama dengan migrasi v12 untuk backup < v9 (tes: `report_group_test.dart`, pemulihan backup v8 -> Laba Rugi benar).
Berlaku untuk **build 1.2.0+16 yang sudah di jalur internal** (data yang dipulihkan dari backup lama di build itu perlu dipulihkan ulang atau dikelompokkan manual); perbaikan ikut build berikutnya (+17).

## 3d. Hasil uji Redmi (2026-10-29 sore, build 1.2.0+17 dari Play, uji coba Ultimate aktif)
Dikerjakan lewat adb (ketukan dan pembacaan layar aplikasi); data di HP adalah data dummy milik pemilik. Berkas **backup uji format v8** (12 transaksi, 2 buku: Buku Utama pribadi
dan "Warung Bu Sari" template Bisnis, tanpa kolom `kind`/`reportGroup`) dibuat di PC dan dipulihkan lewat Pengaturan > Pulihkan.

| Butir | Hasil |
|---|---|
| Pembaruan 16 → 17 dari Play (tanpa menghapus) | **Lulus**: `firstInstallTime` tetap (14:03:28), `lastUpdateTime` 15:00:07 |
| L11 pulihkan backup lama (v8) | **Lulus**: Buku Utama Total Saldo Rp 6.050.000 (BCA 6.400.000 + Tunai -350.000), Pemasukan 5.000.000, Pengeluaran 950.000; Warung Bu Sari Rp 1.350.000 |
| L1b perbaikan +17 pada pemulihan backup lama | **Lulus**: "Warung Bu Sari" otomatis **Mode usaha** menyala; di Kategori: Pembelian Stok = HPP, Peralatan dan Cicilan Usaha = Di luar laba rugi; lainnya "Beban operasional · otomatis" |
| L4 angka Laba Rugi (Oktober) | **Lulus**: pendapatan 1.000.000, HPP -200.000, laba kotor 800.000 (80,0%), beban -300.000, laba operasional 500.000, pendapatan lain +50.000, **laba bersih 550.000 (55,0%)** |
| L5 rekonsiliasi kas | **Lulus**: Laba bersih 550.000 + Modal Masuk 500.000 - Peralatan 150.000 - Utang 100.000 = **Perubahan kas 800.000** |
| L7 periode | **Lulus**: Bulan, 3 Bulan (1 Agu-31 Okt: laba 1.100.000, 61,1%), Tahun (1 Jan-31 Des: 1.100.000); pembanding "Sama dengan periode sebelumnya (Rp 550.000)" benar (September juga 550.000); label rentang benar |
| L7b buku pribadi | **Lulus**: kartu "Buku ini belum Mode usaha" + tombol; angka bawaan tetap terbaca (3 bulan: laba 4.050.000) |
| L3 saran nama | **Lulus**: "Prive" otomatis "Di luar laba rugi" + penjelasan |
| L8 PDF | **Sebagian**: pembuatan PDF di HP berhasil (lembar bagikan Android menampilkan `laciq-laba-rugi-20260801_20261031.pdf`, nama sesuai periode). **Tampilan visual PDF belum diperiksa** (butuh dibuka di aplikasi PDF/WhatsApp oleh pemilik) |
| L9 Excel | **Sebagian**: pembuatan Excel berhasil (`laciq-laba-rugi-20260801_20261031.xlsx` di lembar bagikan). **Isi lembar belum diperiksa** di Google Sheets/Excel |
| L2, L6, L10, L12, L13 | Belum diuji di HP (saklar Mode usaha tampil benar di Lainnya; ubah kelompok manual; akun Gratis; tema terang/huruf besar; ukuran) |

**Temuan dari uji ini (sudah diperbaiki di kode, belum di build):** kartu ringkas di atas layar memberi label "HPP + beban" untuk angka yang sudah dikurangi pendapatan lain
(Rp 450.000 padahal HPP 200.000 + beban 300.000 = 500.000), sehingga menyesatkan. Kini kartu menampilkan **Total pendapatan** (pendapatan usaha + pendapatan lain, 1.050.000) dan **Total biaya**
(HPP + beban + beban lain, 500.000): selisihnya selalu sama dengan laba bersih. Tes ditambahkan. Perlu build +18.

**Tindak lanjut (2026-10-29 15.52): build 1.2.0+18 di Redmi.** Pembaruan 17 → 18 dari Play **lulus tanpa menghapus aplikasi** (`firstInstallTime` tetap 14:03:28). Kartu ringkasan Laba Rugi
"Warung Bu Sari" kini: **Laba bersih Rp 550.000 (55,0%)**, **Total pendapatan Rp 1.050.000**, **Total biaya Rp 500.000** (selisihnya = laba bersih): temuan "HPP + beban" **tertutup**.
**Pemeriksaan pemilik (2026-10-29): PDF (L8) dan Excel (L9) baik** (dibuka dari HP; PDF dan lembar "Laba Rugi" tampil sesuai). Sisa L2/L6/L10/L12 bersifat opsional.
Ringkasan butir WAJIB: L1b, L4, L5, L8, L11 **lulus**; L1 (pembaruan di tempat dari build 15) lulus di gladi emulator dan pembaruan Play 16→17→18 di Redmi, bukan dari 15 langsung.

## 4. Catatan hasil
| Butir | Lulus? | Perangkat / versi | Catatan |
|---|---|---|---|
| L1 | | | |
| L1b | | | |
| L2 | | | |
| L3 | | | |
| L4 | | | |
| L5 | | | |
| L6 | | | |
| L7 | | | |
| L7b | | | |
| L8 | | | |
| L9 | | | |
| L10 | | | |
| L11 | | | |
| L12 | | | |
| L13 | | | |

Temuan yang gagal: catat langkah, perangkat, dan tangkapan layar; tambahkan tes otomatis yang mereproduksinya sebelum memperbaiki.
