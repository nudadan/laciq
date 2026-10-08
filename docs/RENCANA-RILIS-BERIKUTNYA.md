# Daftar rilis berikutnya (setelah 1.0.0+14)

> Dicatat 2026-10-08. Build 14 sudah tayang di produksi. Hal-hal di bawah butuh build baru, jadi digabung dalam satu rilis
> (satu peninjauan Play, bukan beberapa). Urutkan ulang sesuai kebutuhan.

## 1. Pesan persetujuan iklan (CMP / Google UMP)
**Latar:** AdMob (aplikasi terverifikasi 2026-10-08, peninjauan 2-3 hari) menyarankan platform pengelolaan izin yang
disertifikasi Google untuk pengguna di EEA, Inggris Raya, dan Swiss. Aplikasi memakai `google_mobile_ads ^9.1.0` tetapi
belum memanggil UMP (`ConsentInformation` / `ConsentForm` tidak ada di `lib/`). Sementara itu AdMob memakai "pesan
pengganti" bawaan (setelan akun *Maksimalkan cakupan pesan*, aktif default), jadi ini tidak mendesak untuk audiens Indonesia.

**Yang dikerjakan:**
1. AdMob > Privasi & pesan: buat pesan izin untuk aplikasi LaciQ (Android), terbitkan.
2. Kode: di awal aplikasi (sebelum memuat iklan) panggil `ConsentInformation.instance.requestConsentInfoUpdate`, tampilkan
   `ConsentForm` bila diperlukan, dan baru panggil `MobileAds.instance.initialize()` / muat banner bila `canRequestAds()`.
   Pengguna Premium/Ultimate (tanpa iklan) tidak perlu melewati ini.
3. Beri tempat di Pengaturan untuk membuka kembali pilihan privasi bila `privacyOptionsRequirementStatus == required`.
4. Uji dengan `ConsentDebugSettings` (geografi EEA) di perangkat nyata; pastikan layar tidak macet saat offline.
5. Perbarui `docs/kebijakan-privasi/index.html` (bagian iklan: UMP dan pilihan privasi) dan cek ulang
   `docs/DATA-SAFETY-PLAY.md` (tidak ada data baru yang diharapkan, tetapi periksa).
6. Tambahkan tes: alur persetujuan dengan fake, dan tidak ada iklan dimuat sebelum `canRequestAds()`.

**Selesai bila:** pengguna EEA mendapat dialog izin sebelum iklan pertama; pengguna non-EEA tidak melihat perubahan.

## 2. Sapaan "kamu" di teks aplikasi
**Latar:** situs `laciq.solusimandiri.id` dan materi Instagram sudah memakai "kamu" (2026-10-08). Teks di dalam aplikasi
masih "Anda" (sekitar 58 kemunculan di `lib/**/*.dart`, 0 "kamu"), sehingga pengguna merasakan beda nada antara situs dan app.

**Yang dikerjakan:**
1. Daftar semua teks: `grep -rn -w "Anda" lib` (dialog, onboarding, layar langganan, snackbar, tooltip, penjelasan izin).
2. Ganti ke "kamu / -mu" dengan nada yang sama seperti situs: santai di fitur dan onboarding, tetap jelas dan tegas di dialog
   persetujuan (suara, AI), izin, dan penjelasan privasi (jangan memakai "nggak" di sana).
3. Cari tes yang membandingkan string ("Anda") dan perbarui; jalankan seluruh suite (`flutter test`, 666 tes saat ini).
4. Jangan ubah `docs/kebijakan-privasi/index.html` ke nada santai tanpa keputusan terpisah; dokumen hukum sebaiknya tetap formal.
   Pertimbangkan satu kalimat pembuka yang ramah saja.
5. Samakan deskripsi di Play Console (`docs/LISTING-PLAY-STORE.md`, teks panjang) bila masih memakai "Anda".
6. Periksa layar pada ukuran kecil: "kamu" lebih pendek dari "Anda", tetapi frasa baru bisa lebih panjang.

**Selesai bila:** tidak ada "Anda" tersisa di teks pengguna aplikasi (kecuali kutipan atau nama khusus), dan seluruh tes lulus.

## Dibawa ke rilis yang sama (sudah diketahui)
- Versi baru: naikkan `pubspec.yaml` ke 1.0.0+15 (atau 1.0.1+15), bangun AAB dengan `--dart-define` AI yang benar
  (lihat memori "Build harus menyalakan AI").
- Catatan rilis (id), pembaruan lembar panduan bila ada fitur baru, dan cek Data Safety.

## Di luar daftar rilis (tindak lanjut lain)
- Kebijakan privasi memakai "server kami" untuk layanan AI di beberapa bagian; pertimbangkan penyederhanaan bersama revisi UMP di atas.
- Halaman lama `dompetku.hardan-ti.com/privacy` belum diubah.
- Repo lokal belum punya remote git (belum ada cadangan di luar PC ini).
