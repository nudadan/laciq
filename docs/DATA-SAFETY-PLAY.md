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
