# Rilis 1.2.0 (kode +16 DIGANTI +17, lalu +18), disusun 2026-10-29

> **Pembaruan 2026-10-29 (+19, belum diunggah):** AAB `1.2.0+19` dibangun dari commit `f9d173d`: 96.696.752 byte = 96,7 MB, SHA-256 diawali `fb5884211e4d44ae`, tanda tangan SHA-1 `86:E7:F6:…:A2:60` (sama dengan +18).
> Isi baru dibanding +18: sapaan "kamu" menggantikan "Anda" (67 string) dan persetujuan iklan Google UMP + tombol "Pilihan privasi iklan" di Pengaturan. 886 tes lulus; `flutter analyze` hanya 2 info lama di `database.dart`.
> Sebelum +19 tayang di Produksi: buat pesan persetujuan di AdMob (Privasi & pesan), lalu tempel `docs/kebijakan-privasi/DRAFT-iklan-ump.html` ke kebijakan privasi. Pengguna di Indonesia tidak akan melihat formulir (UMP menjawab "tidak diperlukan").

> **Pembaruan 2026-10-29 (malam): gunakan AAB `1.2.0+18`** (commit `1de0936`: 96.656.330 byte = 96,7 MB, SHA-256 diawali `4cac5fc21ea24140`, tanda tangan SHA-1 `86:E7:F6:…:A2:60`,
> manifest identik dengan +17). +18 memuat perbaikan kartu ringkasan Laba Rugi (label "HPP + beban" menyesatkan, ditemukan di uji Redmi) di atas perbaikan pemulihan backup lama (+17).
> **+16 dan +17 tidak boleh dipromosikan ke Produksi.** Rujukan "+16"/"+17" di bawah berlaku untuk **+18** kecuali disebut lain.
>
> **Pembaruan 2026-10-29 (sore):** uji Redmi menemukan bug pemulihan backup lama (< v9), diperbaiki di kode. **AAB +16 di jalur internal tidak boleh dipromosikan;
> gunakan AAB `1.2.0+17`** (dibangun dari commit `41cfe12`: 96.655.853 byte = 96,7 MB, SHA-256 diawali `23ac533497328321`, tanda tangan SHA-1 `86:E7:F6:…:A2:60` sama dengan +15/+16,
> manifest identik dengan +16). Nama berkas dokumen tetap "+16" agar tautan tidak putus; semua rujukan "+16" di bawah berlaku untuk **+17** kecuali disebut lain.

> **Belum dibangun dan belum dirilis.** Berisi Fase 1 pembukuan UMKM: Mode usaha, pengelompokan kategori, laporan Laba Rugi, dan ekspor
> PDF/Excel ([RENCANA-IMPLEMENTASI-UMKM.md](RENCANA-IMPLEMENTASI-UMKM.md)). Pengganti produksi **1.1.0+15**. Nomor versi `1.2.0+16`
> disetujui pemilik sebagai usulan (2026-10-29) tetapi **`pubspec.yaml` belum dinaikkan**: lihat langkah 0.
> Kode sudah di `main` (873 tes otomatis lulus); yang belum ada adalah uji di HP nyata dan pembuatan AAB.

## Artefak (dibangun 2026-10-29)
| Hal | Nilai |
|---|---|
| AAB | `build/app/outputs/bundle/release/app-release.aab` — **96.647.149 byte (96,6 MB; 92,2 MiB)**, SHA-256 diawali `4e2c135931b03990`. Pembanding +15 dibangun ulang dari commit `3fa6f29`: 91.622.387 byte (91,6 MB; 87,4 MiB, inilah angka "87,4 MB" di catatan +15, ternyata MiB). **Selisih +5,0 MB** pada AAB; sekitar 3,7 MB di antaranya simbol debug (`BUNDLE-METADATA`) yang tidak ikut terunduh pengguna. Per perangkat, kenaikan unduhan ≈ **0,75 MB** (`libapp.so` per ABI +0,75 MB karena kode Fase 1 dan paket `pdf`) + font tebal 44 KB terkompresi. Di bawah ambang 1 MB: cukup dicatat |
| Versi | `1.2.0` (kode versi **16**; produksi sekarang 15); `pubspec.yaml` sudah dinaikkan (commit `f09df91`) |
| Penandatangan | **terverifikasi sama dengan +15** (`keytool -printcert -jarfile`): `CN=DompetKu`, SHA-1 `86:E7:F6:D6:FD:67:0A:E4:D1:DC:AD:20:6E:01:30:F6:21:2E:A2:60`, berlaku sampai 7 Feb 2054 |
| Dibangun dari | `main` pada commit `f09df91` (`chore: versi 1.2.0+16`); pohon kerja bersih untuk berkas yang dilacak |
| Tes | 873 Flutter + 146 Worker lulus saat dokumen ini ditulis; `flutter analyze`: 2 info lama di `database.dart` |
| Skema database | **v12** (migrasi dari v1-v11 diuji otomatis; hanya menambah kolom, tidak menghapus apa pun) |
| Format backup | **v9** (backup dari 1.2.0 **tidak** bisa dipulihkan di +15 atau lebih lama; sebaliknya bisa) |
| Worker | Tidak ada perubahan; tidak perlu deploy |
| Izin / manifest | **Terverifikasi tidak berubah**: manifest dasar +15 dan +16 dibandingkan (nama izin, fitur perangkat, komponen); satu-satunya beda adalah `versionName` 1.1.0 → 1.2.0 (`versionCode` 16) |

## Isi (dibanding produksi +15)
- **Mode usaha** (Lainnya > Mode usaha, semua paket): menandai buku sebagai buku usaha. Di Ultimate juga ada saklar "Buku usaha" di dialog buku kas.
- **Pengelompokan kategori** (buku usaha): "Masuk ke laporan sebagai" pendapatan usaha, HPP, beban operasional, pendapatan lain, beban lain, atau di luar laba rugi,
  dengan saran otomatis dari nama kategori baru. Kategori sistem (Utang, Piutang, Tabungan, Penyesuaian Saldo) dan kategori usaha bawaan terisi otomatis lewat migrasi.
- **Laba Rugi** (Lainnya > Laba Rugi, **Premium**): berbasis kas; Bulan/3 Bulan/Tahun/Kustom; laba kotor, operasional, bersih, margin, pembanding periode
  sebelumnya, dan "Dari laba ke kas".
- **Ekspor Laba Rugi** (Premium): PDF A4 dan lembar "Laba Rugi" di Excel.
- Perbaikan kecil: nama buku pada ekspor Excel dibaca dari database (sebelumnya bisa jatuh ke "Buku Utama" bila provider belum terisi).
- Teknis: skema DB v12, backup v9, paket `pdf`, font statis `assets/fonts/pdf/PlusJakartaSans-Bold.ttf`.

## Catatan rilis Play (260 karakter, batas 500)
```
Baru: Mode usaha dan Laba Rugi (Premium). Kelompokkan kategori sebagai pendapatan, HPP, atau beban, lihat laba bersih per bulan, 3 bulan, atau tahun, lalu bagikan sebagai PDF atau Excel. Nyalakan Mode usaha di menu Lainnya. Perbaikan dan penyempurnaan lainnya.
```

## Risiko dan hal yang perlu diperhatikan
| Risiko | Penjelasan | Mitigasi |
|---|---|---|
| Migrasi database v11 → v12 | Menambah `categories.reportGroup` dan `ledgers.kind`, lalu mengisi kelompok kategori bawaan | Diuji otomatis dari semua versi lama; **uji dengan data nyata build 15** (L1) dan ekspor backup berkas sebelum memperbarui |
| **Pemulihan backup lama (< v9) memberi kelompok kosong** (ditemukan di uji Redmi 2026-10-29) | Utang/Piutang/Tabungan dan kategori usaha jatuh ke bawaan jenis; buku usaha kembali pribadi; Laba Rugi menyesatkan | **Diperbaiki di kode** (commit pasca +16, `BackupService.parse`); butuh build baru **+17**. Build +16 di jalur internal tidak boleh dipromosikan ke Produksi |
| Backup v9 tidak terbaca di versi lama | Pengguna yang kembali ke +15 atau lebih lama tidak bisa memulihkan backup baru | Jarang; cukup dicatat (sama seperti v8) |
| Laba Rugi menyesatkan bila kategori salah kelompok | Modal/cicilan/peralatan dianggap beban | Saran otomatis, penanda "otomatis", rekonsiliasi kas, penafian di layar dan PDF; pengguna yang memakai buku pribadi diajak menyalakan Mode usaha |
| Penjualan kredit baru terhitung saat uangnya diterima | Pendapatan tampak lebih kecil dari kenyataan | Dicatat di layar dan PDF; keputusan U8 di Fase 2 |
| PDF/Excel tampil lain di HP nyata | Font, tabel, atau lembar bagikan WhatsApp belum diuji | Daftar uji L7-L9 ([UJI-HP-LABA-RUGI.md](UJI-HP-LABA-RUGI.md)) |
| Ukuran aplikasi naik | Paket `pdf` + font tebal | Ukur AAB; cukup dicatat bila kenaikan < 1 MB |
| Kebijakan privasi berubah (menyebut PDF) | Teks bagian 7 sudah diubah di repo, belum di-deploy | Deploy sebelum rilis tayang (langkah 1) |
| Data Safety | Tidak ada perubahan deklarasi (lihat [DATA-SAFETY-PLAY.md](DATA-SAFETY-PLAY.md), 2026-10-29) | Cek ulang halaman Konten aplikasi saat mengirim rilis |

## Urutan rilis
0. [x] **Naikkan versi** (selesai 2026-10-29, AAB dibangun): `pubspec.yaml` ke `1.2.0+16`, commit `chore: versi 1.2.0+16 (Mode usaha, Laba Rugi)`. Bangun AAB rilis (tanpa `--dart-define` tambahan;
       alamat Worker AI sudah bawaan di kode). Jangan mencetak isi `android/key.properties`.
1. [x] **Kebijakan privasi (DEPLOYED 2026-10-29 14.52)**: deploy `docs/kebijakan-privasi/index.html` (bagian 7 menyebut PDF) ke `https://laciq.solusimandiri.id/privacy`. Tanggal berlaku:
       putuskan apakah perlu diperbarui (perubahan hanya penyebutan format ekspor). **Harus sebelum rilis tayang.**
       Dikerjakan: `scp` ke `dimas@10.9.0.208:/var/www/laciq.solusimandiri.id/privacy/index.html` (lewat VPN; cadangan berkas lama `index.html.bak-20261029`, diganti dengan `mv` agar atomik).
       Selisih dengan versi tayang sebelumnya hanya satu kalimat (bagian 7: "...laporan Excel (.xlsx), **laporan PDF**, dan backup file..."). Terverifikasi di
       `https://laciq.solusimandiri.id/privacy` (HTTP 200, kalimat baru ada; selisih lain dengan berkas asal hanya penyamaran email oleh Cloudflare). **Tanggal berlaku tidak diubah**
       (tetap 15 Oktober 2026; perubahan hanya memperjelas jenis berkas ekspor; ubah bila Anda ingin). Halaman lama `https://dompetku.hardan-ti.com/privacy` tidak diubah.
2. [x] **Uji internal**: AAB diunggah dan **diterbitkan ke jalur Pengujian internal pada 2026-10-29 13.43** (rilis "16 (1.2.0)", catatan rilis varian di atas; status "Tersedia untuk penguji internal").
       Pratinjau Play: tidak ada perangkat yang tidak lagi didukung; ukuran instal baru 21,6 MB (**+790 KB** vs +15), ukuran pembaruan 4,12 MB (sesuai perkiraan +0,75 MB).
       **Ekspor backup berkas dari build 15 sebelum memperbarui di Redmi.**
       **Diganti +17:** AAB `1.2.0+17` diterbitkan ke jalur internal pada **2026-10-29 14.50** (status "Tersedia untuk penguji internal"; ukuran instal 21,6 MB, pembaruan 4,14 MB,
       tidak ada perangkat yang hilang). +16 tidak boleh dipromosikan ke Produksi. Di Redmi: perbarui ke +17 tanpa menghapus aplikasi, lalu **pulihkan ulang backup lama** supaya kelompok kategori terisi.
       **Diganti +18:** AAB `1.2.0+18` diterbitkan ke jalur internal pada **2026-10-29 15.49** (status "Tersedia untuk penguji internal"; ukuran pembaruan 4,13 MB, tidak ada perangkat yang hilang). +16 dan +17 tidak boleh dipromosikan.
3. [ ] **Uji HP**: jalankan [UJI-HP-LABA-RUGI.md](UJI-HP-LABA-RUGI.md). Semua butir bertanda **WAJIB** harus lulus.
4. [~] **Listing (DIKIRIM UNTUK DITINJAU 2026-10-29)**: deskripsi lengkap baru dikirim (judul dan deskripsi singkat tidak diubah); teks di [LISTING-PLAY-STORE.md](LISTING-PLAY-STORE.md). Semula: samakan paragraf baru dengan listing yang tayang (lihat [LISTING-PLAY-STORE.md](LISTING-PLAY-STORE.md), 2026-10-29). Jangan mengubah judul (jendela 14 hari).
5. [x] **Produksi bertahap (TAYANG 50% sejak 2026-10-29 16.38; peninjauan Google selesai)**: konsol menampilkan "18 (1.2.0) Tersedia untuk 50% pengguna di Google Play", rilis 15 (1.1.0) tetap tersedia untuk sisanya, 33 peninstalan. Listing publik sudah memuat deskripsi baru (diverifikasi dari halaman publik). Berikutnya: pantau 24-48 jam lalu naikkan ke 100%. Dikirim 2026-10-29: rilis **18 (1.2.0)** dipromosikan dari Pengujian internal ke Produksi dengan **peluncuran bertahap 50%**
       (basis 33 instal aktif, sekitar 17 yang ditargetkan; bundel yang sama dengan uji internal). Di Ringkasan publikasi statusnya "Perubahan yang sedang ditinjau"
       (bersama perubahan listing, langkah 4). Pemilik mengirim; Google meninjau (beberapa jam sampai beberapa hari). Setelah tayang: pantau Android vitals,
       ulasan, RevenueCat 24-48 jam; naikkan ke 100% dari Produksi > Kelola rilis; jeda peluncuran bila ada masalah berat. Rencana awal yang tertulis di bawah (mulai 10%) diganti keputusan pemilik 50%.
       Semula: promosikan **bundel yang sama** dari uji internal, mulai 10% → 50% → 100% sambil memantau Android vitals, ulasan, dan RevenueCat.
6. [ ] Setelah tayang: perbarui dokumen ini dengan tanggal publikasi; perbarui status di [MATRIKS-FITUR-PAKET.md](MATRIKS-FITUR-PAKET.md) (🟡 → ✅ sesuai hasil uji).

## Dibawa ke rilis yang sama (keputusan U6, belum diputuskan)
Daftar dari [RENCANA-RILIS-BERIKUTNYA.md](RENCANA-RILIS-BERIKUTNYA.md) dan [RENCANA-GROWTH-30-HARI.md](RENCANA-GROWTH-30-HARI.md) yang belum dikerjakan:
pesan persetujuan iklan UMP (CMP), sapaan "kamu" di teks aplikasi (±58 tempat; teks baru di Fase 1 memakai "Anda" agar seragam), serta perubahan aktivasi
bila jadi build +16. Menggabungkan menghemat satu peninjauan Play; rilis sendiri lebih mudah dilacak dan dibatalkan. **Rekomendasi:** rilis Fase 1 sendiri,
UMP dan sapaan di +17.

## Rencana mundur
| Gejala | Tindakan |
|---|---|
| Crash atau regresi berat | Play Console > Produksi > **Jeda peluncuran**; siapkan perbaikan sebagai +17 |
| Migrasi database bermasalah pada sebagian perangkat | Jeda peluncuran, minta pengguna ekspor backup, siapkan +17; **jangan** mengubah nomor skema mundur |
| Laba Rugi menimbulkan keluhan salah hitung | Periksa dulu pengelompokan kategori pelapor (kolom "otomatis"); kesalahan murni di rumus akan tertangkap uji rekonsiliasi, jadi curigai data/pengelompokan |

## Yang masih terbuka
- Uji HP belum dilakukan (lihat [UJI-HP-LABA-RUGI.md](UJI-HP-LABA-RUGI.md)).
- Pratinjau angka terkunci untuk pengguna Gratis tidak dibuat (Gratis hanya ditawari upgrade dari menu).
- Fase 2 dan 3 ([RENCANA-IMPLEMENTASI-UMKM.md](RENCANA-IMPLEMENTASI-UMKM.md) §5-§6) belum dirinci; keputusan U1-U8 belum semuanya ditetapkan.
