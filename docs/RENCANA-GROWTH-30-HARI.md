# Rencana Growth 30 Hari LaciQ (28 Okt - 26 Nov 2026)

> Disusun 2026-10-28 dari data Play Console (28 hari, 27 Sep - 24 Okt) dan dokumen `PROMOSI-PEMASARAN.md`,
> `PAKET-KONTEN.md`, `PROYEKSI-FINANSIAL.md`, `RILIS-1.1.0+15.md`. Target adalah PERKIRAAN dari data awal yang kecil
> (beberapa angka bersampel 1-30), bukan janji. Revisi setelah tiap tinjauan mingguan. Klaim promosi tetap mengikuti
> aturan di `PAKET-KONTEN.md` bagian 7 (tanpa "akurat 100%", tanpa meminta bintang lima).

## 1. Titik awal (dari Play Console)
| Tahap | Angka | Catatan |
|---|---|---|
| Tayangan | 974 (921 penelusuran Play, 53 tautan luar) | Titik sempit utama |
| Pengunjung listing | 110 | |
| Klik pasang | 46 (rasio 42%; tabel listing 29,2%) | Konversi listing sudah sehat |
| Sumber 46 pemasangan | 19 penelusuran Play, 22 berbayar/langsung, 5 tak teridentifikasi | Promosi manual lebih efektif daripada penelusuran |
| Pertama kali dibuka | 27 dari 46 | 41% tidak pernah membuka |
| Pengguna aktif bulanan | 31 | |
| Rating | 4,90 dari 10 pengguna | |
| Pendapatan | $0,77, 0 pembeli | Jalur ke paywall belum terbuka |
| Retensi hari-7 | tidak terbaca (sampel 1 perangkat) | |

**Diagnosis:** masalahnya jumlah orang yang melihat aplikasi, bukan listing atau kualitas. Rencana ini menaikkan trafik
(ASO, situs, komunitas), memperbaiki aktivasi, dan membuka jalur konversi berbayar. Tidak ada belanja iklan.

## 2. Target 30 hari
| Metrik | Awal | Target 30 hari | Sumber |
|---|---|---|---|
| Pemasangan per bulan | 46 | 120-150 | Play Console > Statistik |
| Pengunjung listing per bulan | 110 | 300+ | Listingan Play Store |
| Pertama kali dibuka / pemasangan | 59% | >= 70% | Kembangkan basis pengguna |
| Ulasan | 10 | >= 25 | Rating dan ulasan |
| Komunitas yang dihubungi | ? | 5 (satu per minggu, mulai minggu 2) | Lembar catatan sendiri |
| Artikel/halaman SEO terbit | 0 | 2-3 | Situs |
| Uji coba Ultimate dinyalakan | belum | Ya, dengan pemantauan biaya | Worker, RevenueCat |

Target 90 hari (tinjau di akhir): 300-400 pemasangan per bulan, 150 pengguna aktif bulanan, konversi berbayar 1-2%.

## 3. Pilihan segmen
Segmen utama: **pelaku usaha kecil, freelancer, penjual online** (pesan: "pisahkan uang pribadi dan uang usaha";
paket Ultimate: multi buku kas, scan struk, Excel). Alasan: kemauan membayar lebih tinggi dan komunitasnya terkonsentrasi.
Segmen kedua (Reels, tanpa anggaran waktu khusus): karyawan 22-35 tahun ("gaji habis ke mana", tanpa akun).
Jangan bersaing di kata umum "catatan keuangan" saja; pesaing besar sudah menguasainya.

## 4. Rencana per minggu

### Minggu 1 (28 Okt - 3 Nov): ukur dan perbaiki fondasi
- [ ] Buka Play Console > Statistik/Listingan: catat **kata kunci pencarian** yang membawa tayangan (belum diperiksa) dan sebaran negara/perangkat.
- [ ] Rekap lembar pelacakan (spreadsheet): tanggal, kanal, tautan UTM, tayangan, klik, pemasangan. Isi dengan data 4 minggu terakhir.
- [ ] Kenali asal 22 pemasangan "berbayar/langsung": kanal mana yang sudah diposting (Instagram, WA, situs, QR)? Jawabannya menentukan kanal yang digandakan.
- [x] **Periksa status uji coba Ultimate** (SELESAI 2026-10-28: A4 lulus, `TRIAL_ENABLED = "1"` di produksi, penawaran trial teruji di HP nyata). Catatan awal: nilai `TRIAL_ENABLED` di Worker produksi. Bila masih `"0"`, selesaikan syarat di `RILIS-1.1.0+15.md` (uji A4 ANDROID_ID, 24-48 jam stabil di 100%) lalu nyalakan; pantau `promo-cost` dan konversi trial ke berbayar di RevenueCat.
- [x] **ASO v1** (TAYANG, terbaca 2026-10-28; jangan ubah judul/deskripsi singkat sampai 2026-11-11; lihat `ASO-DAN-MATERI-UMKM.md`): ubah judul dan deskripsi singkat ke kata yang dicari orang ("pencatat pengeluaran", "buku kas", "catat utang piutang", "anggaran"), pembeda tetap di kalimat pertama deskripsi lengkap. Pilih kata dari laporan pencarian, bukan tebakan. Catat tanggal perubahan untuk pembanding.
- [ ] Buat **listing kustom** untuk segmen UMKM (screenshot 1-3: buku kas, scan struk, Excel).
- [ ] Pantau selisih "dibuka vs dipasang": cek 3 layar pertama aplikasi dan waktu hingga transaksi pertama.

### Minggu 2 (4 - 10 Nov): distribusi manual dan situs
- [ ] Posting minimal 3 konten (Reels V3, V7, V2) dengan tautan UTM per kanal (format di `PAKET-KONTEN.md` bagian 0).
- [ ] **Komunitas #1**: satu grup UMKM/freelance/penjual online. Baca aturan, pakai teks "cari masukan jujur", balas semua komentar dalam 24 jam. Jangan kirim ke banyak grup sekaligus.
- [ ] Situs: halaman **template buku kas Excel UMKM** (unduhan gratis) dengan tombol Play Store dan UTM sendiri.
- [ ] Artikel #1 (judul = kata kunci): "Cara memisahkan uang pribadi dan uang usaha".
- [ ] Hubungi 5 pembuat konten literasi keuangan/UMKM skala kecil (1-20 ribu pengikut). Tawarkan akun Ultimate untuk dicoba. Tanpa syarat ulasan atau bintang.
- [ ] Tinjauan minggu 1-2 (Jumat): tayangan, klik, pemasangan per sumber.

### Minggu 3 (11 - 17 Nov): aktivasi dan retensi
- [ ] Keputusan build +16 (bila diperlukan): contoh data awal atau pengantar singkat, target transaksi pertama < 30 detik, pengingat catat harian (opt-in), kartu "Bagikan ringkasan bulan" tanpa data sensitif.
- [ ] Bila analitik tidak ditambahkan (menjaga citra privasi): survei satu pertanyaan di dalam aplikasi ("apa yang menghambatmu mencatat?") dan kumpulkan jawaban lewat email dukungan.
- [ ] Komunitas #2 dan #3 (satu per minggu bila minggu 2 menghasilkan).
- [ ] Artikel #2: "Cara mencatat utang dan piutang agar tidak lupa".
- [ ] Ajakan ulasan jujur kepada pengguna yang sudah memakai (lewat dialog ulasan dalam aplikasi, ambang 10 transaksi tetap). Jangan menjanjikan imbalan.
- [ ] Tinjauan minggu 3 (Jumat).

### Minggu 4 (18 - 24 Nov): gandakan yang berhasil
- [ ] Dari tinjauan: kanal dengan pemasangan terbanyak per jam kerja dilipatgandakan; kanal tanpa hasil setelah 2 minggu dihentikan.
- [ ] Komunitas #4 dan #5.
- [ ] Artikel #3 atau halaman template kedua (mis. utang piutang atau anggaran).
- [ ] ASO v2: sesuaikan kata kunci dan screenshot berdasarkan pengunjung baru.
- [ ] Tinjauan akhir: bandingkan tabel di bagian 2.

### 25 - 26 Nov: tinjauan 30 hari
- [ ] Isi bagian 6 dokumen ini. Putuskan 30 hari berikutnya.

## 5. Aturan keputusan
| Kondisi di tinjauan | Tindakan |
|---|---|
| Pemasangan >= 120 dan pengguna dibuka >= 70% | Tambah kanal; mulai uji harga/tahunan bila ada data trial |
| Pengunjung listing naik tetapi pemasangan tidak | Perbaiki screenshot dan deskripsi |
| Pemasangan tidak naik, pengunjung listing tetap | Trafik masih masalahnya: perkuat ASO dan situs, tambah komunitas |
| Pemasangan naik tetapi dibuka < 60% | Fokus aktivasi (onboarding, contoh data), bukan trafik |
| Retensi hari-7 < 10% setelah sampel >= 30 | Tinjau nilai harian aplikasi (pengingat, ringkasan) sebelum menambah trafik |
| Pelanggan berbayar masih 0 setelah trial hidup 2 minggu dan >= 100 pengguna aktif | Tinjau paywall, nilai Ultimate, dan harga |

Iklan berbayar: tunda. Perkiraan kasar (asumsi, bukan data): net sekitar Rp6.000 per pelanggan per bulan, bertahan 4 bulan,
konversi 2% menghasilkan nilai sekitar Rp500 per pemasangan, sementara biaya per pemasangan Android di Indonesia umumnya
lebih tinggi. Hitung ulang setelah konversi dan retensi nyata ada.

## 6. Hasil tinjauan (isi di akhir periode)
| Metrik | Target | Hasil |
|---|---|---|
| Pemasangan per bulan | 120-150 | |
| Pengunjung listing | 300+ | |
| Pertama kali dibuka / pemasangan | >= 70% | |
| Ulasan | >= 25 | |
| Pembeli berbayar | - | |
| Kanal terbaik | - | |
| Keputusan 30 hari berikutnya | - | |

## 7. Risiko
| Risiko | Mitigasi |
|---|---|
| Sampel kecil, angka bergelombang | Bandingkan mingguan, bukan harian; jangan menyimpulkan dari satu minggu |
| Trial menguras anggaran AI | Saklar `TRIAL_ENABLED`, anggaran global di Worker, pantau `promo-cost` |
| Ulasan dianggap dimanipulasi | Hanya minta masukan jujur; tanpa imbalan; balas semua ulasan |
| Waktu pengembang terbagi (fitur vs promosi) | Batasi build +16 ke perubahan aktivasi; promosi 3-4 jam per minggu tetap |
| Pesaing menguasai kata umum | Fokus ke kata spesifik UMKM dan buku kas |
