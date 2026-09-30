# Catatan Sesi — Dompet Pintar (21 September 2026)

Rekaman informasi kunci dari sesi pengembangan hari ini: keputusan beserta alasannya, status, aturan yang tidak boleh
dilanggar, hal yang masih terbuka, dan pelajaran dari kesalahan. Dibuat agar pekerjaan bisa dilanjutkan (oleh Anda atau
sesi Claude berikutnya) tanpa mengulang penelusuran.

> Catatan kejujuran: bagian **10** memisahkan apa yang sudah *terbukti* dari apa yang baru *diasumsikan*.
> Fakta kebijakan eksternal (Play Store, harga, regulasi) berasal dari pengetahuan umum saat perencanaan awal dan
> **perlu diverifikasi ulang** sebelum dijadikan dasar keputusan.

---

## 1. Ringkasan

Aplikasi manajemen keuangan pribadi **"Dompet Pintar"** untuk pengguna perorangan di **Indonesia**, dikembangkan **sendiri
oleh satu orang dibantu agen AI**, **Android dulu** (iOS menyusul), akan dipublikasikan ke Play Store untuk monetisasi.
Hari ini dibangun dari nol sampai: pencatatan (dompet, kategori, transaksi, transfer), anggaran, ringkasan + grafik, kunci
PIN/biometrik, ekspor CSV, backup/restore, ubah transaksi, transaksi berulang, kelola kategori, target tabungan, dan
**redesain tampilan gelap-futuristik**. Aplikasi sudah berjalan di HP fisik pemilik.

## 2. Keputusan produk & arsitektur (beserta alasan)

| Keputusan | Alasan |
|---|---|
| **Flutter** (Dart), satu basis kode | Android + iOS, performa grafik baik; cocok untuk solo developer |
| **Offline-first**: SQLite lokal via **Drift** adalah sumber kebenaran | Aplikasi keuangan harus jalan tanpa internet; tidak ada backend di MVP |
| **Riverpod 3** untuk state | Testable, deklaratif |
| Nominal disimpan **integer Rupiah** (tanpa desimal), tidak pernah `double` | Tidak ada galat pembulatan |
| Saldo dompet **dihitung** (saldo awal + transaksi), tidak disimpan | Tidak mungkin tidak sinkron |
| **Soft delete** (`deleted_at`) + `updated_at` di tabel transaksi | Bisa di-undo, siap untuk sinkronisasi kelak |
| ID **UUID v7** dibuat di klien | Bisa dibuat offline tanpa konflik |
| Kategori/dompet bawaan ber-ID tetap (`cat-exp-makan`, `acc-tunai`, dst.) | Konsisten lintas perangkat/backup |
| Backup berupa **JSON berversi**, bukan salinan file SQLite | Bebas dari detail skema internal; bisa divalidasi sebelum menyentuh data |
| Kategori **diarsipkan, tidak dihapus** | Transaksi, anggaran, aturan berulang masih merujuknya |
| Target tabungan = **penanda dana (earmark)**, TIDAK mengubah saldo dompet | Kalau memotong dompet, uang terhitung dua kali di laporan/anggaran dan dompet bisa minus |
| Tema **gelap sebagai bawaan** | Identitas visual "futuristik" yang diminta pemilik |
| `android:allowBackup="false"` | Tanpa ini Android menyalin database keuangan ke Google Drive pengguna diam-diam |

### Rencana monetisasi (BELUM diimplementasikan; hanya rencana)
Freemium + langganan lewat **RevenueCat**. Usulan batas gratis: 3 dompet, 3 anggaran, riwayat laporan 3 bulan; Premium:
sinkronisasi cloud, scan struk (OCR/AI), ekspor PDF/Excel, mode berdua. Harga perkiraan (uji dulu): bulanan Rp 19–29 rb,
tahunan Rp 149–199 rb (jadikan opsi utama), lifetime Rp 399–499 rb. Pendapatan tambahan: iklan terbatas untuk pengguna
gratis, referral produk keuangan **berizin OJK** (berlabel sponsor), pembelian sekali beli (tema/ikon). Target konversi
awal yang realistis 2–5%. **Saat ini aplikasi tidak memiliki pembatasan apa pun.**

## 3. Status fitur (semua sudah berjalan)

- **Dompet**: tunai/bank/e-wallet/kartu dengan saldo awal.
- **Transaksi**: pemasukan, pengeluaran, transfer; ubah (ketuk), hapus (geser + Batal), daftar per hari dengan selisih harian.
- **Kategori**: 16 bawaan berbahasa Indonesia; tambah/ubah nama-ikon-warna; arsip/pulihkan. Jenis tidak bisa diubah.
- **Anggaran** bulanan per kategori pengeluaran.
- **Ringkasan**: total saldo, pemasukan/pengeluaran bulan ini, donut per kategori.
- **Transaksi berulang** (mingguan/bulanan/tahunan, tanggal berakhir, jeda/lanjut, ubah, hapus).
- **Target tabungan**: setor/tarik, riwayat, tenggat + perkiraan setoran per bulan, arsip, hapus.
- **Keamanan**: PIN 6 digit, sidik jari/wajah, kunci ulang setelah > 30 dtk di latar belakang.
- **Data**: ekspor CSV, backup & restore JSON.
- **Pengaturan**: tema (Sistem/Terang/Gelap), kelola kategori & transaksi berulang.
- **Belum ada**: langganan/paywall, sinkronisasi cloud, scan struk, notifikasi pengingat, enkripsi database, ikon aplikasi kustom, iOS.

## 4. Skema database & prosedur migrasi

Skema sekarang **v3** (sudah ada di HP pemilik). Tabel: `accounts`, `categories`, `transactions` (+`recurring_id`),
`budgets`, `recurring_rules`, `savings_goals`, `goal_contributions`. Format backup **v3** (v1 & v2 tetap terbaca).

**Setiap perubahan skema WAJIB:**
1. Naikkan `schemaVersion`, tulis langkah di `onUpgrade` (`lib/data/database.dart`).
2. `dart run build_runner build`
3. `dart run drift_dev schema dump lib/data/database.dart drift_schemas/`
4. `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`
5. Tambah kasus di `test/migration_test.dart` (isi data di skema lama → migrasi → data utuh + fitur baru jalan).
6. Naikkan `BackupService.formatVersion` bila format berubah; pertahankan pembacaan versi lama.
7. **Jangan pernah mengedit `drift_schemas/drift_schema_v*.json` yang sudah dirilis.**

Migrasi v2→v3 sudah dibuktikan pada database **nyata di HP** (sebelum: 2 dompet/16 kategori/1 transaksi; sesudah: identik
+ tabel baru kosong; `integrity_check` dan `foreign_key_check` = ok).

## 5. Konvensi yang tidak boleh dilanggar

- Urutan enum `TxType`, `AccountKind`, `Frequency`, `ContributionKind` disimpan sebagai **index** — jangan diubah urutannya.
- Drift menyimpan `DateTime` dengan **presisi detik**; waspada bila `updatedAt` kelak dipakai untuk menyelesaikan konflik sinkronisasi.
- **Transaksi berulang**: aturan menyimpan tanggal mulai + *indeks* kejadian berikutnya; tanggal dihitung dari jangkar
  (`occurrenceAt`), bukan dari kejadian sebelumnya (31 Jan → 28 Feb → **31 Mar**, bukan 28 Mar). ID transaksi hasil generate
  = `rec-<aturan>-<indeks>` sehingga **idempoten**. Dicatat saat aplikasi dibuka/dilanjutkan (bukan pekerjaan latar belakang).
  Mengubah aturan hanya berlaku untuk transaksi berikutnya; jadwal (mulai/frekuensi) tidak bisa diubah. Dilanjutkan setelah
  dijeda → periode yang terlewat **dilewati**.
- **Target tabungan**: dana terkumpul = setoran − penarikan (yang belum dihapus) dan **tidak boleh negatif** lewat jalur
  apa pun (penarikan berlebih, menghapus setoran yang sudah ditarik, file backup yang dimodifikasi).
- **Kategori**: nama unik per jenis (tanpa beda huruf besar/kecil, termasuk yang diarsipkan); minimal satu kategori aktif per jenis.
- **Restore** berjalan dalam satu transaksi: gagal = data lama utuh. Backup divalidasi penuh (format, versi, ID ganda,
  referensi menggantung, nominal ≤ 0, dana negatif) sebelum menyentuh data.
- **CSV**: pemisah `;` (Excel regional Indonesia memakai titik koma), BOM UTF-8, sel teks dinetralkan dari *formula injection*.
- **Warna makna keuangan** lewat `context.palette` (`income/expense/transfer/warning`); jangan pakai `Colors.green`/`scheme.error`.
- Pesan singkat lewat `notify(messenger, teks)` (bukan `showSnackBar` langsung: snackbar mengantre dan umpan balik jadi terlambat).
- **Dialog dengan `TextEditingController`**: controller dimiliki `State` dialog itu sendiri, **jangan** di-`dispose` oleh pemanggil.

## 6. Keputusan yang masih TERBUKA (butuh pemilik)

1. **Application ID** masih otomatis: `id.dompetpintar.dompet_pintar`. **Permanen setelah dirilis** ke Play Store. Putuskan
   sebelum rilis (mis. `com.namaanda.dompetpintar`); mengubahnya sekarang masih murah.
2. Model target tabungan (earmark, tidak memotong dompet) — perlu persetujuan; alternatif "memotong dompet" butuh aturan
   tambahan agar tidak terhitung ganda.
3. Bawaan tema gelap — apakah cocok untuk semua pengguna; opsi Sistem/Terang tersedia.
4. Struktur harga & batas gratis (bagian 2) — belum diuji ke pengguna.
5. Apakah setoran otomatis ke target ("nabung Rp500rb tiap tgl 25") ingin dihubungkan ke transaksi berulang.

## 7. Batasan keamanan/privasi yang diketahui

- PIN adalah **kunci level aplikasi**, BUKAN enkripsi data. Database di penyimpanan privat aplikasi **tidak terenkripsi**
  (HP ter-root/akses fisik bisa membacanya). SQLCipher belum ada — sebaiknya masuk sebelum rilis publik / klaim "aman".
- PIN 6 digit di-hash PBKDF2-HMAC-SHA256 (10.000 iterasi) + salt acak di Keystore. 5 salah beruntun → kunci 30 dtk, berlipat
  ganda tiap putaran, maks. 15 menit, bertahan setelah aplikasi ditutup. **PIN tidak bisa dipulihkan.**
- File **backup & CSV tidak terenkripsi** dan berisi seluruh data keuangan.
- Penutup isi di tampilan "recent apps" bersifat *best-effort* (belum memakai `FLAG_SECURE`).
- Kebijakan privasi, syarat layanan, fitur hapus akun/data (wajib di store), dan kepatuhan UU PDP No. 27/2022 **belum dibuat**.

## 8. Lingkungan pengembangan

- **Ruang kerja ada di server remote** (`dimas-hms-sts`); pemilik menyambung lewat **VPN** dan SSH.
- Toolchain di `~/development` (tanpa sudo): Flutter 3.47.5 (stable), JDK 17, Android SDK 35/34/36. Jalankan
  `source ~/development/env.sh` sebelum perintah `flutter`/`dart`/`adb` (tidak ada di PATH).
- **Server memblokir SSH port forwarding** (`/etc/ssh/sshd_config.d/00-no-forwarding.conf`: `AllowTcpForwarding no`, dibuat
  21 Sep 10:13). Ini pengaturan keamanan yang **disengaja — jangan dilewati/diubah tanpa keputusan pemilik server.**
- Solusi yang dipakai: HP masuk **VPN yang sama** dengan server, lalu **Debugging nirkabel** (server menyambung keluar ke
  HP; tanpa tunnel). Port acak & berganti tiap dinyalakan ulang; pairing memakai kode 6 digit sekali pakai. Setelah pairing
  ada satu port koneksi; pada sesi ini HP juga terlihat di port `5555` (mode `tcpip`).
- HP uji: **Redmi Note 13 Pro 5G** (kode `2312DRA50G`, Android 16, HyperOS). Xiaomi memblokir pemasangan lewat adb kecuali
  *Pasang via USB* (+ *Debugging USB (Pengaturan keamanan)*) aktif dan dialog konfirmasi disetujui; APK debug 156 MB
  butuh ±100–120 dtk lewat VPN.
- Saya bisa **melihat layar HP** lewat `adb exec-out screencap -p` (skala tampilan 900×2000 = asli 1220×2712, faktor 1,36).
- Pemandu layar yang aman: `uiautomator dump` → cari node berdasarkan `text`/`content-desc` (mis. "Catat", "Pengaturan", "Kembali") → tap pusat `bounds`. Selalu cek fokus jendela sebelum tiap ketukan.
- Cek **sebelum** menyentuh HP: `dumpsys display | grep mScreenState`, `dumpsys window | grep mCurrentFocus`.
  Layar mati/terkunci/NotificationShade ⇒ tangkapan hitam & hot restart menggantung. **Jangan mengetuk buta; jangan mencoba
  membuka kunci.**
- HP keluar dari VPN/Wi-Fi saat layar mati lama → sesi debug putus. Saran: aktifkan *Tetap aktif* (Stay awake) saat mengisi daya.
- `pkill -f "<pola>"` di dalam perintah bash yang memuat pola yang sama akan **mematikan shell itu sendiri** (exit 144). Jangan dipakai.

## 9. Bug & pelajaran hari ini

| Kejadian | Akar masalah | Pelajaran |
|---|---|---|
| Widget test menggantung tanpa error | Drift butuh async nyata, `testWidgets` memakai jam palsu | Pakai `appTest`/`settle`/`typePin` di `test/support/harness.dart`; jangan `pumpAndSettle`; bersihkan di badan tes, bukan `addTearDown` |
| **Crash saat buat dompet** (`TextEditingController used after being disposed`) | Pemanggil `dispose()` controller segera setelah `showDialog`, padahal animasi tutup dialog masih memakainya. Dialog anggaran identik | Controller milik dialog itu sendiri. Tulis tes yang **gagal di kode lama dulu**, baru perbaiki |
| Snackbar kedua tak muncul (tes gagal) | `showSnackBar` mengantre di belakang yang lama (4 dtk) | Helper `notify` (clear lalu tampilkan) |
| `pageBack()` gagal di tes | Mencari tooltip `'Back'`; aplikasi berbahasa Indonesia (`'Kembali'`) | Cari tombol per tipe widget |
| 13 tes gagal setelah redesain | Tes mencari tombol pengaturan lewat **ikon** yang diganti | Cari lewat `find.byTooltip('Pengaturan')` |
| `NoSuchMethodError` aneh di HP padahal analyzer bersih | Kompiler inkremental `flutter run` tidak sinkron setelah banyak restart (kernel campuran file lama+baru) | Matikan sesi, mulai `flutter run` baru; jangan restart terus-menerus |
| "Restart selesai" palsu | `grep` menemukan baris "Restarted application" yang lama | Hitung jumlah baris sebelum/sesudah |
| Edit `pubspec.yaml` diam-diam tak masuk | Pola `replace` tidak cocok (ada baris kosong/komentar) tanpa error | Selalu `assert` pola ada sebelum mengganti |
| `dart format lib` mengubah banyak file yang tak disentuh + memunculkan lint | Dijalankan ke seluruh folder | Format hanya berkas yang diubah; periksa analyzer sesudahnya |
| **4 masalah kontras warna di desain sendiri** | Teks hint/catatan redup; hijau pemasukan (terang) 3,77:1; putih di ujung cyan 2,43:1 | `test/theme_test.dart` mengukur kontras WCAG; hitung warna pengganti, jangan menebak |
| Tangkapan tak sengaja **layar utama HP pemilik** | Skrip menekan tombol Kembali *sistem* dari halaman akar aplikasi (keluar ke launcher) lalu mengambil tangkapan | Berkasnya dihapus. Jangan pernah `keyevent BACK`; pakai tombol "Kembali" milik aplikasi yang ditemukan lewat `uiautomator dump`, dan tolak bila tidak ada |
| Ketukan koordinat buta mengenai kotak warna/tombol Simpan di form (tidak tersimpan karena validasi menolak) | Koordinat diasumsikan; tombol Kembali pertama hanya menutup keyboard | Cari elemen berdasarkan teks/label lewat `uiautomator`; setelah edge-to-edge bilah navigasi berpusat di y≈2438 (bukan 2502) |
| Angka "aneh" di Ringkasan (524.133 vs 700.000) | Tangkapan diambil di tengah animasi hitung-naik | Tunggu ±1 dtk setelah layar muncul sebelum menilai angka |
| Font variabel & `FontWeight` | Bobot font variabel dipilih lewat `FontVariation('wght')`, bukan hanya `FontWeight` | Terverifikasi visual pada angka besar; periksa bobot lain bila ada kejanggalan |

## 10. Yang terbukti vs yang belum

**Terbukti**
- 164 tes lolos (unit: data/migrasi/backup/CSV/PIN/kontras; widget: alur utama, dialog, PIN, kategori, target, berulang); analyzer bersih.
- Migrasi v1→v3 dan v2→v3 dengan data nyata; migrasi v2→v3 juga di database HP sungguhan.
- Terlihat langsung di HP dengan desain baru (mode gelap): **Ringkasan, Transaksi, Anggaran, Dompet, Target, form Target Baru,
  form Catat Transaksi, Pengaturan**, serta bilah navigasi sistem yang kini transparan/gelap (edge-to-edge bekerja).
- Dua cacat visual ditemukan **hanya karena dilihat di HP** (tes tidak menangkapnya) dan sudah diperbaiki: label segmen
  "Pengeluaran" terpotong (ikon centang memakan tempat → `showSelectedIcon: false`) dan prefiks "Rp" terpisah dari angka
  (kini `Row` + `IntrinsicWidth`).
- Biometrik: dialog sidik jari tampil saat aplikasi dibuka di HP (terlihat sebagai jendela `systemui` yang mengambil fokus);
  belum diuji alur suksesnya secara sengaja.
- Build debug & release Android berhasil pada tahap-tahap sebelumnya (izin `USE_BIOMETRIC` dan `allowBackup=false` terbukti di manifest hasil merge).

**Belum terbukti**
- Tampilan **keypad PIN / layar kunci** baru lolos tes, belum dilihat (memerlukan mengunci aplikasi; PIN milik pemilik).
- **Mode terang** belum pernah dilihat di HP (percobaan terakhir terhenti karena layar HP mati). Kontras warnanya sudah diukur oleh tes.
- Dialog biometrik asli, menu Bagikan (CSV/backup), pemilih file untuk restore: belum diuji di perangkat.
- Performa build **release** dengan desain baru (blur/gradien) belum diukur; hanya debug yang dijalankan.
- APK release di `build/` (±60 MB) adalah build **lama** (tahap transaksi berulang) — **bukan** versi terbaru. Bangun ulang sebelum dibagikan.
- Belum ada penandatanganan rilis, ikon aplikasi kustom, maupun uji di perangkat lain/ukuran layar lain.

## 11. Rencana berikutnya (urutan usulan)

1. Verifikasi visual layar yang tertunda di HP; perbaiki yang janggal (termasuk mode terang).
2. Putuskan **Application ID**; siapkan signing + build release + ikon/nama.
3. Rilis **tertutup** Play Store (akun perorangan baru: syarat ± 12 penguji × 14 hari — **verifikasi ulang kebijakan**; masa tunggu
   berjalan sendiri, jadi makin cepat dimulai makin baik).
4. Enkripsi database (SQLCipher) dan backup berkata sandi; kebijakan privasi & hapus akun.
5. Notifikasi pengingat (tagihan/anggaran), edit kategori lanjutan (urutan), tren 6 bulan di Ringkasan.
6. Langganan (RevenueCat), sinkronisasi cloud (Supabase + RLS), scan struk.

## 12. Perintah penting

```bash
source ~/development/env.sh
flutter pub get
dart run build_runner build                 # wajib setelah mengubah lib/data/database.dart
flutter analyze && flutter test             # 164 tes, ±40 dtk
flutter build apk --release                 # APK release
adb -s <ip:port> exec-out screencap -p > shot.png     # lihat layar HP
flutter run -d <ip:port> --host-vmservice-port=8181   # sesi debug (hot reload: kirim SIGUSR1 ke PID di --pid-file)
```

## 13. Lokasi berkas

- Kode: `lib/` (data di `lib/data/`, tema & komponen di `lib/core/`, layar di `lib/features/`); tes: `test/`
  (harness: `test/support/harness.dart`; migrasi: `test/migration_test.dart` + `test/generated_migrations/`).
- Snapshot skema: `drift_schemas/`. Font + lisensi OFL: `assets/fonts/`. Ringkasan teknis: `README.md`.
- **Sementara (scratchpad, bisa hilang):** salinan database HP sebelum migrasi v3 di `…/scratchpad/devdb-before/`,
  tangkapan layar di `…/scratchpad/shots/`, log sesi debug `…/scratchpad/run.log`.
- Memory sesi (untuk Claude berikutnya): `~/.claude/projects/-home-dimas-Claude-Dompet-Pintar/memory/`.
