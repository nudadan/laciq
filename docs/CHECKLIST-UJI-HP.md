# Daftar Centang Uji di HP — DompetKu rilis 1.0.0 (build 5)

> Dibuat 2026-10-01. Untuk menguji build uji internal sebelum rilis produksi. Centang `[x]` bila lulus; bila gagal,
> tulis catatan di baris "Catatan" dan kirim ke Claude (sertakan layar atau pesan galat). Bagian bertanda **KRITIS**
> menyangkut uang atau data: kalau gagal, hentikan dulu dan jangan lanjut ke rilis produksi.

## 0. Persiapan

- [ ] HP uji: Redmi (yang sudah memasang rilis 3). Android yang dipakai: ______
- [ ] Akun Google di HP termasuk **penguji lisensi** Play Console (agar pembelian gratis dan berlangganan cepat habis)
- [ ] Akun yang sama termasuk **penguji internal** (daftar penguji jalur Pengujian internal)
- [ ] **Backup lokal dulu** dari rilis 3: Pengaturan > Backup data, simpan berkasnya di luar aplikasi (Drive/PC)
- [ ] Catat angka acuan SEBELUM update: total saldo ______ · jumlah transaksi ______ · jumlah dompet ______
- [ ] Koneksi internet aktif; baterai cukup
- [ ] (Opsional, untuk Claude) siapkan satu struk belanja asli dan satu struk SPBU/yang berlayout rumit

Catatan: ____________________________________________

## A. Update dari rilis 3 ke build 5 — migrasi data **KRITIS**

Build ini mengubah skema database (buku kas). Data lama harus utuh.

- [ ] A1. Play Store > DompetKu > **Perbarui** (atau pasang dari tautan uji internal). Versi terpasang 1.0.0 (5)
      _Cek: Pengaturan akhir halaman / Info aplikasi Android_
- [ ] A2. Aplikasi terbuka **tanpa crash** dan tidak kembali ke layar onboarding (data tidak ter-reset)
- [ ] A3. Total saldo sama dengan angka acuan di bagian 0
- [ ] A4. Jumlah transaksi dan dompet sama dengan angka acuan
- [ ] A5. Anggaran, target, transaksi berulang, agenda, utang piutang lama masih ada (buka satu per satu)
- [ ] A6. Foto struk lama masih bisa dibuka dari transaksinya
- [ ] A7. Catat satu transaksi baru: tersimpan, saldo berubah benar
- [ ] A8. Tutup paksa aplikasi lalu buka lagi: data masih ada

Catatan: ____________________________________________

## B. Tampilan baru (build 5)

- [ ] B1. Pengaturan > **Lihat panduan lagi**: ada **6 halaman** (Catat transaksi · Anggaran dan tren · Rencanakan keuangan ·
      Data di HP · Ultimate · Pilih paket)
- [ ] B2. Setiap halaman bisa digulir ke bawah, teks tidak terpotong atau menumpuk
- [ ] B3. Label **Premium** dan **Ultimate** tampil di fitur yang tepat; halaman terakhir menampilkan kartu Gratis, Premium, Ultimate
- [ ] B4. Tombol "Lewati" dan "Lanjut/Mulai" bekerja; setelah selesai kembali ke Pengaturan
- [ ] B5. Mode terang dan gelap: panduan terbaca jelas di keduanya
- [ ] B6. Isi panduan tidak bertentangan dengan yang Anda lihat di aplikasi (mis. batas 3 bulan tren, 3 item agenda untuk paket gratis)

Catatan: ____________________________________________

## C. Paket Gratis (sebelum membeli)

- [ ] C1. Pengaturan: kartu **"Upgrade ke Premium"** tampil dengan harga bulanan
- [ ] C2. Analisa Tren: hanya 3 bulan; pilihan 6/12 bulan mengajak upgrade
- [ ] C3. Agenda: item ke-4 ditolak dengan ajakan upgrade
- [ ] C4. Backup Cloud, Utang & Piutang, Proyeksi: menampilkan ajakan Premium, bukan crash
- [ ] C5. Buku Kas (menu Lainnya): tertulis **Fitur Ultimate**
- [ ] C6. Iklan banner: tampil setelah masa bebas 30 hari (bisa tidak tampil di HP yang baru dipasang; itu normal)

Catatan: ____________________________________________

## D. Beli Premium **KRITIS**

- [ ] D1. Pengaturan > Upgrade ke Premium: halaman langganan menampilkan Premium (bulanan dan tahunan) dan **Ultimate**
- [ ] D2. Pilih bulanan > Play menampilkan dialog beli dengan label uji (tanpa tagihan nyata) > selesaikan
- [ ] D3. Aplikasi menampilkan Premium aktif (tanpa perlu mulai ulang)
- [ ] D4. Kartu langganan di Pengaturan **rapi**: judul "DompetKu Premium aktif" tidak terpotong; tombol **Upgrade** dan **Kelola** berada di baris bawah
- [ ] D5. Iklan hilang; Analisa Tren 6/12 bulan terbuka; Agenda tanpa batas; Utang & Piutang terbuka; Backup Cloud terbuka
- [ ] D6. Play Store > Pembayaran & langganan: ada **1** langganan DompetKu Premium

Catatan: ____________________________________________

## E. Upgrade Premium → Ultimate **KRITIS** (uji penggantian produk)

Ini uji terpenting: salah penggantian bisa membuat pengguna tertagih dua langganan.

- [ ] E1. Pengaturan > **Upgrade** (di kartu Premium): halaman hanya menampilkan kartu **Ultimate** (judul "Upgrade ke Ultimate")
- [ ] E2. Pilih bulanan > dialog Play menyebut **mengganti** langganan Premium (bukan langganan baru terpisah)
- [ ] E3. Selesaikan pembelian > aplikasi menampilkan **"DompetKu Ultimate aktif"**
- [ ] E4. Play Store > Pembayaran & langganan: hanya **1** langganan aktif (Ultimate); Premium tidak lagi aktif atau tertagih terpisah
      **Bila ada 2 langganan aktif: HENTIKAN, screenshot, kirim ke Claude.**
- [ ] E5. Semua fitur Premium tetap terbuka (iklan tetap hilang, Backup Cloud tetap bisa)
- [ ] E6. Kartu langganan Ultimate: hanya tombol **Kelola**, tanpa **Upgrade**
- [ ] E7. Menu Lainnya > **Buku Kas** terbuka (tidak lagi bertuliskan Fitur Ultimate)

Catatan: ____________________________________________

## F. Scan struk

### F1. Scan biasa (heuristik di HP)
- [ ] F1.1. Catat > Scan Struk > Kamera: foto struk belanja biasa
- [ ] F1.2. Nominal, tanggal, dan nama toko terisi; foto struk tersimpan ("Foto tersimpan")
- [ ] F1.3. Simpan transaksi: foto struk terbuka dari detail transaksi

### F2. Scan dengan AI (Ultimate) **KRITIS untuk fitur Ultimate**
- [ ] F2.1. Scan pertama: muncul dialog **"Isi otomatis dengan AI?"**; pilih **Izinkan**
- [ ] F2.2. Nama toko, kategori, **total, dan tanggal** terisi (kategori masuk akal)
- [ ] F2.3. Scan struk SPBU atau struk berlayout dua kolom: **total benar** (di rilis lama heuristik sering salah di sini)
- [ ] F2.4. Scan kedua: tidak bertanya izin lagi
- [ ] F2.5. Total/tanggal yang Anda ubah sendiri **tidak ditimpa** AI bila Anda mengetik selagi menunggu
- [ ] F2.6. Waktu tunggu AI wajar (kira-kira di bawah 5 detik) dan ada indikator loading

Struk yang diuji dan hasilnya (isi di sini):

| Struk | Total benar? | Toko benar? | Kategori benar? | Tanggal benar? |
|---|---|---|---|---|
| | | | | |
| | | | | |
| | | | | |

### F3. Menolak izin dan kegagalan (fallback)
- [ ] F3.1. Hapus data aplikasi atau pilih **Lewati** pada dialog izin: scan tetap jalan dengan hasil heuristik, AI tidak dipanggil
- [ ] F3.2. **Mode pesawat** lalu scan: hasil heuristik tetap terisi, **tanpa pesan galat yang mengganggu**
- [ ] F3.3. Setelah internet kembali, scan dengan AI normal lagi
- [ ] F3.4. (Opsional) Scan struk yang buram/bukan struk: tidak crash

### F4. Kuota
Kuota 300 per bulan dan 15 per hari; sulit dihabiskan di HP, jadi cukup periksa tampilan dasar.
- [ ] F4.1. Tidak ada pesan "kuota" yang muncul berulang-ulang di tiap scan
- [ ] F4.2. (Bila sempat) 16 scan dalam satu hari: scan ke-16 menampilkan **sekali** pesan "Batas scan AI hari ini tercapai", dan hasil biasa tetap dipakai

Catatan: ____________________________________________

## G. Multi buku kas (Ultimate) **KRITIS**

- [ ] G1. Lainnya > **Buku Kas**: ada **Buku Utama**; tombol tambah buku
- [ ] G2. Buat buku **"Bisnis"** (pilih templat dan ikon): berhasil, muncul di daftar
- [ ] G3. Ganti ke buku Bisnis lewat pengalih buku: dasbor menampilkan saldo **0** dan dompet/kategori sesuai templat, **bukan** data Buku Utama
- [ ] G4. Saat di buku Bisnis, ada penanda jelas "mencatat di buku Bisnis" pada form Catat
- [ ] G5. Catat satu pemasukan dan satu pengeluaran di buku Bisnis
- [ ] G6. Kembali ke Buku Utama: transaksi Bisnis **tidak** muncul; saldo Buku Utama **tidak berubah**
- [ ] G7. Anggaran, target, agenda, utang piutang, transaksi berulang: terpisah per buku (buat satu di Bisnis, pastikan tidak ada di Utama)
- [ ] G8. Ekspor CSV di buku Bisnis: isinya hanya transaksi Bisnis
- [ ] G9. Ubah nama dan arsipkan buku (buku arsip tidak dihitung batas 5). Hapus buku: ada **dialog konfirmasi eksplisit** karena penghapusan permanen beserta seluruh isinya; Buku Utama **tidak** bisa dihapus
- [ ] G10. Buat buku sampai **5 buku**; buku ke-6 ditolak dengan pesan batas
- [ ] G11. Transfer antar dompet dari dua buku berbeda **ditolak** (tidak boleh lintas buku)
- [ ] G12. Backup data (berkas) lalu **pulihkan**: kedua buku dan transaksinya kembali utuh

Catatan: ____________________________________________

## H. Fitur Premium lain (uji cepat, pakai data nyata)

- [ ] H1. **Backup Cloud**: masuk dengan akun Google > unggah > hasilnya sukses (catatan: login di build Play bergantung OAuth client Play App Signing, mungkin gagal; kirim pesannya bila gagal)
- [ ] H2. **Pulihkan Backup Cloud** (setelah H1): data kembali utuh, termasuk foto struk
- [ ] H3. **Proyeksi bulanan** dan **simulasi arus kas** ("cukup sampai tanggal X"): angkanya masuk akal untuk data Anda
- [ ] H4. **Utang & Piutang**: tambah utang, bayar sebagian, lunasi; saldo/ringkasan benar
- [ ] H5. **Pengingat transaksi berulang** dan **agenda**: buat satu pengingat jatuh tempo 1-2 menit ke depan; notifikasi **berbunyi** tepat waktu (belum pernah diuji sampai berbunyi)
- [ ] H6. **Notifikasi anggaran**: lewati 80% anggaran satu kategori; notifikasi muncul

Catatan: ____________________________________________

## I. Berhenti berlangganan / Ultimate berakhir (opsional, butuh waktu)

Langganan uji berakhir cepat (bulanan ≈ 5 menit per periode, berhenti setelah beberapa kali perpanjangan).
- [ ] I1. Play Store > langganan Ultimate > **Batalkan**; tunggu sampai masa berlaku habis
- [ ] I2. Buka aplikasi: kembali ke Gratis, kartu "Upgrade ke Premium" muncul
- [ ] I3. **Buku Bisnis terkunci** (datanya tidak hilang, tidak bisa diubah); Buku Utama tetap normal
- [ ] I4. Transaksi berulang di buku terkunci **dijeda** (tidak membuat transaksi baru)
- [ ] I5. Berlangganan Ultimate lagi: buku Bisnis terbuka kembali dengan data utuh
- [ ] I6. Foto/riwayat tidak hilang setelah turun paket

Catatan: ____________________________________________

## J. Umum

- [ ] J1. Tidak ada crash atau layar merah/kuning selama seluruh pengujian
- [ ] J2. Kunci PIN dan sidik jari: aktifkan, tutup aplikasi, buka lagi: diminta kunci; matikan lagi bekerja
- [ ] J3. Rotasi layar / kembali dari aplikasi lain tidak membuat form Catat kehilangan isian
- [ ] J4. Kinerja: daftar transaksi dan dasbor tidak terasa lambat (terutama setelah banyak transaksi)
- [ ] J5. Hapus semua data (Pengaturan): menghapus buku tambahan, transaksi, foto struk; aplikasi kembali seperti baru (**lakukan paling akhir**)

Catatan: ____________________________________________

## Ringkasan hasil

| Bagian | Lulus | Gagal | Catatan singkat |
|---|---|---|---|
| A. Migrasi data | | | |
| B. Panduan dan tampilan | | | |
| C. Paket Gratis | | | |
| D. Beli Premium | | | |
| E. Upgrade ke Ultimate | | | |
| F. Scan struk (AI dan fallback) | | | |
| G. Multi buku kas | | | |
| H. Fitur Premium lain | | | |
| I. Ultimate berakhir | | | |
| J. Umum | | | |

**Syarat lanjut ke rilis produksi:** semua butir bagian A, E, F2, dan G lulus; tidak ada crash; tidak ada tagihan ganda.

## Bila ada yang gagal, kirim ke Claude
- Nomor butir, apa yang dilakukan, apa yang terjadi, dan screenshot atau pesan galat
- Untuk F2 (AI): perkiraan jam kejadian. Claude dapat memeriksa log Worker (`ai_usage` dan `ai_model_failed`) pada jam itu
- Untuk E (penggantian produk): screenshot halaman Play > Pembayaran & langganan
