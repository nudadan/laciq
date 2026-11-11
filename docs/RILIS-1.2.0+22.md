# Rilis 1.2.0+22 (disusun 2026-11-11, belum diunggah)

> Pengganti +21 (jalur Pengujian internal) dan, bila lulus uji, calon pengganti produksi +20. Isinya sama dengan [+21](RILIS-1.2.0+21.md)
> ditambah satu perbaikan tampilan yang ditemukan saat uji +21 di HP Samsung: teks bantu penarikan tabungan ke **Lainnya** tidak lagi terpotong.
> **Produksi tetap +20.** Jalur internal tetap +21 sampai +22 diunggah.

## Artefak
| Hal | Nilai |
|---|---|
| AAB | `build/app/outputs/bundle/release/app-release.aab` (**96.821.097 byte**, 96,8 MB; +260 byte dibanding +21) |
| SHA-256 | `a3cf6715a2b5803114980f40fa90bc522ef92d5d7b3191caa4719a584e26cc12` |
| Versi | `1.2.0` (kode versi **22**; produksi 20, internal 21) |
| Dibangun dari | `main` pada commit `6cf13a4` (`chore: versi 1.2.0+22`), pohon kerja bersih untuk berkas yang dilacak |
| Penandatangan | `CN=DompetKu`, SHA-1 `86:E7:F6:D6:FD:67:0A:E4:D1:DC:AD:20:6E:01:30:F6:21:2E:A2:60` (**sama dengan +15 sampai +21**), berlaku sampai 7 Feb 2054 |
| Alamat Worker AI | Nilai bawaan di kode (tanpa `--dart-define`) |
| Skema database / format backup | v13 / v10 (sama dengan +21) |

### Manifest gabungan (dibanding +21)
Dibandingkan dari manifest gabungan hasil build: **tidak ada perbedaan selain `versionCode` 21 → 22.** Izin dan fitur perangkat tidak berubah.
`pubspec.yaml` (selain versi), `pubspec.lock`, dan `android/` tidak berubah sejak +21. Satu-satunya perubahan kode aplikasi sejak +21 adalah
`lib/features/savings/savings_detail_page.dart` (commit `5b01873`).

## Isi
**Dibanding +21 (satu perubahan):** teks bantu dialog **Tarik** dengan pilihan Lainnya terpotong di baris ketiga pada layar sempit (ditemukan di layar sampul
Samsung SM-F956B), sehingga kalimat "Saldo dompet tidak berubah." tidak terbaca. Kini kalimat itu ada di depan, batas baris teks bantu 3 → 4, dan pesan galat
nominal boleh 2 baris (`errorMaxLines`) agar "Saldo tabungan hanya Rp..." tidak terpotong.

**Dibanding produksi +20** (sama dengan +21): opsi Lainnya pada setor/tarik tabungan (tabel baru `savings_external_entries`, skema v13), pesan galat langganan yang
membedakan jaringan, Google Play, dan galat lain, serta perbaikan uji trial. Lihat [RILIS-1.2.0+21.md](RILIS-1.2.0+21.md) untuk rincian, hal yang berubah bagi
pengguna (backup v10 tidak bisa dipulihkan di aplikasi lama; penarikan ke Lainnya tidak dihitung sebagai pengeluaran), dan rencana mundur.

## Pemeriksaan yang sudah dilakukan
- `flutter analyze`: hanya 2 info lama di `database.dart`.
- `flutter test`: **940 lulus, 0 gagal**, termasuk uji UI yang mengunci kalimat kunci di depan serta `helperMaxLines` 4 dan `errorMaxLines` 2.
- AAB: teks baru ("Saldo dompet tidak berubah. Dana dipakai di luar dompet-mu") ada di `libapp.so` ketiga ABI (arm64-v8a, armeabi-v7a, x86_64); teks lama tidak ada.
- Uji +21 di HP Samsung (Android 17) sebelumnya: pembaruan di tempat dari +20, data utuh, setor/tarik Lainnya, batas saldo, hapus, batal, penolakan saldo negatif,
  penolakan hapus permanen, dan arsip semuanya benar; Total Saldo dan pemasukan/pengeluaran tidak berubah; tidak ada crash.

## Belum dilakukan
- AAB belum diunggah ke Play Console dan belum diuji sebagai +22 di perangkat.
- Tampilan teks bantu yang diperbaiki belum dilihat di HP (hanya diuji lewat uji widget dan pengecekan isi AAB).
- Dari daftar uji +21 yang masih terbuka: Backup lalu Pulihkan format v10, pesan galat langganan baru di perangkat, serta pembelian dan pemulihan pembelian dengan akun penguji lisensi.

## Catatan rilis Play (359 karakter, batas 500)
Sama dengan +21; perbaikan teks bantu adalah bagian dari fitur Lainnya, jadi tidak perlu disebut tersendiri.
```
Baru: opsi "Lainnya" pada setor dan tarik Tabungan, untuk dana yang berasal dari atau pergi ke luar dompet (mis. transfer ke rekening orang lain atau bayar tagihan). Pesan galat langganan kini lebih jelas membedakan masalah internet dan masalah Google Play. Backup dari versi ini tidak bisa dipulihkan di versi lama, jadi perbarui aplikasi sebelum memulihkan.
```

## Urutan rilis
0. [x] Naikkan versi dan bangun AAB (2026-11-11), lihat Artefak.
1. [ ] **Unggah ke Pengujian internal** di Play Console (menggantikan +21). Cek pratinjau: tidak ada perangkat yang hilang, ukuran instal sekitar 21,6 MB.
2. [ ] Perbarui di HP penguji (+21 → +22 lewat Play) dan lihat dialog Tarik dengan Lainnya: kalimat pertama teks bantu harus terbaca penuh.
3. [ ] Uji sisa daftar +21 (Backup/Pulihkan v10, pesan galat langganan, pembelian) di perangkat.
4. [ ] Promosikan **bundel yang sama** ke Produksi bertahap hanya bila langkah 2 dan 3 lulus. Data Safety dan kebijakan privasi tidak berubah.
5. [ ] Setelah tayang: perbarui dokumen ini.
