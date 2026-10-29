# Rilis 1.2.0+16 (RANCANGAN, disusun 2026-10-29)

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
1. [ ] **Kebijakan privasi**: deploy `docs/kebijakan-privasi/index.html` (bagian 7 menyebut PDF) ke `https://laciq.solusimandiri.id/privacy`. Tanggal berlaku:
       putuskan apakah perlu diperbarui (perubahan hanya penyebutan format ekspor). **Harus sebelum rilis tayang.**
2. [ ] **Uji internal**: unggah AAB ke Pengujian internal, tempel catatan rilis di atas. **Ekspor backup berkas dari build 15 sebelum memperbarui.**
3. [ ] **Uji HP**: jalankan [UJI-HP-LABA-RUGI.md](UJI-HP-LABA-RUGI.md). Semua butir bertanda **WAJIB** harus lulus.
4. [ ] **Listing**: samakan paragraf baru dengan listing yang tayang (lihat [LISTING-PLAY-STORE.md](LISTING-PLAY-STORE.md), 2026-10-29). Jangan mengubah judul (jendela 14 hari).
5. [ ] **Produksi bertahap**: promosikan **bundel yang sama** dari uji internal, mulai 10% → 50% → 100% sambil memantau Android vitals, ulasan, dan RevenueCat.
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
