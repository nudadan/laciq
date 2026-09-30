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
• Data keuangan tersimpan di perangkat Anda; kami tidak punya server yang menampungnya
• Hapus semua data kapan saja dari menu Pengaturan

FITUR PREMIUM (BERLANGGANAN)
• Bebas iklan
• Backup Cloud ke Google Drive Anda sendiri, terenkripsi
• Analisa Tren pengeluaran per kategori untuk 6 dan 12 bulan
• Pengingat transaksi berulang dan agenda (servis kendaraan, tagihan tahunan, dan lainnya)
• Proyeksi pengeluaran bulan ini dan simulasi apakah dana cukup sampai akhir bulan
• Catatan utang dan piutang
• Scan struk: foto struk dibaca langsung di HP Anda

Paket gratis menampilkan iklan banner dan sudah mencakup pencatatan, dompet, anggaran, target tabungan, serta sebagian fitur Agenda dan Analisa Tren. Langganan dapat dibatalkan kapan saja lewat Google Play.

DompetKu mencatat keuangan Anda; aplikasi ini tidak memindahkan uang, tidak memberi pinjaman, dan bukan layanan penasihat keuangan.

Kebijakan privasi: https://dompetku.hardan-ti.com/privacy
Bantuan: support@hardan-ti.com
```

## Tambahan deskripsi saat Ultimate dirilis (JANGAN dipasang sebelum produk Ultimate bisa dibeli)
Sisipkan setelah blok "FITUR PREMIUM"; total deskripsi tetap jauh di bawah 4.000 karakter. Sesuaikan kalimat
Scan struk di Premium agar tidak tumpang tindih (Premium = dibaca di HP; Ultimate = dilengkapi AI).
```
FITUR ULTIMATE (BERLANGGANAN)
• Semua fitur Premium
• Multi buku kas: pisahkan pembukuan pribadi dan bisnis, masing-masing dengan dompet, kategori, anggaran, dan laporan sendiri (sampai 5 buku)
• Scan struk dengan AI: nama toko, kategori, total, dan tanggal terisi otomatis. Teks hasil scan (bukan foto) dikirim ke server AI kami untuk diproses dan tidak disimpan
```
Kalimat "kami tidak punya server yang menampungnya" di bagian Privasi juga perlu dilunakkan saat Ultimate rilis
(mis. "Data keuangan tersimpan di perangkat Anda; hanya teks struk yang dikirim ke server AI bila Anda memakai
fitur Ultimate dan menyetujuinya").

## Aset yang harus disediakan (belum ada di repo)
| Aset | Ukuran | Catatan |
|---|---|---|
| Ikon aplikasi | 512×512 PNG, maks. 1 MB | Gunakan ikon yang sama dengan di APK |
| Feature graphic | 1024×500 PNG/JPG | Wajib |
| Screenshot HP | min. 2, rasio 16:9 atau 9:16 | Disarankan 4–8: Dasbor, Tambah transaksi, Anggaran, Analisa Tren, Proyeksi |
| Screenshot tablet | Opsional | Hanya jika ingin tampil untuk tablet |

## Catatan untuk pemilik
- Setelah ini beres, baru bisa klik **Kirim aplikasi untuk ditinjau** di Ringkasan publikasi.
- Bagian Ultimate (ekstraksi struk AI) sengaja dihapus dari deskripsi karena produknya belum dibuat di Play Console
  dan Worker AI belum di-deploy. Tambahkan lagi saat tier Ultimate sudah bisa dibeli, sekalian revisi bagian
  "Scan struk" agar tidak tumpang tindih.
- Detail kontak (support@hardan-ti.com, https://dompetku.hardan-ti.com) sudah dipublikasikan 2026-09-30; kategori
  aplikasi = Keuangan (tersimpan sebagai perubahan draf).
- "Scan struk" ditulis di bawah Premium sesuai GAP-ANALISA (fitur Premium); akurasi parser struk kompleks tercatat
  masih kurang, jadi tidak diklaim sebagai "otomatis akurat".
