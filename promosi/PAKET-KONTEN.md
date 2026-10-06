# Paket Konten Promosi LaciQ (Instagram dan media lain)

> Dibuat 2026-10-07, setelah LaciQ build 14 tayang di Google Play. Melengkapi `docs/PROMOSI-PEMASARAN.md` (posisi,
> naskah video V1–V8, blog). Semua klaim mengikuti fitur yang sudah terbukti dan kebijakan privasi. Gambar dibuat ulang
> dengan `python promosi/build_slides.py` (hasil di `promosi/gambar/`).

## 0. Tautan yang dipakai
| Untuk | Tautan |
|---|---|
| Bio Instagram, kolom bio | `https://play.google.com/store/apps/details?id=com.hardanti.lacipintar&referrer=utm_source%3Dinstagram%26utm_medium%3Dbio%26utm_campaign%3Dpeluncuran` |
| Stiker tautan Story | sama, ganti `utm_medium%3Dstory` |
| WhatsApp / grup | sama, ganti `utm_source%3Dwhatsapp%26utm_medium%3Dchat` |
| Situs | `https://laciq.solusimandiri.id` |

Parameter `referrer` membuat Play Console > Statistik > Akuisisi pengguna menunjukkan sumber pemasangan. Instagram tidak
membuat tautan di caption bisa diklik, jadi tulis "link di bio".

## 1. Menyiapkan profil
- **Nama akun:** LaciQ. **Handle (cari yang kosong):** `@laciq.id`, `@laciq.app`, atau `@laciq.catat`. Samakan di semua media.
- **Foto profil:** `store-assets/ikon-512.png`.
- **Bio (maks. 150 karakter):**
  `Catatan keuangan tanpa akun. Data di HP-mu. 🎙️ Catat dengan suara · 🧾 Scan struk · 📊 Laporan bulanan` (+ tautan Play di kolom link)
- **Kategori profil:** Aplikasi / Produk atau Layanan. **Tombol kontak:** email `support@hardan-ti.com`.
- **Sorotan (Highlights) Story:** Mulai · Fitur · Privasi · Harga · Tanya Jawab.
- **Postingan tersemat (3):** posting peluncuran, karusel kenalan, karusel AI dan privasi.

## 2. Konten siap unggah

### 2.1 Posting peluncuran (1 gambar)
Gambar: `gambar/posting-peluncuran.png`.
```
LaciQ sudah tayang di Google Play 🎉

Aplikasi pencatat keuangan yang tidak minta kamu daftar akun. Pasang, langsung catat. Datamu tersimpan di HP-mu.

✅ Catat pemasukan, pengeluaran, dan transfer antar dompet
✅ Anggaran bulanan dan target tabungan
✅ Catat dengan suara dan laporan bulanan (Premium)
✅ Scan struk dan banyak buku kas untuk uang pribadi dan usaha (Ultimate)

Paket gratis sudah cukup untuk mulai (menampilkan iklan banner). Langganan bisa dibatalkan kapan saja lewat Google Play.

Cari "LaciQ: Catatan Keuangan" di Play Store, atau klik link di bio.

#laciq #catatankeuangan #aplikasikeuangan #kelolauang #financialplanning
```

### 2.2 Karusel "Kenalan dengan LaciQ" (7 slide)
Gambar urut: `gambar/karusel-kenalan-1.png` … `-7.png`. Slide 1 menentukan apakah orang menggeser.
```
Gaji tanggal 25, tanggal 10 sudah tipis? Itu biasanya bukan satu pengeluaran besar, tapi banyak yang kecil dan tak tercatat.

LaciQ membantu mencatat dengan cepat:
• Tanpa akun, tanpa login
• Ucapkan transaksinya, formulir terisi (Premium)
• Foto struk, terisi sendiri (Ultimate)
• Uang pribadi dan usaha dipisah (Ultimate)
• Laporan bulanan dengan sorotan otomatis (Premium)

Simpan postingan ini kalau mau coba. Link Google Play di bio. 📲

#catatankeuangan #kelolauang #gajian #tipsuang #pengeluaranbulanan #aplikasikeuangan
```

### 2.3 Karusel "AI dan privasi" (4 slide)
Gambar: `gambar/karusel-ai-privasi-1.png` … `-4.png`. Konten kepercayaan; cocok untuk hari ke-4 atau ke-5.
```
"Aplikasi keuangan pakai AI? Datanya dikirim ke mana?" Wajar kalau kamu bertanya.

Di LaciQ, ringkasan AI untuk Laporan Bulanan (paket Ultimate) hanya menerima:
✅ total pengeluaran dan pemasukan
✅ nama kategori

Tidak dikirim: catatan transaksi, nama toko, tanggal transaksi, dan foto struk.

Selalu ada dialog persetujuan lebih dulu. Menolak tidak mematikan fitur lain. Dan karena dibuat AI, ringkasannya bisa keliru: anggap sebagai gambaran, bukan nasihat keuangan. Ada tombol "Laporkan" kalau ada yang janggal.

#privasi #datapribadi #catatankeuangan #aplikasiandroid #laciq
```

### 2.4 Story (3 frame)
| Frame | Gambar | Stiker yang ditambahkan di Instagram |
|---|---|---|
| 1 | `gambar/story-1-peluncuran.png` | Stiker Hitung Mundur atau Emoji Slider |
| 2 | `gambar/story-2-suara.png` | Stiker Pertanyaan: "Biasanya kamu catat pengeluaran pakai apa?" |
| 3 | `gambar/story-3-ajakan.png` | Stiker Tautan ke Google Play (tautan story di bagian 0) |

Hindari menaruh teks penting di 250 px teratas dan 340 px terbawah (tertutup antarmuka Instagram).

### 2.5 Reels (rekam layar sendiri)
Pakai naskah V1, V2, V3, V5, V7, V8 di `docs/PROMOSI-PEMASARAN.md`. Urutan tayang yang disarankan: **V7 (suara)** karena paling
mudah dipahami dalam 3 detik, lalu V1, V2, V5. Tips rekam:
- Rekam layar HP dengan data contoh (jangan data pribadi). Warung Bu Sari dan Pribadi di akun uji aman dipakai.
- Teks besar di 3 detik pertama, durasi 20–35 detik, teks tetap terbaca tanpa suara.
- Akhiri dengan kartu "Cari LaciQ di Play Store".
- Cover Reels: ambil frame dari `gambar/story-2-suara.png` (potong tengah 1080×1350).

Hook alternatif (uji dua versi, pakai yang tontonannya lebih lama):
1. "Catat pengeluaran tanpa mengetik." (V7)
2. "Ternyata uang makan siangmu sebulan segini." (V1)
3. "Aplikasi keuangan yang tidak minta kamu daftar." (V5)
4. "Uang warung dan uang jajan tercampur? Pisahkan." (V3)

## 3. Kalender 14 hari
Jam tayang rekomendasi: 12.00 atau 19.00–21.00 WIB. Balas semua komentar dalam 24 jam.

| Hari | Feed | Story | Media lain |
|---|---|---|---|
| 1 | Posting peluncuran | Frame 1–3 | WhatsApp ke kontak pribadi, status WA, grup (bagian 4) |
| 2 | Reels V7 (suara) | Jajak "catat pakai apa?" | Threads/X: utas singkat |
| 3 | Karusel kenalan | Bagikan ulang karusel | Facebook (grup yang mengizinkan) |
| 4 | Reels V1 | Balas kotak pertanyaan | LinkedIn: cerita pengembang |
| 5 | Karusel AI dan privasi | Slide privasi | |
| 6 | — | Hasil jajak dan tips singkat | TikTok: V7 |
| 7 | Reels V2 (scan struk) | | Ringkasan minggu pertama untuk diri sendiri: pemasangan, sumber trafik |
| 8 | Posting tips: "3 cara membuat anggaran realistis" (tautan blog bila ada) | | |
| 9 | Reels V5 (privasi) | Q&A: ambil 3 pertanyaan terbanyak | |
| 10 | Karusel baru: Laporan Bulanan dan Excel (buat dari slide 6) | | Komunitas UMKM (bagian 4) |
| 11 | Reels V3 (pribadi vs usaha) | | |
| 12 | Posting testimoni nyata (hanya dengan izin tertulis pengguna) | | |
| 13 | Reels V8 | Sorotan diperbarui | |
| 14 | Ringkasan: "Dua minggu LaciQ" (tanpa angka palsu) | Ajakan masukan | Evaluasi (bagian 6) |

Setelah Hari 14, sisakan ritme 3 posting per minggu (satu karusel atau tips, dua Reels).

## 4. Media lain

### WhatsApp (pesan pribadi, jangan siaran massal)
```
Halo [nama], aku baru merilis aplikasi pencatat keuangan Android bernama LaciQ. Tidak perlu daftar akun, datanya di HP. Kalau mau coba dan kasih masukan jujur, ini linknya: [tautan WA]. Terima kasih ya! 🙏
```
Status WA: pakai `story-1-peluncuran.png`.

### Grup WhatsApp, Facebook, komunitas (UMKM, freelancer, finansial)
Baca aturan dulu. Jangan kirim ke banyak grup sekaligus. Tempel tautan hanya bila diizinkan.
```
Halo semua, saya developer lokal yang baru merilis LaciQ, aplikasi pencatat keuangan Android tanpa akun (data tersimpan di HP). Ada paket gratis. Saya cari masukan jujur dari yang mau mencoba beberapa hari: fitur apa yang kurang, bagian mana yang membingungkan. Kalau berminat, balas di sini atau cari "LaciQ: Catatan Keuangan" di Play Store.
```
Untuk grup UMKM, tambahkan satu kalimat: "Ada buku kas terpisah untuk uang pribadi dan usaha (paket Ultimate)."

### Threads / X (utas, 5 bagian)
1. "Saya merilis LaciQ, aplikasi pencatat keuangan Android tanpa akun. Ini alasan dan apa isinya. 🧵"
2. "Masalah: banyak aplikasi keuangan wajib daftar dulu. Padahal yang dibutuhkan cuma mencatat."
3. "Jadi LaciQ tidak punya login. Datamu di HP, backup-nya ke Google Drive-mu sendiri (Premium)."
4. "Fitur: catat dengan suara, scan struk, anggaran, laporan bulanan, ekspor Excel, buku kas pribadi dan usaha."
5. "Ada paket gratis. Cari 'LaciQ: Catatan Keuangan' di Play Store. Masukan sangat saya hargai."

### LinkedIn (cerita pengembang, tanpa nada iklan keras)
```
Beberapa bulan terakhir saya membangun LaciQ, aplikasi pencatat keuangan Android, dan minggu ini akhirnya tayang di Google Play.

Prinsip yang saya pegang: tanpa akun, data di HP, dan fitur AI hanya menerima angka yang perlu, selalu dengan persetujuan pengguna.

Pelajaran terbesar: meninjau satu per satu data yang dikumpulkan, sampai kebijakan privasi dan deklarasi Keamanan Data di Play cocok dengan perilaku aplikasi, memakan waktu lebih lama daripada menulis fiturnya, tapi paling penting.

Kalau kamu pengembang atau pelaku UMKM, saya senang mendengar masukanmu. Cari "LaciQ: Catatan Keuangan" di Play Store.
```

### TikTok
Pakai Reels yang sama tanpa watermark, caption pendek + 3–5 tagar (`#catatankeuangan #kelolauang #fyp` tidak wajib).

### Blog dan SEO
6 topik di `docs/PROMOSI-PEMASARAN.md` bagian 4. Terbitkan di `laciq.solusimandiri.id` bila nanti ada bagian blog.

## 5. Hashtag (pilih 8–12 per posting)
- **Inti:** #laciq #catatankeuangan #aplikasikeuangan #kelolauang #pengeluaranbulanan
- **Gaji dan tips:** #gajian #tipsuang #financialplanning #literasikeuangan #anggaranbulanan #menabung
- **UMKM dan freelance:** #umkm #pembukuansederhana #keuanganusaha #freelancerindonesia #bisnisonline
- **Fitur:** #catatdengansuara #scanstruk #laporankeuangan #excel
- **Privasi:** #privasi #datapribadi #aplikasiandroid

## 6. Balasan standar komentar dan DM
| Pertanyaan | Balasan |
|---|---|
| Ada untuk iPhone? | Saat ini baru Android. Kalau banyak yang minta iOS, kami pertimbangkan. |
| Gratis? | Ada paket gratis (mencatat, dompet, anggaran, target tabungan) dengan iklan banner. Premium mulai Rp7.500/bulan, Ultimate Rp12.500/bulan. Bisa dibatalkan kapan saja lewat Google Play. |
| Datanya aman? | Data tersimpan di HP-mu, bukan di server kami, dan tidak perlu akun. Backup (Premium) ke Google Drive-mu sendiri, terenkripsi. Rinciannya di laciq.solusimandiri.id/privacy. |
| Suara saya direkam? | Tidak oleh LaciQ. Suara diubah jadi teks oleh layanan pengenalan suara bawaan Android; yang dipakai hanya teksnya. Kalau HP tidak punya model suara offline, Android bisa memakai layanan Google sesuai pengaturan HP. |
| AI-nya baca semua catatan saya? | Tidak. Ringkasan AI hanya menerima total dan nama kategori, dan hanya setelah kamu setuju. Scan struk AI mengirim teks hasil scan, bukan fotonya. |
| Ganti HP, data hilang? | Pakai Backup Cloud (Premium) atau ekspor berkas cadangan. Tanpa backup, data hanya ada di HP lama. |
| Ada bug / saran | Terima kasih! Boleh kirim ke support@hardan-ti.com dengan versi aplikasi dan penjelasan singkat. |

## 7. Aturan klaim dan keamanan konten
- Jangan menjanjikan "hemat jutaan", "akurat 100%", atau "AI memberi saran keuangan". AI hanya merangkum angka dan bisa keliru.
- Jangan bilang "tidak ada data yang keluar dari HP" secara mutlak: Scan struk AI dan Ringkasan AI (Ultimate, dengan persetujuan) mengirim data terbatas, dan pembayaran lewat Google Play.
- Jangan meminta bintang lima atau menjanjikan hadiah untuk ulasan (melanggar kebijakan Play). Boleh meminta masukan jujur.
- Pakai badge resmi "Get it on Google Play" bila ingin menaruh tombol toko; gambar di sini memakai teks biasa sehingga tidak menyalahi pedoman merek Google.
- Screenshot untuk media sosial memuat data contoh. Gambar `suara`, `laporan`, `ringkasan-ai`, dan `excel` berasal dari HP pemilik
  dengan catatan yang sudah dikaburkan; cek ulang sebelum dipakai di luar situs. Jangan tampilkan nama, email, atau rekening nyata.
- Sebut paket gratis menampilkan iklan banner.
- Testimoni hanya dengan izin tertulis pengguna.

## 8. Ukuran keberhasilan (14 hari)
Catat di spreadsheet, bukan di kepala:
| Metrik | Cara lihat |
|---|---|
| Pemasangan per sumber | Play Console > Statistik > Akuisisi pengguna (filter `utm_source`) |
| Klik tautan bio | Instagram Insight > Aktivitas profil |
| Tontonan 3 detik dan retensi Reels | Instagram Insight per Reels |
| Simpan dan bagikan karusel | Insight per postingan (lebih bernilai daripada like) |
| Pertanyaan berulang | Kumpulkan, jadikan konten Q&A berikutnya |

Ganti hook atau visual bila tontonan 3 detik di bawah sekitar 30%. Evaluasi tiap Hari 7 dan Hari 14.
