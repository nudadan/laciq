# Rilis 1.1.0+15 (disiapkan 2026-10-14)

> Pengganti produksi saat ini (+14). Berisi Tabungan, Sesuaikan saldo, dan uji coba Ultimate 30 hari tanpa kartu.
> **Fitur uji coba dirilis "gelap"**: kodenya ada di aplikasi, tetapi baru hidup setelah `TRIAL_ENABLED = "1"` di Worker.
> Dengan begitu rilis dan penyalaan fitur dipisahkan: bila ada masalah, cukup `TRIAL_ENABLED = "0"` tanpa rilis ulang.

## Artefak
| Hal | Nilai |
|---|---|
| AAB | `build/app/outputs/bundle/release/app-release.aab` (87,4 MB) |
| Versi | `1.1.0` (kode versi **15**; produksi sekarang 14) |
| Penandatangan | `CN=DompetKu`, SHA-1 `86:E7:F6:D6:FD:67:0A:E4:D1:DC:AD:20:6E:01:30:F6:21:2E:A2:60` (sama dengan kunci unggah yang tercatat) |
| Dibangun dari | `main` pada `cb1eda1` + penaikan versi di `pubspec.yaml` (**commit penaikan versi sebelum mengunggah**, lihat langkah 0) |
| Tes | 759 Flutter + 146 Worker lulus; analisis statis bersih (2 info lama di `database.dart`) |
| Alamat Worker AI | Nilai bawaan di kode (tidak perlu `--dart-define`) |
| Skema database | v11 (migrasi dari v10 diuji otomatis untuk semua versi lama) |
| Format backup | v8 (backup dari 1.1.0 **tidak** bisa dipulihkan di build 14 atau lebih lama; sebaliknya bisa) |

### Manifest gabungan (dibanding build 14)
Diperiksa dari APK rilis dengan `aapt2 dump badging`:
- **Izin: tidak ada yang baru.** Paket `android_id` tidak menambah izin.
- **Fitur perangkat: tidak berubah.** `microphone` tetap `not-required` (pelajaran dari +12), kamera wajib seperti sebelumnya.
  Jadi Play tidak akan memperingatkan "perangkat tidak lagi didukung".

## Isi (dibanding produksi +14)
- **Tabungan (Ultimate):** satu atau beberapa tabungan dengan saldo terpisah dari dompet. Setor = pengeluaran dompet asal,
  tarik = pemasukan dompet tujuan. Tanpa Ultimate, tabungan lama tetap terlihat dan bisa ditarik.
- **Sesuaikan saldo (semua paket):** saldo awal dompet yang sudah punya transaksi **dikunci**; selisih ke saldo aktual dicatat
  sebagai transaksi "Penyesuaian Saldo". *Perubahan perilaku yang terlihat pengguna lama.*
- **Uji coba Ultimate 30 hari tanpa kartu** (opt-in, butuh Worker menyala): penawaran kontekstual, hitung mundur, peringatan
  hari ke-23/28/terakhir, dialog "yang akan berubah", pengingat notifikasi.
- Pemisahan tier akses dan tier berbayar (mencegah penagihan ganda bagi pelanggan Premium yang sedang uji coba).
- Teknis: skema DB v11, backup v8, paket `android_id`.

## Catatan rilis Play
Varian **A** bila uji coba dinyalakan bersamaan dengan rilis (355 karakter, batas 500):
```
Baru: Tabungan (Ultimate) dengan saldo terpisah dari dompet; setoran tercatat sebagai pengeluaran dan penarikan sebagai pemasukan. Uji coba Ultimate 30 hari tanpa kartu, dengan pengingat sebelum berakhir. Saldo awal dompet yang sudah punya transaksi kini dikunci; gunakan "Sesuaikan saldo" agar hitungan tidak meleset. Perbaikan dan penyempurnaan lainnya.
```
Varian **B** bila uji coba baru dinyalakan setelah rilis stabil (tanpa menyebut uji coba, 281 karakter):
```
Baru: Tabungan (Ultimate) dengan saldo terpisah dari dompet; setoran tercatat sebagai pengeluaran dan penarikan sebagai pemasukan. Saldo awal dompet yang sudah punya transaksi kini dikunci; gunakan "Sesuaikan saldo" agar hitungan tidak meleset. Perbaikan dan penyempurnaan lainnya.
```
**DIPILIH PEMILIK (2026-10-14): varian B.** Uji coba dinyalakan setelah 24-48 jam stabil (langkah 7); varian A hanya acuan bila rencana itu berubah.

## Risiko dan hal yang perlu diperhatikan
| Risiko | Penjelasan | Mitigasi |
|---|---|---|
| Migrasi database v10 → v11 | Menambah tabel `savings_accounts` dan kolom `savings_id` pada transaksi | Diuji otomatis untuk semua versi lama; penguji internal ekspor backup berkas dulu |
| Saldo awal dompet terkunci | Pengguna yang terbiasa mengubah saldo awal akan melihat kolom terkunci | Jelas di dialog + tombol "Sesuaikan saldo"; masuk catatan rilis |
| Backup v8 tidak terbaca di versi lama | Pengguna yang kembali ke build lama tidak bisa memulihkan backup baru | Jarang; cukup dicatat |
| Aplikasi baru memanggil `/trial/status` saat dibuka | Worker lama menjawab 404 (diperlakukan "tidak ada penawaran") | Diuji: penawaran tersembunyi bila status bukan 200 |
| Pengenal perangkat terkirim saat dibuka | Dijelaskan di kebijakan privasi 6c dan lembar konfirmasi | **Deploy kebijakan sebelum rilis** (langkah 1) |
| Uji coba menguras anggaran AI | Kuota trial 60/6 per pengguna + anggaran global Rp1,35 jt | Saklar `TRIAL_ENABLED`; pantau `promo-cost` |

## Urutan rilis
0. [ ] **Commit penaikan versi**: `chore: versi 1.1.0+15 (Tabungan, Sesuaikan saldo, uji coba Ultimate)`. Lalu bangun ulang AAB
       bila ada perubahan kode setelahnya (AAB di atas dibangun dari pohon kerja dengan penaikan versi). Cadangkan repo ke tempat
       lain (belum ada remote) dan simpan `upload-keystore.jks` terpisah dari repo.
1. [ ] **Kebijakan privasi**: isi tanggal berlaku (`[ISI TANGGAL RILIS]`) di `docs/kebijakan-privasi/index.html`, deploy ke
       `https://laciq.solusimandiri.id/privacy`, dan cek tampilannya. **Harus sebelum rilis tayang.**
2. [ ] **Worker** (bisa kapan saja; kompatibel mundur, uji lulus): `cd backend/receipt-extraction-worker && npx wrangler deploy`
       dengan `TRIAL_ENABLED = "0"`. Pastikan endpoint `/extract` dan `/report-insight` masih berjalan (scan AI di build lama).
3. [ ] **Uji internal**: Play Console > Pengujian > Pengujian internal > Buat rilis, unggah AAB, tempel catatan rilis (varian B, dipilih),
       simpan dan terbitkan. Penguji memasang dari tautan opt-in. **Ekspor backup berkas sebelum memperbarui.**
4. [ ] **Uji HP**: jalankan [UJI-HP-TRIAL-ULTIMATE.md](UJI-HP-TRIAL-ULTIMATE.md) (nyalakan `TRIAL_ENABLED = "1"` hanya selama uji;
       aman karena hanya build internal yang memuat UI trial). Tambahan uji cepat non-trial: Tabungan (setor/tarik/hapus),
       Sesuaikan saldo, backup berkas v8 bolak-balik, pembelian/pulihkan, scan AI, Backup Cloud, migrasi dari data build 14.
5. [ ] **Data Safety**: perbarui baris "ID perangkat atau ID lainnya" dan kirim ulang formulir
       (lihat `DATA-SAFETY-PLAY.md`, bagian 2026-10-14). Cek halaman Konten aplikasi.
6. [ ] **Produksi bertahap**: promosikan **bundel yang sama** dari uji internal (tanpa membangun ulang), mulai **10%**,
       naikkan ke 50% lalu 100% setelah melihat Android vitals (tingkat crash/ANR), ulasan baru, dan dasbor RevenueCat stabil.
7. [ ] **Nyalakan uji coba** setelah 24-48 jam stabil di 100%: `TRIAL_ENABLED = "1"`, deploy Worker. Pantau
       `wrangler tail` (`trial_claim result=`), `promo-cost:<bulan>`, dan konversi trial → berbayar (RevenueCat).
8. [ ] Setelah tayang: perbarui `RILIS-*.md` ini dengan tanggal publikasi; tinjau metrik 4-6 minggu
       ([RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md](RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md) bagian 7).

## Rencana mundur
| Gejala | Tindakan |
|---|---|
| Masalah pada uji coba (penagihan ganda, klaim anomali, biaya AI melonjak) | `TRIAL_ENABLED = "0"` lalu deploy Worker; tidak perlu rilis ulang. Trial yang berjalan tidak terpengaruh |
| Crash atau regresi berat pada rilis | Play Console > Produksi > **Jeda peluncuran** (rollout bertahap); siapkan perbaikan sebagai +16 |
| Migrasi database bermasalah pada sebagian perangkat | Jeda peluncuran, minta pengguna ekspor backup, siapkan +16; **jangan** mengubah nomor skema mundur |

## Yang masih terbuka (bukan penghalang rilis gelap)
- Play Integrity (Fase 3): pendekode belum dipasang; `INTEGRITY_MODE` tetap `shadow`.
- Verifikasi `ANDROID_ID` dengan kunci Play (A4 di daftar uji HP) wajib lulus **sebelum** langkah 7.
- Remote git belum ada (lihat langkah 0).
