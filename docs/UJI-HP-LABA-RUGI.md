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
