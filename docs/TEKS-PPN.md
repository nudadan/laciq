# Teks keterangan PPN (harga belum termasuk PPN 11%)

> Disusun 2026-10-09. Dasar: pesanan nyata pertama (Play Console > Pengelolaan pesanan, GPA.3304-9982-3764-47106, 8 Okt 2026):
> Ultimate bulanan, harga jual Rp12.500 + pajak Rp1.375 = **total Rp13.875**. Situs dan listing menulis Rp12.500, jadi pelanggan
> membayar lebih tinggi daripada angka yang mereka baca. Teks di bawah menutup selisih itu secara jujur dan konsisten.
> Bukan nasihat pajak atau hukum; tarif dan cara penampilan pajak ditentukan Google dan aturan yang berlaku.

## 0. Angka yang harus sama di mana-mana
| Paket | Harga jual (tanpa PPN) | PPN 11% | Total dibayar |
|---|---|---|---|
| Premium bulanan | Rp7.500 | Rp825 | **Rp8.325** |
| Premium tahunan | Rp75.000 | Rp8.250 | **Rp83.250** |
| Ultimate bulanan | Rp12.500 | Rp1.375 | **Rp13.875** |
| Ultimate tahunan | Rp125.000 | Rp13.750 | **Rp138.750** |

Setelah uji coba gratis 15 hari, tagihan pertama = total tahunan di atas (Premium Rp83.250, Ultimate Rp138.750).
Verifikasi: hanya Ultimate bulanan yang sudah terbukti dari pesanan nyata; empat angka lain dihitung dengan tarif yang sama (11%).
Cek di lembar bayar Play untuk tiap paket sebelum teks tayang.

## 1. Situs `laciq.solusimandiri.id`

### 1a. Catatan di bawah kartu paket (ganti kalimat pertama paragraf `.fine`)
```
Harga di atas belum termasuk PPN 11%, yang ditambahkan Google saat pembayaran. Contoh: Ultimate bulanan Rp12.500 + PPN Rp1.375 = Rp13.875. Harga bisa berbeda sesuai ketentuan Google Play. Langganan diperpanjang otomatis dan bisa dibatalkan kapan saja lewat Google Play. LaciQ hanya mencatat keuanganmu; aplikasi ini tidak memindahkan uang, tidak memberi pinjaman, dan bukan layanan penasihat keuangan.
```
(Menggantikan: "Harga dalam Rupiah dan bisa berbeda sesuai ketentuan Google Play. ...")

### 1b. Baris kecil di tiap kartu (`.price-sub`)
| Kartu | Mode bulanan | Mode tahunan |
|---|---|---|
| Premium | `+ PPN 11% (Rp8.325 total)` | `Setara Rp6.250/bulan + PPN 11% (Rp83.250 total)` |
| Ultimate | `+ PPN 11% (Rp13.875 total)` | `Setara Rp10.417/bulan + PPN 11% (Rp138.750 total)` |

Atribut `data-monthly` dan `data-yearly` pada `.price-sub` sudah ada di HTML; ubah isinya. Gratis tidak perlu PPN.

### 1c. Tanya jawab baru (tambah di FAQ, setelah "Apa bedanya Premium dan Ultimate?")
```
Pertanyaan: Kenapa harga di Google Play lebih tinggi dari harga di situs?
Jawaban: Harga di situs belum termasuk PPN 11%. Saat membayar, Google menambahkan PPN dan menampilkan total sebelum kamu konfirmasi. Contoh: Ultimate bulanan Rp12.500 + PPN Rp1.375 = Rp13.875. PPN dipungut dan disetor Google, bukan biaya tambahan dari LaciQ.
```

### 1d. Uji coba gratis (bila situs menyebutnya nanti)
```
Uji coba gratis 15 hari untuk paket tahunan (pelanggan baru). Setelah itu ditagih harga tahunan ditambah PPN 11%, kecuali kamu membatalkan sebelum masa uji coba berakhir.
```

## 2. Listing Google Play (deskripsi lengkap)
Tambahkan satu baris di bagian langganan (atau sebelum kalimat "Langganan dapat dibatalkan kapan saja lewat Google Play"):
```
Harga langganan belum termasuk PPN 11% yang ditambahkan Google saat pembayaran. Paket tahunan memiliki uji coba gratis 15 hari untuk pelanggan baru.
```
Sapaan di listing saat ini "Anda" (lihat `docs/RENCANA-RILIS-BERIKUTNYA.md`); samakan bila listing ikut diubah ke "kamu".
Catatan: perubahan listing memicu peninjauan; satukan dengan perubahan listing lain, jangan kirim sendirian.

## 3. Di dalam aplikasi (halaman Langganan, rilis v1.1)
Letakkan di bawah daftar baris harga pada `lib/features/subscription/subscription_page.dart` (teks kecil, `bodySmall`):
```
Harga belum termasuk PPN 11%. Total yang kamu bayar ditampilkan Google Play sebelum konfirmasi.
```
Bila trial aktif untuk akun itu (rencana v1.1 butir 2.1), ganti teks di bawah tombol tahunan:
```
Gratis 15 hari, lalu {harga tahunan} + PPN 11%. Perpanjang otomatis. Batalkan kapan saja di Google Play.
```
Jangan menulis angka total di kode; ambil harga dari RevenueCat dan tambahkan hanya keterangan "belum termasuk PPN 11%". Tampilan pajak di lembar Play
tetap yang mengikat. Saat ini aplikasi menampilkan harga jual (mis. "Rp 7.500 / bulan") dari `storeProduct.price`.

## 4. Promosi (Instagram dan lainnya)
Sudah diperbarui di `promosi/PAKET-KONTEN.md` (balasan "Gratis?"). Bentuk singkat yang boleh dipakai:
- Pendek: `Premium mulai Rp7.500/bulan (belum termasuk PPN 11%).`
- Dengan total: `Premium Rp7.500/bulan + PPN 11% = Rp8.325. Ultimate Rp12.500/bulan + PPN = Rp13.875.`
- Gambar: tambahkan tulisan kecil "Harga belum termasuk PPN 11%" bila harga muncul di gambar (kartu harga di `promosi/gambar` belum ada).
Jangan menulis "Rp7.500 total" atau "harga sudah termasuk pajak".

## 5. Balasan komentar dan DM
```
Harga Premium Rp7.500/bulan dan Ultimate Rp12.500/bulan belum termasuk PPN 11%. Google menambahkan PPN saat pembayaran, jadi totalnya Rp8.325 dan Rp13.875. Total persisnya selalu tampil di Google Play sebelum kamu konfirmasi, dan bisa dibatalkan kapan saja.
```

## 6. Keputusan yang masih terbuka (untuk pemilik)
1. **Pertahankan harga jual** Rp7.500/Rp12.500 dan jelaskan PPN (teks di atas), atau **ubah harga** agar totalnya bulat (mis. harga jual yang menghasilkan total Rp8.000 atau Rp14.000). Mengubah harga tidak memengaruhi pelanggan yang sudah berlangganan secara otomatis; Play memerlukan persetujuan pelanggan untuk kenaikan.
2. Periksa di Play Console > Monetisasi > Produk > Langganan > paket dasar > **Harga dan ketersediaan**: apakah Indonesia ditampilkan sebagai harga tanpa pajak, dan apakah ada opsi yang mengubahnya. Saya tidak dapat menyimpulkannya dari pesanan saja.
3. Konsultasikan dengan konsultan pajak soal pencatatan penghasilan: dasar PPh adalah harga jual, bukan total yang dibayar pelanggan (lihat `docs/PROYEKSI-FINANSIAL.md` bagian 3).
