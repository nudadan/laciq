# Draf Listingan Play Store — DompetKu

> Dibuat 2026-09-30. Draf teks untuk Play Console → Kembangkan basis pengguna → Kehadiran di Store → Listingan Play
> Store (bahasa: Indonesia – id). Isi disusun dari `docs/kebijakan-privasi/index.html` dan
> `docs/GAP-ANALISA-2026-09-24.md`; tidak ada klaim di luar fitur yang sudah tercatat selesai. Periksa ulang sebelum
> dipasang, terutama bagian fitur berbayar (harga dan Ultimate belum bisa dibeli sungguhan).

## Batas karakter Play Console
| Kolom | Batas | Draf |
|---|---|---|
| Nama aplikasi | 30 | 26 |
| Deskripsi singkat | 80 | 72 |
| Deskripsi lengkap | 4.000 | ± 1.900 |

## Nama aplikasi (26 karakter)
```
DompetKu: Catatan Keuangan
```

## Deskripsi singkat (72 karakter)
```
Catat pemasukan & pengeluaran, atur anggaran. Data tersimpan di HP Anda.
```

## Deskripsi lengkap
```
DompetKu membantu Anda mencatat dan memahami keuangan pribadi dengan cepat, tanpa perlu membuat akun. Data keuangan Anda disimpan di HP Anda sendiri.

CATAT DENGAN CEPAT
• Catat pemasukan, pengeluaran, dan transfer antar dompet dalam beberapa ketukan
• Banyak dompet: tunai, rekening bank, e-wallet
• Kategori dan tag yang bisa Anda atur sendiri
• Transaksi berulang untuk gaji, cicilan, dan langganan

PAHAMI ARUS UANG ANDA
• Dasbor saldo total, arus kas bulan ini, dan grafik per kategori
• Anggaran bulanan per kategori dengan pengingat saat mendekati batas
• Target tabungan untuk tujuan yang ingin Anda capai
• Ekspor data ke CSV

PRIVASI DAN KEAMANAN
• Tidak perlu daftar atau login
• Kunci aplikasi dengan PIN atau sidik jari
• Data keuangan tersimpan di perangkat Anda dan tidak kami simpan di server. Satu-satunya pengecualian: bila Anda memakai Scan struk dengan AI (Ultimate) dan menyetujuinya, teks struk dikirim untuk diproses dan tidak disimpan
• Hapus semua data kapan saja dari menu Pengaturan

FITUR PREMIUM (BERLANGGANAN)
• Bebas iklan
• Backup Cloud ke Google Drive Anda sendiri, terenkripsi
• Analisa Tren pengeluaran per kategori untuk 6 dan 12 bulan
• Pengingat transaksi berulang dan agenda (servis kendaraan, tagihan tahunan, dan lainnya)
• Proyeksi pengeluaran bulan ini dan simulasi apakah dana cukup sampai akhir bulan
• Catatan utang dan piutang
• Scan struk: foto struk dibaca langsung di HP Anda

FITUR ULTIMATE (BERLANGGANAN)
• Semua fitur Premium
• Multi buku kas: pisahkan pembukuan pribadi dan bisnis, masing-masing dengan dompet, kategori, anggaran, dan laporan sendiri (sampai 5 buku)
• Scan struk dengan AI: nama toko, kategori, total, dan tanggal terisi otomatis (300 scan per bulan). Hanya teks hasil scan, bukan foto, yang dikirim ke server AI kami untuk diproses, dan tidak disimpan

Paket gratis menampilkan iklan banner dan sudah mencakup pencatatan, dompet, anggaran, target tabungan, serta sebagian fitur Agenda dan Analisa Tren. Langganan dapat dibatalkan kapan saja lewat Google Play.

DompetKu mencatat keuangan Anda; aplikasi ini tidak memindahkan uang, tidak memberi pinjaman, dan bukan layanan penasihat keuangan.

Kebijakan privasi: https://dompetku.hardan-ti.com/privacy
Bantuan: support@hardan-ti.com
```

## Ultimate sudah masuk ke deskripsi di atas (diperbarui 2026-10-01)
Blok "FITUR ULTIMATE" dan kalimat privasi yang sudah dilunakkan sudah menyatu di deskripsi lengkap. **Pasang ke
Play Console bersamaan dengan rilis 4** (versi aplikasi yang memuat Ultimate), bukan sebelumnya, supaya listing
tidak menjanjikan fitur yang belum ada di versi yang beredar. Produk Ultimate di Play sudah aktif (2026-09-30).

## Aset yang harus disediakan (belum ada di repo)
| Aset | Ukuran | Catatan |
|---|---|---|
| Ikon aplikasi | 512×512 PNG, maks. 1 MB | Gunakan ikon yang sama dengan di APK |
| Feature graphic | 1024×500 PNG/JPG | Wajib |
| Screenshot HP | min. 2, rasio 16:9 atau 9:16 | Disarankan 4–8: Dasbor, Tambah transaksi, Anggaran, Analisa Tren, Proyeksi |
| Screenshot tablet | Opsional | Hanya jika ingin tampil untuk tablet |

## Catatan untuk pemilik
- Setelah ini beres, baru bisa klik **Kirim aplikasi untuk ditinjau** di Ringkasan publikasi.
- 2026-10-01: deskripsi lengkap versi Ultimate (2.254 karakter) sudah DISIMPAN sebagai draf di Play Console (belum dikirim; ikut tinjauan bersama rilis). Aset: ikon, gambar fitur, 7 screenshot ponsel dan tablet sudah ada (belum ada screenshot khusus fitur Ultimate; opsional).
- Bagian Ultimate kini sudah ada di deskripsi (produk Ultimate aktif di Play dan Worker AI di-deploy 2026-10-01),
  tetapi pasang bersama rilis 4. Jawaban Data Safety ada di `docs/DATA-SAFETY-PLAY.md`.
- Detail kontak (support@hardan-ti.com, https://dompetku.hardan-ti.com) sudah dipublikasikan 2026-09-30; kategori
  aplikasi = Keuangan (tersimpan sebagai perubahan draf).
- "Scan struk" ditulis di bawah Premium sesuai GAP-ANALISA (fitur Premium); akurasi parser struk kompleks tercatat
  masih kurang, jadi tidak diklaim sebagai "otomatis akurat".
- 2026-10-01/02: **Akses aplikasi untuk peninjau Play** — Detail login diisi "No login" + petunjuk Inggris, kotak "akses
  penuh" dicentang. Peninjau membuka Ultimate lewat kode promo kustom **DKUULTIMATE2026** (Monetisasi > Kode promo,
  langganan `dompetku_ultimate`, uji coba 30 hari, 2.000 penukaran, berlaku 2 Okt 2026 - 31 Mar 2027; "DOMPETKUREVIEW"
  ditolak Play karena kata terlarang). Jangan hapus/jeda kode selama peninjauan. Pembaruan publikasi (10 perubahan,
  rilis produksi 6) dikirim untuk ditinjau pada 2026-10-02.
- 2026-10-02: **Screenshot Ultimate dipasang** di Listingan Play Store (draf, belum dikirim; batas 8 ponsel). Urutan:
  08 buku kas, 09 scan struk AI, Ringkasan, Anggaran, Proyeksi, 10 ringkasan per buku, Transaksi, 11 grafik. Dilepas:
  Dompet, Lainnya, Catat transaksi (berkas asli di `store-assets/screenshots/`). Berkas baru:
  `store-assets/screenshots_ultimate/` (1220x2300, dengan caption); mentahnya di `store-assets/_raw/ultimate/`.
  Struk di gambar 09 adalah gambar buatan ("Toko Grosir Makmur"), bukan struk nyata. Kirim lewat Ringkasan publikasi
  setelah peninjauan pertama selesai.
