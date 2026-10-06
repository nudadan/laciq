# Materi Promosi LaciQ

> Dibuat 2026-10-02 (sebagai DompetKu), diperbarui 2026-10-07 setelah LaciQ build 14 tayang di Play. Tautan toko:
> https://play.google.com/store/apps/details?id=com.hardanti.lacipintar . Situs: https://laciq.solusimandiri.id .
> Semua klaim di sini mengikuti fitur yang sudah terbukti
> (lihat `docs/MATRIKS-FITUR-PAKET.md`) dan teks listing (`docs/LISTING-PLAY-STORE.md`). Jangan menjanjikan hal di
> luar itu: tidak ada klaim "akurat 100%", "hemat jutaan", atau "AI memberi saran keuangan".

## 1. Posisi dan pesan inti
**Kalimat posisi:** *Catatan keuangan yang tidak minta akun dan tidak menyimpan datamu di server.*

| Pembeda | Cara menyebutnya | Bukti di aplikasi |
|---|---|---|
| Tanpa akun | "Install, langsung catat. Tanpa daftar, tanpa login." | Tidak ada layar login |
| Data di HP | "Datamu tinggal di HP-mu, bukan di server kami." | Kebijakan privasi bagian 1 |
| Scan struk AI (Ultimate) | "Foto struk, nama toko, kategori, total, dan tanggal terisi sendiri." | Terbukti di perangkat nyata |
| Multi buku kas (Ultimate) | "Pisahkan uang pribadi dan uang usaha dalam satu aplikasi." | Sampai 5 buku, G1–G12 lulus |
| Backup Cloud (Premium) | "Cadangan terenkripsi ke Google Drive-mu sendiri." | Terbukti di build Play |
| Catat dengan suara (Premium) | "Ucapkan 'makan siang dua puluh lima ribu', formulir terisi." | Lulus uji di tablet dan Redmi; suara diubah jadi teks oleh layanan bawaan Android, LaciQ tidak merekam |
| Laporan Bulanan (Premium) | "Sorotan otomatis: apa yang berubah bulan ini." | Dihitung di HP, lulus uji data nyata |
| Ekspor Excel (Premium) | "Laporan .xlsx rapi, siap dibuka di Excel." | Lima lembar, lulus uji di perangkat; CSV tetap gratis |
| Ringkasan AI (Ultimate) | "Rangkuman bulan dalam beberapa kalimat." | Hanya angka total dan nama kategori dikirim; bisa keliru, bukan nasihat keuangan |

**Sasaran pertama (urut prioritas):**
1. Pekerja/karyawan 22–35 tahun yang ingin tahu uang gajinya habis ke mana.
2. Freelancer dan pemilik usaha kecil (warung, toko online, jasa) yang uang pribadi dan usahanya tercampur → paket Ultimate.
3. Orang yang kapok aplikasi keuangan karena wajib daftar dan takut datanya dipakai.

**Tagline (pilih satu, uji lainnya di eksperimen listing):**
- "Catat uang tanpa daftar akun."
- "Datamu tetap di HP-mu."
- "Foto struk, selesai tercatat."
- "Uang pribadi dan usaha, tidak lagi tercampur."
- "Ucapkan, tercatat."

## 2. Screenshot Ultimate untuk listing Play
Screenshot Ultimate sudah terpasang di listing. Bagian ini tinggal rujukan bila perlu membuat ulang atau menambah
gambar fitur baru (suara, Laporan Bulanan; ada di `store-assets/screenshots_ultimate/` dan situs). Tiga gambar
pertama paling menentukan konversi:

| # | Layar | Teks di atas gambar (maks. 6 kata) | Kondisi data yang diperlukan |
|---|---|---|---|
| U1 | Pengalih buku kas terbuka (Pribadi / Warung Bu Sari / Freelance) | Pisahkan uang pribadi dan usaha | 3 buku kas dengan nama wajar |
| U2 | Form transaksi setelah Scan struk AI: toko, total, tanggal, kategori terisi | Foto struk, langsung terisi | Struk Indomaret/Alfamart contoh, nominal wajar |
| U3 | Ringkasan buku "Warung" dengan grafik dan saldo terpisah dari "Pribadi" | Laporan terpisah tiap buku | Transaksi 1 bulan di buku Warung |
| U4 (opsional) | Layar langganan Premium vs Ultimate | Pilih paket yang pas | Tidak perlu data |

Aturan teknis Play: rasio 9:16, minimal 320 px dan maksimal 3.840 px per sisi, PNG/JPG, maksimal 8 MB, 2–8 gambar.
Jangan menampilkan data pribadi nyata (nama, email, nomor rekening) di screenshot.

## 3. Naskah video pendek (TikTok, Reels, Shorts), 20–35 detik
Format: layar HP direkam (tanpa wajah juga boleh), teks besar di layar, suara pembaca atau musik. Akhiri dengan
"Cari LaciQ di Play Store".

**V1 — Hook "gaji habis ke mana"**
- 0–3 dtk (teks): *"Gaji tanggal 25, tanggal 10 sudah tipis. Ke mana?"*
- 3–15 dtk: buka Ringkasan, tunjuk grafik pengeluaran per kategori. *"Catat sebentar tiap hari, akhir bulan kelihatan bocornya di mana."*
- 15–25 dtk: tambah transaksi dalam beberapa ketukan.
- 25–30 dtk: *"Tanpa daftar akun. Data tetap di HP-mu."*

**V2 — Scan struk (Ultimate)**
- 0–3 dtk: *"Males ngetik belanjaan satu-satu?"*
- 3–18 dtk: foto struk minimarket → nama toko, total, tanggal, kategori terisi. Tunjukkan layar sebelum dan sesudah.
- 18–25 dtk: *"Tinggal cek dan simpan."* (jujur: tetap dicek sebelum disimpan)
- 25–30 dtk: *"Scan struk AI ada di paket Ultimate."*

**V3 — Pribadi vs usaha (Ultimate)**
- 0–3 dtk: *"Uang warung dan uang jajan tercampur? Capek hitungnya."*
- 3–20 dtk: pengalih buku → buku Pribadi, lalu buku Warung; tunjukkan saldo masing-masing berbeda.
- 20–30 dtk: *"Satu aplikasi, sampai 5 buku kas terpisah."*

**V4 — Anggaran dan notifikasi**
- 0–3 dtk: *"Anggaran makan Rp1,5 juta. Baru tanggal 12, sudah 80%?"*
- 3–18 dtk: buat anggaran, tunjukkan peringatan saat mendekati batas.
- 18–28 dtk: *"Diingatkan sebelum jebol, bukan sesudahnya."*

**V5 — Privasi**
- 0–3 dtk: *"Aplikasi keuangan yang tidak minta kamu daftar."*
- 3–20 dtk: buka aplikasi pertama kali, langsung catat. Teks: *"Tanpa email. Tanpa nomor HP. Tanpa login."*
- 20–30 dtk: *"Datamu tersimpan di HP. Backup-nya ke Google Drive-mu sendiri (Premium)."*

**V6 — Utang piutang**
- 0–3 dtk: *"Teman pinjam Rp200 ribu, lupa kapan dan berapa?"*
- 3–18 dtk: catat piutang, lunas sebagian, lunas penuh.
- 18–25 dtk: *"Utang dan piutang tercatat rapi (Premium)."*

**V7 — Catat dengan suara (Premium)**
- 0–3 dtk: *"Lagi bawa belanjaan, tangan penuh. Mau nyatat gimana?"*
- 3–18 dtk: buka formulir, ketuk mikrofon, ucapkan "makan siang dua puluh lima ribu". Tunjukkan nominal dan kategori terisi.
- 18–26 dtk: *"Cek dulu, lalu simpan."* (jujur: formulir tetap diperiksa)
- 26–32 dtk: *"Catat dengan suara ada di paket Premium."*

**V8 — Laporan Bulanan dan Excel**
- 0–3 dtk: *"Akhir bulan, bingung uangnya ke mana?"*
- 3–18 dtk: buka Laporan Bulanan, tunjuk sorotan (anggaran terlampaui, perbandingan bulan lalu).
- 18–28 dtk: ekspor ke Excel, buka berkasnya. *"Satu berkas rapi, tinggal dibuka."*
- 28–33 dtk: *"Laporan Bulanan dan Excel ada di Premium."*

### Caption dan tagar (salin-tempel)
- Caption V1: `Gaji habis sebelum tanggal tua? Coba catat 1 menit sehari. LaciQ, tanpa daftar akun. Cari di Play Store. #catatankeuangan #kelolauang #financialplanning #tipsuang #gajian`
- Caption V2: `Foto struk, nama toko, total, dan tanggal terisi otomatis. Cek, simpan, selesai. (Paket Ultimate) #scanstruk #catatankeuangan #aplikasikeuangan #umkm`
- Caption V3: `Uang pribadi dan uang usaha jangan dicampur. Satu aplikasi, banyak buku kas. #umkm #pembukuansederhana #keuanganusaha #freelancer`
- Caption V7: `Ucapkan transaksinya, formulir terisi sendiri. Tetap kamu cek sebelum disimpan. (Paket Premium) #catatdengansuara #catatankeuangan #aplikasikeuangan`
- Caption V8: `Sorotan otomatis tiap bulan plus laporan Excel yang rapi. (Paket Premium) #laporankeuangan #excel #catatankeuangan`
- Caption V5: `Aplikasi pencatat keuangan tanpa akun, tanpa login. Data di HP-mu. #privasi #catatankeuangan #aplikasiandroid`

Jadwal rekomendasi: 3 video per minggu selama 4 minggu, jam 12.00 atau 19.00–21.00. Satu video ulang tayang dengan hook
berbeda bila tayang awalnya bagus.

## 4. Artikel blog untuk laciq.solusimandiri.id (SEO)
Satu artikel per topik, 600–900 kata, akhiri dengan tombol Play Store. Judul = kata kunci utama.

1. **Cara mencatat pengeluaran bulanan dengan mudah** (kata kunci: cara mencatat pengeluaran bulanan)
2. **Metode 50/30/20: cara membagi gaji bulanan** (metode 50/30/20)
3. **Cara memisahkan uang pribadi dan uang usaha** (pisahkan keuangan pribadi dan usaha)
4. **Cara mencatat utang dan piutang agar tidak lupa** (catat utang piutang)
5. **Cara membuat anggaran bulanan yang realistis** (anggaran bulanan)
6. **Aplikasi catatan keuangan tanpa login: apa untungnya?** (aplikasi keuangan tanpa akun)

Kerangka tiap artikel: masalah umum → langkah praktis → contoh angka sederhana → "cara melakukannya di LaciQ" (1
paragraf, bukan iklan keras) → ajakan. Wajib: tanpa saran investasi atau jaminan hasil.

## 5. Teks posting komunitas (jangan tempel tautan di pesan pertama bila grup melarang)
> Halo, saya developer lokal yang baru merilis LaciQ (sebelumnya DompetKu), aplikasi pencatat keuangan Android yang tidak meminta akun dan
> menyimpan data di HP. Saya cari 20 orang yang mau mencoba 2 minggu dan memberi masukan jujur. Kalau berminat, balas di
> sini atau cek Play Store: "LaciQ: Catatan Keuangan", atau buka laciq.solusimandiri.id.

Aturan: baca aturan grup dulu, jangan kirim ke banyak grup sekaligus, balas semua komentar, jangan minta bintang lima
(hanya minta masukan; kebijakan Play melarang ulasan berinsentif).

## 6. Hari rilis (checklist)
- [x] Play menyetujui dan menayangkan build 14 (2026-10-07).
- [ ] Unduh dari tautan Play publik dan cek SHA-1 APK produksi (Backup Cloud), langganan, dan suara.
- [ ] Umumkan ke kontak pribadi dan komunitas (teks bagian 5, tempel tautan Play hanya bila grup mengizinkan).
- [ ] Unggah V1 dan V2.
- [ ] Pantau Play Console > Statistik dan ulasan harian; balas ulasan dalam 24 jam.
- [ ] Catat sumber trafik (Play Console > Statistik > Akuisisi pengguna).

## 7. Ukuran keberhasilan 30 hari pertama
| Metrik | Target awal | Sumber |
|---|---|---|
| Pemasangan | 100–300 | Play Console |
| Rating | ≥ 4,3 dengan ≥ 10 ulasan | Play Console |
| Retensi hari-7 | ≥ 15% | Play Console |
| Pelanggan berbayar | 1–3% dari pemasangan aktif | RevenueCat |

Angka ini perkiraan konservatif untuk aplikasi baru tanpa iklan berbayar, bukan janji. Sesuaikan setelah data pertama.
