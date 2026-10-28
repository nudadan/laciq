# ASO v1 dan Materi Segmen UMKM (disusun 2026-10-28)

> Lanjutan `RENCANA-GROWTH-30-HARI.md` (minggu 1-2). Semua klaim mengikuti `MATRIKS-FITUR-PAKET.md` dan aturan di
> `PAKET-KONTEN.md` bagian 7. Usulan teks Play Store di bawah BELUM dipasang; perlu persetujuan pemilik lalu diubah
> di Play Console > Listingan Play Store default. Tidak ada data volume pencarian di tangan saya, jadi pilihan kata
> kunci adalah hipotesis yang diuji lewat tayangan penelusuran di Play Console.

## 1. Temuan terbaru
**Listing yang tayang sekarang (dibaca dari halaman Play publik, 2026-10-28):**
- Judul: `LaciQ: Catatan Keuangan Harian` (30 karakter, sudah di batas).
- Deskripsi singkat: `Catat keuangan harian praktis tanpa login. Scan struk AI & laporan rapi.` (72). Berbeda dari draf di `LISTING-PLAY-STORE.md`; anggap versi Play yang benar.
- Deskripsi lengkap dibuka dengan keuangan pribadi. Multi buku kas (pembeda untuk UMKM) baru muncul di blok Ultimate, jauh di bawah.
- 10+ unduhan, 10 ulasan, rating 4,9. Pemilik sudah membalas semua ulasan.

**Hasil pencarian Play (Chrome pemilik, `gl=ID`; hasil bisa berbeda per akun dan waktu):**
| Kata dicari | Isi hasil | LaciQ |
|---|---|---|
| `catatan keuangan` | 14 hasil: aplikasi besar atau generik (Money Lover, Wallet, Pengelola Keuangan, Catatku, dompet digital) | Tidak muncul, walau kata itu ada di judul |
| `buku kas umkm` | 8 hasil, mayoritas pengembang kecil (Ogestudio, Aesthetic Labs, Rizuma Labs, My Buku Kas); BukuWarung 3,2 bintang | Tidak muncul |

Kesimpulan: kata umum "catatan keuangan" dikuasai aplikasi besar dan sulit dimasuki sekarang. Kata "buku kas / UMKM" diisi
pengembang kecil dan lebih mungkin ditembus. Ini mendukung pilihan segmen UMKM di rencana growth.

**Ulasan nyata menyebut:** "ga perlu login atau bikin akun", "simpel, praktis, dan ga ribet", "tahu uang habis ke mana".
Pesan "tanpa login + simpel" sudah diterima pengguna; pakai kata-kata itu di materi.

**Data Safety (kartu Play):** menampilkan "Lokasi" dan "Info keuangan". Sesuai `DATA-SAFETY-PLAY.md`: lokasi perkiraan dari
IP oleh AdMob, dan riwayat pembelian. Itu benar, jadi jangan menulis "tidak ada data yang keluar dari HP". Tulis
"catatan keuanganmu tersimpan di HP-mu".

## 2. Usulan ASO v1
Ubah SEKALI, catat tanggalnya, lalu jangan ubah 14 hari agar efeknya terbaca. Baseline 28 hari terakhir: 921 tayangan
penelusuran Play (sekitar 33 per hari), 19 pemasangan dari penelusuran Play.

| Elemen | Sekarang | Usulan | Panjang |
|---|---|---|---|
| Judul | LaciQ: Catatan Keuangan Harian | **LaciQ: Buku Kas & Catatan Uang** | 30 / 30 |
| Deskripsi singkat | Catat keuangan harian praktis tanpa login. Scan struk AI & laporan rapi. | **Buku kas usaha & pribadi terpisah. Tanpa login, data di HP. Scan struk AI.** | 74 / 80 |

Alternatif judul bila ingin menyebut segmen langsung: `LaciQ: Buku Kas UMKM & Pribadi` (30). Risiko: kata "UMKM"
bisa menjauhkan pencari uang pribadi. Pilihan pertama menjaga dua sisi.

Catatan: pindahkan "Catatan Keuangan" dari judul hanya setelah dicek di laporan kata kunci pencarian Play Console
(Statistik) bahwa kata itu memang tidak membawa tayangan. Bila ada tayangan darinya, pertahankan di deskripsi singkat.

**Pembuka deskripsi lengkap (usulan; sisanya tetap):**
```
LaciQ: buku kas untuk usaha kecil dan uang pribadi dalam satu aplikasi. Tanpa daftar akun, tanpa login. Catatan keuanganmu tersimpan di HP-mu sendiri.

• Pisahkan buku kas usaha dan pribadi, masing-masing dengan dompet, anggaran, dan laporan sendiri (sampai 5 buku, paket Ultimate)
• Catat pemasukan dan pengeluaran dalam beberapa ketukan, atau ucapkan lewat suara (Premium)
• Foto struk, nama toko, total, dan tanggal terisi (Ultimate; hasil tetap kamu cek sebelum disimpan)
• Catat utang dan piutang pelanggan atau teman (Premium)
• Laporan Bulanan otomatis dan ekspor Excel (.xlsx) (Premium)
```
Sapaan: deskripsi live memakai "Anda"; usulan ini memakai "kamu" seperti situs. Samakan seluruh deskripsi saat
mengubahnya (rilis berikutnya juga mengganti "Anda" di aplikasi; lihat `RENCANA-RILIS-BERIKUTNYA.md`).

**Screenshot:** urutan 3 pertama untuk UMKM: pengalih buku kas, scan struk AI, laporan Excel (berkas ada di
`store-assets/screenshots_ultimate/`). Buat sebagai listing kustom untuk pengunjung dari kampanye UMKM.

**Kata kunci uji (hipotesis, urut prioritas):** buku kas, buku kas umkm, pembukuan sederhana, catat utang piutang,
catat pengeluaran, catatan keuangan tanpa login, scan struk. Tuliskan secara wajar di deskripsi; jangan mengulang kata
berlebihan (melanggar kebijakan metadata Play).

## 3. Teks komunitas (pilih satu per minggu; baca aturan grup dulu, tempel tautan hanya bila diizinkan)

**A. Penjual online / reseller**
> Halo semua, saya developer lokal. Saya membuat LaciQ, aplikasi buku kas Android untuk memisahkan uang pribadi dan
> uang jualan, tanpa daftar akun (data di HP). Ada paket gratis. Saya cari 10 penjual online yang mau mencoba beberapa
> hari dan memberi masukan jujur: fitur apa yang kurang untuk catat modal, omzet, dan utang pelanggan? Cari
> "LaciQ: Buku Kas & Catatan Uang" di Play Store.

**B. Freelancer**
> Ada yang uang proyek dan uang pribadinya tercampur di satu rekening? Saya membuat LaciQ, aplikasi Android yang
> memisahkan buku kas pribadi dan kerja, bisa ekspor laporan ke Excel, tanpa akun. Cari masukan jujur dari freelancer:
> apa yang masih merepotkan saat mencatat pemasukan proyek?

**C. Warung / usaha rumahan**
> Catat belanja dan jualan tiap hari itu capek. LaciQ bisa foto struk belanja dan terisi sendiri (paket Ultimate),
> serta ada catatan utang piutang pelanggan (Premium). Data tersimpan di HP, tanpa daftar. Mau coba dan kasih
> masukan jujur?

Cara mencari komunitas: cari di Facebook/WhatsApp/Telegram dengan frasa `komunitas UMKM [kota]`, `reseller [produk]`,
`freelancer Indonesia`, `pelaku usaha rumahan`. Catat nama grup, jumlah anggota, aturan promosi, dan tanggal posting
di lembar pelacakan. Satu grup per minggu, balas semua komentar dalam 24 jam.

## 4. Naskah Reels segmen UMKM (20-30 detik; rekam layar dengan data contoh "Warung Bu Sari")
**U1 (Pribadi vs usaha, lanjutan V3)**
- 0-3 dtk: *"Uang jualan dan uang jajan nyampur? Pusing hitung untungnya."*
- 3-18 dtk: pengalih buku: Pribadi, lalu Warung; saldo dan laporan berbeda.
- 18-28 dtk: *"Satu aplikasi, sampai 5 buku kas. Tanpa daftar akun."*

**U2 (Struk belanja stok)**
- 0-3 dtk: *"Belanja stok, struknya numpuk dan nggak kecatat?"*
- 3-18 dtk: foto struk, tunjukkan layar sebelum/sesudah terisi.
- 18-28 dtk: *"Cek, simpan. Scan struk AI ada di paket Ultimate."* (jujur: tetap dicek)

**U3 (Utang pelanggan)**
- 0-3 dtk: *"Pelanggan ngutang, lupa berapa dan kapan?"*
- 3-18 dtk: catat piutang, lunas sebagian, lunas penuh.
- 18-28 dtk: *"Utang piutang tercatat rapi (Premium)."*

Tiap video diakhiri kartu "Cari: LaciQ: Buku Kas & Catatan Uang di Play Store" (nama persis seperti judul yang tayang
saat itu). Tautan bio memakai UTM per kanal (`PAKET-KONTEN.md` bagian 0).

## 5. Halaman template Excel di situs (SEO)
- **Judul halaman (kata kunci):** `Template Buku Kas UMKM Excel Gratis`. Alamat: `/template-buku-kas-umkm`.
- **Isi berkas .xlsx:** lembar Kas Masuk, Kas Keluar, Ringkasan Bulanan (rumus jumlah per bulan dan saldo), Utang Piutang.
  Buat sederhana dan benar-benar berguna tanpa aplikasi; jangan mewajibkan email.
- **Kerangka halaman:** masalah (uang pribadi dan usaha tercampur) → cara pakai template (3 langkah) → tombol unduh →
  satu paragraf "bila bosan mengetik di Excel, LaciQ bisa mengekspor laporan serupa dari HP" + tombol Play dengan UTM
  `utm_source=situs&utm_medium=template`. Tanpa janji hasil keuangan.
- Tambahkan ke `sitemap.xml` setelah tayang.

## 6. Pesan ke pembuat konten mikro (1.000 - 20.000 pengikut)
> Halo [nama], saya developer LaciQ, aplikasi buku kas Android tanpa akun yang datanya di HP. Kontenmu soal
> [topik] pas dengan pengguna yang saya tuju. Mau saya kirim akses Ultimate gratis untuk dicoba? Tidak ada kewajiban
> mengulas atau memposting; kalau kamu memutuskan membuat konten, tolong tandai sebagai kerja sama/akses gratis dan
> sampaikan pendapatmu sendiri, termasuk kekurangannya.

Akses diberikan lewat kode promo Play (Monetisasi > Kode promo). Jangan menjanjikan bintang lima atau tautan tertentu.

## 7. Yang dicatat minggu ini
| Hal | Sumber | Catatan |
|---|---|---|
| Tanggal dan isi perubahan listing | Lembar sendiri | Penanda sebelum/sesudah |
| Tayangan penelusuran dan pemasangan harian | Kembangkan basis pengguna | Bandingkan dengan baseline 33 tayangan/hari |
| Kata kunci pencarian pembawa tayangan | Play Console (Statistik; belum ditemukan di navigasi, cari di laporan akuisisi) | Dasar memilih kata |
| Posting, grup, balasan, klik tautan | Lembar pelacakan | UTM per kanal |
| Pertanyaan berulang dari komunitas | Catatan | Bahan artikel dan FAQ |

## 8. Keputusan menunggu pemilik
- [ ] Setuju judul `LaciQ: Buku Kas & Catatan Uang` dan deskripsi singkat usulan? (perlu diubah di Play Console)
- [ ] `TRIAL_ENABLED` di Worker produksi: hidup atau mati? Bila mati, kapan dinyalakan?
- [ ] Reels dan postingan mana yang sudah tayang sejak 7 Okt (untuk membaca asal 22 pemasangan langsung)?
