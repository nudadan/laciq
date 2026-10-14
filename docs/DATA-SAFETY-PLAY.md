# Jawaban Data Safety Play Console — DompetKu

> Dibuat 2026-10-01 untuk Play Console → Kebijakan dan program → Konten aplikasi → Keamanan data. Disusun dari
> `docs/kebijakan-privasi/index.html` (versi 1 Okt 2026) dan kode aplikasi + Worker. Jawaban Data Safety harus
> sama dengan kebijakan privasi; ubah keduanya bersama bila fitur berubah.

## Sumber acuan SDK pihak ketiga
- **Google Mobile Ads (AdMob)**: [panduan resmi Google](https://developers.google.com/admob/android/privacy/play-data-disclosure)
  (versi SDK 25.5.0; aplikasi memakai `google_mobile_ads ^9.1.0`, cek ulang bila SDK naik jauh). Mengumpulkan DAN
  membagikan: alamat IP, interaksi produk, informasi diagnostik, ID perangkat/akun. Enkripsi TLS.
- **RevenueCat**: [panduan resmi](https://www.revenuecat.com/docs/platform-resources/google-platform-resources/google-plays-data-safety)
  — hanya Riwayat pembelian (Financial info), wajib, tidak bisa dimatikan. Tidak mengumpulkan lokasi, aktivitas
  aplikasi, atau diagnostik. ID pengguna anonim kita tidak mengandung nama/email.

## Pertanyaan umum
| Pertanyaan | Jawaban |
|---|---|
| Apakah aplikasi mengumpulkan atau membagikan tipe data pengguna yang diwajibkan? | **Ya** |
| Semua data pengguna dienkripsi saat transit? | **Ya** (HTTPS: AdMob, RevenueCat, Worker `dompetku-api.hardan-ti.com`, Google Drive) |
| Aplikasi mengizinkan pembuatan akun? | **Tidak** (tidak ada akun DompetKu) |
| Cara pengguna meminta penghapusan data | **Ya**: menu Pengaturan > Hapus semua data (lokal); email support@hardan-ti.com untuk data di server. URL penghapusan: `https://dompetku.hardan-ti.com/privacy` (bagian 9) |
| Mengikuti Kebijakan Keluarga? | Tidak (bukan untuk anak) |
| Validasi keamanan independen? | Tidak |

## Tipe data yang dideklarasikan
Semua baris di bawah: **dikumpulkan = Ya**. Pilih "Dibagikan = Ya" hanya bila tertulis.

| Kategori > Tipe | Dibagikan | Wajib/Opsional | Tujuan | Sumber |
|---|---|---|---|---|
| Info keuangan > **Riwayat pembelian** | Tidak (RevenueCat = penyedia layanan) | Wajib | Fungsi aplikasi | RevenueCat |
| Info keuangan > **Info keuangan lainnya** | Tidak (Cloudflare, Google = penyedia layanan) | **Opsional** (hanya bila memakai Scan struk AI dan menyetujuinya) | Fungsi aplikasi | Teks struk ke Worker + Gemini (Ultimate) |
| Lokasi > **Lokasi perkiraan** | **Ya** | Wajib | Iklan atau pemasaran; Pencegahan penipuan, keamanan, dan kepatuhan | AdMob (dari alamat IP) |
| Aktivitas aplikasi > **Interaksi aplikasi** | **Ya** | Wajib | Iklan atau pemasaran; Analitik; Pencegahan penipuan, keamanan | AdMob (interaksi produk) |
| Info dan performa aplikasi > **Diagnostik** | **Ya** | Wajib | Analitik; Pencegahan penipuan, keamanan | AdMob |
| Perangkat atau ID lainnya > **ID perangkat atau ID lainnya** | **Ya** | Wajib | Iklan atau pemasaran; Analitik; Pencegahan penipuan, keamanan; Fungsi aplikasi | AdMob (ID iklan) + ID anonim RevenueCat |

Catatan: baris AdMob berlaku untuk paket gratis. Pelanggan berbayar tidak melihat iklan, tetapi form Play tidak
membedakan paket, jadi tetap dideklarasikan.

## Yang TIDAK dideklarasikan, dan alasannya
- **Transaksi, dompet, anggaran, utang, buku kas, foto struk**: hanya di HP, tidak pernah dikirim ke kami. Data yang
  tidak meninggalkan perangkat bukan "dikumpulkan".
- **Foto struk**: dibaca di perangkat dengan ML Kit; tidak dikirim. Hanya teks hasil baca yang dikirim (Ultimate).
- **Backup Cloud (Premium)**: dienkripsi di HP lalu diunggah ke folder `drive.appdata` milik akun Google pengguna
  sendiri; pengembang tidak menerima salinannya. Dinyatakan di kebijakan privasi bagian 5. (Keputusan konservatif
  alternatif: deklarasikan "Info keuangan lainnya" tidak dibagikan, tujuan Fungsi aplikasi, opsional. Play umumnya
  tidak mewajibkan bila data hanya ke penyimpanan pribadi pengguna.)
- **Email akun Google** pada Backup Cloud: hanya ditampilkan di layar, tidak dikirim ke kami.
- **Biometrik**: dicocokkan oleh sistem Android; aplikasi tidak menerima datanya.
- **Dialog ulasan Play (In-App Review, plugin `in_app_review`)**: dijalankan oleh Google Play; aplikasi tidak mengirim
  data apa pun dan tidak menerima hasil/ratingnya. Hitungan transaksi dan waktu permintaan hanya disimpan lokal di
  penyimpanan aman perangkat. Tidak perlu dideklarasikan.
- **Data teknis koneksi di Cloudflare (IP)**: dicatat Cloudflare sebagai penyedia layanan; disebut di kebijakan bagian 6.

## Keputusan yang perlu diperiksa pemilik sebelum kirim
1. Pemrosesan teks struk bersifat sementara (tidak disimpan di log/KV). Play mengizinkan **tidak** mendeklarasikan data
   yang diproses efemeral, tetapi kami mendeklarasikannya demi kehati-hatian karena fitur ini opsional dan lebih
   baik berlebih daripada kurang.
2. Kebijakan privasi mengklaim Google tidak memakai data layanan berbayar untuk melatih model (ketentuan Gemini API).
   Cocokkan dengan <https://ai.google.dev/gemini-api/terms> bila ada perubahan.
3. Jawaban ini mengikuti kode saat ini. Jika nanti ada analitik/crash reporting, atau mode "ads terbatas" diaktifkan,
   perbarui.

## Catatan login Google (Backup Cloud) — 2026-10-01
Login Google gagal di build dari Play dengan galat 28444 ("Developer console is not set up correctly"; server Google:
"This android application is not registered to use OAuth2.0"). Penyebab: sidik jari (SHA-1) sertifikat yang benar-benar
menandatangani APK terpasang dari Play (`92:09:67:BB:F4:21:44:71:5F:F4:25:80:F8:3B:10:0E:B5:F3:E1:63`, dibaca dengan
`apksigner verify --print-certs` dari APK di perangkat) tidak sama dengan yang terdaftar di client OAuth "Play App Signing"
(`21:30:93:26:...`, nilai kunci klasik di konsol Play). Konsol Play juga menampilkan kunci post-quantum
(`2D:C6:90:1C:...`). Perbaikan: client OAuth Android baru "DompetKu - Play (terpasang)" dengan SHA-1 hasil baca dari APK.
Setelah rilis produksi, periksa lagi sidik jari APK hasil unduhan produksi dan daftarkan bila berbeda.
Uji ulang 2026-10-01 setelah client OAuth baru dan scope `drive.appdata` ditambahkan di Data Access: login, cadangkan, dan
pulihkan lewat Backup Cloud berhasil di build 6 dari Play. Sisa tugas: publikasikan layar persetujuan OAuth ke Production
(scope non-sensitif, tanpa verifikasi) agar bukan hanya 5 penguji yang bisa masuk; tampilkan kode galat Google di pesan
aplikasi (`cloud_backup_service.dart`) pada build berikutnya.
Update 2026-10-01: layar persetujuan OAuth dipublikasikan ke **Production**. Syarat tanpa verifikasi: <= 10 domain, TANPA logo
aplikasi (mengunggah logo mewajibkan verifikasi), hanya scope non-sensitif (`drive.appdata`). Branding diisi: beranda
`https://dompetku.hardan-ti.com`, kebijakan privasi `/privacy`, domain terotorisasi `hardan-ti.com`. Beranda dipasang di
nginx (`location = /`, lihat `docs/situs-beranda/`). Bila suatu saat ingin menambah logo, ajukan verifikasi dulu.

## Catatan 2026-10-04: ekspor Excel dan Laporan Bulanan
Keduanya dihitung dan dibuat sepenuhnya di perangkat (tanpa jaringan, tanpa izin baru, tanpa SDK baru). Berkas Excel baru keluar dari HP bila pengguna membagikannya sendiri lewat lembar bagikan Android, sama seperti CSV dan backup berkas. **Tidak ada perubahan deklarasi Data Safety.** Kebijakan privasi bagian 7 hanya ditambah penyebutan ekspor Excel.

## Pembaruan 2026-10-04 (tahap 3 dan 4): input suara dan ringkasan laporan AI
**PERIKSA ULANG di Play Console sebelum merilis.** Poin di bawah adalah pemahaman saya, bukan keputusan Google.

1. **Ringkasan laporan AI (Ultimate)** mengirim angka agregat (total, nama kategori beserta total, persen anggaran) ke Worker lalu Gemini, sama jalurnya dengan Ekstraksi Struk. Deklarasi yang sudah ada mencakupnya: **Info keuangan > Info keuangan lainnya**, dikumpulkan, dibagikan = ya (penyedia AI sebagai pemroses), opsional, tujuan Fungsi aplikasi. Tidak ada tipe data baru. Kebijakan privasi bagian 6a diperbarui.
2. **Input suara (Premium)**: aplikasi hanya meminta izin `RECORD_AUDIO` dan menerima TEKS dari layanan pengenalan suara Android; audio tidak diterima, disimpan, atau dikirim oleh aplikasi/server kita. Sikap konservatif yang disarankan: **jawab "tidak dikumpulkan" untuk Audio (Rekaman suara atau bunyi)** karena diproses oleh layanan sistem pada perangkat, dan jelaskan di kebijakan privasi (bagian 6b, sudah ditulis) bahwa Android dapat memakai layanan Google bila model offline tidak ada. Bila ragu, deklarasikan Audio > "Rekaman suara" sebagai **dikumpulkan = tidak** terlebih dahulu dan baca panduan resmi Google tentang data yang diproses di perangkat (data yang hanya diproses di perangkat dan tidak dikirim keluar tidak perlu dideklarasikan).
3. **Izin baru di manifest: `RECORD_AUDIO`.** Cek halaman Konten aplikasi/Izin apakah Play meminta deklarasi tambahan. Izin ini tidak termasuk izin sensitif yang dibatasi (SMS, log panggilan, lokasi latar belakang).
4. Jangan menulis "tidak ada data yang dikirim" secara mutlak di listing untuk fitur suara; gunakan kalimat dari kebijakan privasi.

## Pembaruan 2026-10-14: uji coba Ultimate tanpa kartu, Tabungan, penyesuaian saldo
**PERIKSA ULANG di Play Console sebelum merilis.** Berpadanan dengan kebijakan privasi bagian 6c (baru) dan perubahan kecil di
bagian 1, 2, 4, 6, 6a, 9. Tanggal berlaku kebijakan masih placeholder `[ISI TANGGAL RILIS]`; isi dan deploy kebijakan SEBELUM rilis.

### Ringkasan keputusan
| Fitur | Data keluar HP? | Dampak Data Safety |
|---|---|---|
| **Tabungan** (Ultimate) dan **Sesuaikan saldo** | Tidak (seluruhnya lokal, ikut backup berkas/cloud seperti data lain) | **Tidak ada perubahan** |
| **Uji coba Ultimate**: pemeriksaan kelayakan | **Ya**: ID anonim RevenueCat + `ANDROID_ID` ke Worker (koneksi TLS) | Tipe sudah dideklarasikan; perbarui **sumber** (lihat di bawah) |
| **Uji coba Ultimate**: klaim | **Ya, dan disimpan**: HMAC(ANDROID_ID), ID anonim, waktu mulai/akhir | Tipe yang sama; tanpa batas waktu penyimpanan eksplisit |
| Pengingat akhir uji coba | Tidak (notifikasi lokal) | Tidak ada perubahan |
| Play Integrity | **Belum aktif**: pendekode token tidak dipasang, aplikasi tidak mengirim token | Tidak dideklarasikan sekarang; **perbarui bila Fase 3 mengirim token** |

### Perubahan pada formulir Data Safety
Tidak ada tipe data baru. Satu baris yang sudah ada diperbarui deskripsinya:

| Kategori > Tipe | Dikumpulkan | Dibagikan | Wajib/Opsional | Tujuan | Sumber (perbarui) |
|---|---|---|---|---|---|
| Perangkat atau ID lainnya > **ID perangkat atau ID lainnya** | Ya | **Ya** (AdMob, seperti sebelumnya) | Wajib | Iklan atau pemasaran; Analitik; **Pencegahan penipuan, keamanan**; **Fungsi aplikasi** | AdMob (ID iklan) + ID anonim RevenueCat + **`ANDROID_ID` ke server kami untuk kelayakan uji coba (disimpan ber-hash, bukan nilai mentah)** |

Alasannya:
- `ANDROID_ID` dikirim ke server kami lewat TLS, jadi **dikumpulkan**. Disimpan hanya sebagai HMAC satu arah; tetap dianggap
  "disimpan" karena turunannya dipakai sebagai kunci. Play tidak mensyaratkan deklarasi ulang tipe, hanya tujuan yang jujur:
  *Pencegahan penipuan, keamanan* (anti uji coba berulang) dan *Fungsi aplikasi* (sisa hari saat pasang ulang), keduanya sudah dicentang.
- **Dibagikan** tidak berubah: Worker kami (Cloudflare) adalah penyedia layanan/pemroses, bukan pihak ketiga. RevenueCat sudah
  menerima ID anonim sejak sebelumnya; ia kini juga menerima hibah promosional untuk ID itu (informasi pembelian/hak akses).
- **Wajib vs opsional:** pemeriksaan kelayakan berjalan untuk semua pengguna non-Ultimate saat aplikasi dibuka, jadi tetap **Wajib**.
- Jawaban pertanyaan umum tidak berubah (TLS: ya; akun: tidak; permintaan penghapusan: ya, lihat bagian 9 kebijakan).

### Yang TIDAK dideklarasikan
- Tabungan, penyesuaian saldo, hitung mundur uji coba, dan pengingat akhir uji coba: lokal.
- Penghitung gabungan Worker (jumlah klaim harian, perkiraan biaya AI promo): angka tanpa identitas.

### Temuan yang perlu keputusan Anda
1. **Waktu pengiriman pengenal perangkat.** Di kode, status uji coba dimuat di awal sesi untuk semua pengguna non-Ultimate
   (`trialStatusProvider` di `HomeShell`), sehingga `ANDROID_ID` terkirim saat aplikasi dibuka, **sebelum** pengguna menekan
   "Mulai uji coba". Kebijakan 6c sudah menyatakan ini apa adanya. Teks lembar konfirmasi saat ini berbunyi:
   *"Untuk mencegah uji coba berulang, pengenal perangkat Anda dikirim ke server dalam bentuk ber-hash."*, yang menyiratkan
   pengiriman baru terjadi setelah tombol ditekan dan tidak menyebut pemeriksaan awal. **Rekomendasi:** ganti menjadi
   *"Agar uji coba hanya diberikan sekali per perangkat, aplikasi memeriksa kelayakan dengan mengirim pengenal perangkat Anda
   (disimpan ber-hash di server, bukan nilai aslinya). Tidak ada data keuangan yang dikirim."* (perubahan satu kalimat di
   `lib/features/subscription/trial_offer.dart`, ikut tes `trial_offer_test`).
   Alternatif yang lebih ketat: panggil `/trial/status` hanya saat kartu/titik penawaran akan tampil, bukan di awal sesi.
2. **Masa simpan catatan perangkat.** Catatan `trial:<hash>` di KV saat ini **tanpa kedaluwarsa**. Teks kebijakan ditulis
   sesuai itu ("selama program berlangsung atau sampai Anda meminta penghapusan"). Bila Anda ingin batas yang lebih
   tegas (mis. 24 bulan), pasang TTL pada `put` di `trial_handler.ts` dan ganti kalimat "Berapa lama" di 6c menjadi
   "disimpan sekitar 24 bulan lalu terhapus otomatis". Konsekuensi: perangkat bisa mengulang uji coba setelah TTL.
3. **Penghapusan atas permintaan.** Kebijakan menjanjikan penghapusan lewat ID anonim; catatan KV berkunci hash perangkat,
   jadi pencarian dilakukan dengan memindai nilai (`appUserId`). Cukup untuk skala sekarang; perlu skrip kecil bila jumlahnya besar.

### Daftar periksa sebelum mengirim
- [ ] Isi tanggal berlaku di `docs/kebijakan-privasi/index.html`, lalu deploy ke `laciq.solusimandiri.id/privacy`
      (halaman lama `dompetku.hardan-ti.com/privacy` tetap tidak diubah kecuali Anda memutuskan lain).
- [ ] Putuskan temuan 1 dan 2 di atas; sesuaikan kode/teks bila perlu.
- [ ] Play Console > Keamanan data: perbarui baris "ID perangkat atau ID lainnya" (sumber/tujuan) dan **kirim ulang** formulir.
- [ ] Cocokkan halaman Konten aplikasi bila Play meminta deklarasi tambahan setelah formulir diubah.
- [ ] Listing Play: jangan menulis "tidak ada data dikirim" atau "tanpa pelacakan" secara mutlak; sebut uji coba hanya
      sebagai "uji coba gratis 30 hari tanpa kartu".
- [ ] Setelah Fase 3 (Play Integrity) benar-benar mengirim token, perbarui kebijakan dan baris ini lagi.
