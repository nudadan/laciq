# Rilis 1.0.0+12 (disiapkan 2026-10-04)

AAB: `build/app/outputs/bundle/release/app-release.aab` (87 MB, ditandatangani kunci unggah `CN=DompetKu`, SHA-1
`86:E7:F6:D6:FD:67:0A:E4:D1:DC:AD:20:6E:01:30:F6:21:2E:A2:60`). Commit `383cc90` di `main`. 666 tes Flutter + 84 tes Worker lulus,
analisis statis bersih (2 info lama di `database.dart`). Alamat Worker AI sudah menjadi nilai bawaan di kode (tidak perlu `--dart-define`).

## Isi (dari build 7 sampai 12, dibanding rilis produksi 6)
- Rebrand ke LaciQ (nama, teks, tema, berkas ekspor), domain `laciq.solusimandiri.id`.
- Baru: Catat dengan Suara (Premium), ekspor Excel .xlsx (Premium), Laporan Bulanan (Premium), Ringkasan AI Laporan Bulanan (Ultimate).
- Foto struk: bisa dilihat kembali, dihapus, miniatur di daftar dan pratinjau di formulir; foto yatim dibersihkan.
- Dialog ulasan Play (In-App Review) dan tombol "Beri nilai LaciQ".
- Backup Cloud: saklar "Sertakan foto struk"; pesan galat login berkode.
- Perbaikan: scan AI di buku kas bisnis (ID kategori panjang), pulihkan pembelian jujur, status langganan ditarik eksplisit.
- Izin baru: `RECORD_AUDIO` (hanya saat tombol suara ditekan, setelah dialog penjelasan).

## Catatan rilis Play (382 karakter, batas 500)
```
Nama baru: LaciQ (sebelumnya DompetKu). Baru: Catat dengan Suara, ekspor laporan ke Excel (.xlsx), dan Laporan Bulanan dengan sorotan otomatis (Premium). Ultimate: Ringkasan AI untuk Laporan Bulanan. Foto struk kini tampil sebagai miniatur di daftar transaksi dan bisa dilihat kembali. Penilaian aplikasi lewat dialog Play. Perbaikan scan AI di buku kas bisnis dan status langganan.
```

## Urutan rilis (menunggu peninjauan produksi rilis 6 selesai)
1. [x] Worker `/report-insight` di-deploy (versi `cdbd022b`), diuji di tablet.
2. [x] DIKERJAKAN 2026-10-04 17:27 (cadangan lama: `privacy/index.html.bak-20261004` di server, tidak terjangkau publik). **Deploy kebijakan privasi baru** (`docs/kebijakan-privasi/index.html`, bagian 6a, 6b, tanggal berlaku 4 Okt 2026) ke
       `https://laciq.solusimandiri.id/privacy` SEBELUM rilis tayang. (Situs lama `dompetku.hardan-ti.com/privacy` hanya diubah bila
       listing yang ditinjau masih merujuknya.)
3. [ ] Play Console > Keamanan data: periksa ulang (lihat `DATA-SAFETY-PLAY.md`, catatan 2026-10-04): Audio dianggap tidak
       dikumpulkan; Info keuangan lainnya sudah mencakup ringkasan AI. Periksa apakah `RECORD_AUDIO` memicu deklarasi tambahan.
4. [ ] Unggah AAB ke jalur **uji internal**, pasang dari Play, uji cepat: beli/pulihkan, suara, Excel, Laporan, ringkasan AI,
       Backup Cloud (cek SHA-1 APK terpasang untuk client OAuth bila perlu).
5. [ ] Kirim draf listing LaciQ (nama, deskripsi `LISTING-PLAY-STORE.md` termasuk baris suara/Excel/Laporan/ringkasan AI, gambar
       fitur, URL privasi baru, screenshot Ultimate) bersama rilis: Ringkasan publikasi > "Kirim ... perubahan untuk ditinjau".
       PRASYARAT: cek PDKI fonetik (laciq, lasik, lacik) dan "laci".
6. [ ] Promosikan build 12 dari uji internal ke produksi setelah peninjauan rilis 6 selesai.
7. [ ] Setelah tayang: isi `PLAY_URL` di beranda, sesuaikan `PROMOSI-PEMASARAN.md` ke nama LaciQ.
