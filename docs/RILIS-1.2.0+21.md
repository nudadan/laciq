# Rilis 1.2.0+21 (disusun 2026-11-11, belum diunggah)

> Pengganti produksi saat ini (+20). Membawa dua perubahan: opsi **Lainnya** pada setor/tarik Tabungan, dan pesan galat
> langganan yang membedakan penyebab. Dibangun untuk diuji di HP penguji internal lewat Play sebelum dipromosikan.

## Artefak
| Hal | Nilai |
|---|---|
| AAB | `build/app/outputs/bundle/release/app-release.aab` (**96.820.837 byte**, 96,8 MB) |
| SHA-256 | `8891660560ca007d4eeb977658f301d6fcb9ac641366f95b527a90d2a74e1f2d` |
| Versi | `1.2.0` (kode versi **21**; produksi sekarang 20) |
| Dibangun dari | `main` pada commit `70faa92` (`chore: versi 1.2.0+21`), pohon kerja bersih untuk berkas yang dilacak |
| Penandatangan | `CN=DompetKu`, SHA-1 `86:E7:F6:D6:FD:67:0A:E4:D1:DC:AD:20:6E:01:30:F6:21:2E:A2:60` (**sama dengan +15 sampai +20**), berlaku sampai 7 Feb 2054 |
| Alamat Worker AI | Nilai bawaan di kode (tanpa `--dart-define`) |
| Skema database | **v13** (naik dari v12) |
| Format backup | **v10** (naik dari v9) |

### Manifest gabungan (dibanding +20)
Dibandingkan dari manifest gabungan hasil build (+20 dari server, +21 dari sini): **tidak ada perbedaan selain `versionCode` 20 → 21.**
Izin dan fitur perangkat tidak berubah (`microphone` tetap tidak wajib), jadi Play tidak akan memperingatkan "perangkat tidak lagi didukung".
`pubspec.yaml` (selain versi), `pubspec.lock`, dan `android/` tidak berubah sejak +20.

## Isi (dibanding produksi +20)
1. **Opsi Lainnya pada Tabungan** (commit `17f3e7c`). Pilihan dompet di dialog Setor/Tarik kini punya "Lainnya" untuk dana yang
   berasal dari atau pergi ke luar dompet pengguna (transfer ke rekening orang lain, bayar tagihan). Hanya menggeser saldo
   tabungan: **tidak mengubah saldo dompet dan tidak masuk total pemasukan/pengeluaran.** Disimpan di tabel baru
   `savings_external_entries` (skema v13), karena saldo tabungan sebelumnya hanya diturunkan dari transaksi dompet yang wajib punya dompet.
2. **Pesan galat langganan** (commit `dd8ecd0`). Memuat paket dan memulihkan pembelian tidak lagi selalu berkata "Periksa
   koneksi internetmu": galat dibedakan menjadi jaringan, Google Play tidak bisa dipakai, dan lainnya, dan galat aslinya dicatat.
3. Perbaikan uji `trial_offer_test` (tanggal tetap → relatif), tidak memengaruhi aplikasi (commit `8ff86a1`).

## Hal yang berubah bagi pengguna
- **Backup v10 tidak bisa dipulihkan di aplikasi lama** (sengaja: aplikasi lama akan salah menghitung saldo tabungan). Backup lama (sampai v9)
  tetap bisa dipulihkan di +21. Sama seperti pola +15 (backup v8).
- Penarikan tabungan ke Lainnya **tidak dihitung sebagai pengeluaran** di laporan. Keputusan produk yang bisa ditinjau ulang.
- Ekspor Excel/CSV transaksi tidak memuat entri Lainnya (bukan transaksi dompet).
- Migrasi v12 → v13 hanya menambah tabel (`createTable`); data lama tidak diubah.

## Pemeriksaan yang sudah dilakukan
- `flutter analyze`: hanya 2 info lama di `database.dart`.
- `flutter test`: **940 lulus, 0 gagal.** Termasuk migrasi dari semua versi lama (v1 sampai v12) ke v13 dan uji data nyata v12 → v13.
- Uji baru: 20 uji DB dan backup (`savings_external_test`), 3 uji alur UI (`savings_external_flow_test`), 7 uji pemetaan galat (`billing_error_message_test`).
- Worker (`backend/receipt-extraction-worker`) tidak berubah; hasil terakhir 146 lulus.

## Belum diuji (perlu di HP penguji internal)
- Pembaruan **+20 → +21 lewat Play** pada data nyata (migrasi v13) tanpa menghapus aplikasi. **Ekspor backup file dulu** sebelum memperbarui.
- Dialog Setor/Tarik dengan "Lainnya" dan tampilan riwayat di perangkat (hanya diuji lewat uji widget; emulator tidak stabil sehingga belum dicoba langsung).
- Backup v10: Backup data lalu Pulihkan dari backup pada tabungan yang punya entri Lainnya (dan backup cloud bila dipakai).
- Pesan galat baru pada layar Premium: matikan data seluler untuk melihat pesan jaringan; pesan "Google Play belum bisa dipakai" hanya muncul di perangkat tanpa Play yang berfungsi.
- Pembelian dan pemulihan pembelian dengan akun penguji lisensi (tidak berubah, tetapi inilah alasan rilis internal ini).

## Catatan rilis Play (359 karakter, batas 500)
```
Baru: opsi "Lainnya" pada setor dan tarik Tabungan, untuk dana yang berasal dari atau pergi ke luar dompet (mis. transfer ke rekening orang lain atau bayar tagihan). Pesan galat langganan kini lebih jelas membedakan masalah internet dan masalah Google Play. Backup dari versi ini tidak bisa dipulihkan di versi lama, jadi perbarui aplikasi sebelum memulihkan.
```

## Urutan rilis
0. [x] Naikkan versi dan bangun AAB (2026-11-11), lihat Artefak.
1. [ ] **Unggah ke Pengujian internal** di Play Console (pemilik). Cek pratinjau: tidak ada perangkat yang hilang, ukuran instal sekitar 21,6 MB.
2. [ ] Uji di HP penguji internal (daftar "Belum diuji"). Semua butir migrasi dan backup harus lulus.
3. [ ] Promosikan **bundel yang sama** ke Produksi bertahap hanya bila langkah 2 lulus. Data Safety dan kebijakan privasi tidak berubah (tidak ada data baru).
4. [ ] Setelah tayang: perbarui dokumen ini dan [MATRIKS-FITUR-PAKET.md](MATRIKS-FITUR-PAKET.md) bila perlu.

## Rencana mundur
| Gejala | Tindakan |
|---|---|
| Migrasi v13 bermasalah pada sebagian perangkat | Jeda peluncuran; minta pengguna ekspor backup; siapkan +22. **Jangan** mengubah nomor skema mundur. |
| Saldo tabungan tidak cocok setelah memakai Lainnya | Periksa entri di riwayat tabungan; saldo = setoran dompet + setoran Lainnya − penarikan dompet − penarikan Lainnya. |
| Crash atau regresi berat | Produksi > Kelola rilis > **Jeda peluncuran**. |
