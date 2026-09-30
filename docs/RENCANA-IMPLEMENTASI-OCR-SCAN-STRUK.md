# Rencana Implementasi — Scan Struk (OCR) + Simpan Foto

> Dibuat 2026-09-28, direvisi 2026-09-29 (pivot strategi: OCR jadi fitur premium, bukan gratis — lihat §1).
> Fitur Fase 2 dari [RANCANGAN-AWAL.md](RANCANGAN-AWAL.md), dikerjakan **sebelum** lanjut ke setup Play Console
> (checklist RevenueCat/AdMob dijeda sementara di [CHECKLIST-REVENUECAT-ADMOB.md](CHECKLIST-REVENUECAT-ADMOB.md),
> sudah selesai sampai bagian 2). Fitur utang/piutang yang dibahas bersamaan ada di dokumen terpisah:
> [RENCANA-IMPLEMENTASI-UTANG-PIUTANG.md](RENCANA-IMPLEMENTASI-UTANG-PIUTANG.md) — tidak berhubungan teknis
> dengan OCR, cuma sama-sama bagian dari paket premium yang sama.

## 1. Perubahan strategi (2026-09-29)

Strategi produk berubah dari "OCR gratis sebagai differentiator" menjadi **"paket profesional terjangkau untuk
menarik pengguna dari layanan berbayar lain"** — fitur tidak kalah dari kompetitor, tapi harga jauh lebih murah
(lihat benchmark Rekapin/Finansialku di `docs/CHECKLIST-REVENUECAT-ADMOB.md` §2). Konsekuensinya:

- **OCR on-device (ML Kit + parsing heuristik) sekarang murni fitur Premium, TIDAK ADA versi gratis sama
  sekali.** Ini sebenarnya menguntungkan secara margin: ML Kit gratis dan jalan di device (nol biaya marjinal),
  jadi menggratiskannya dulu (rencana lama) berarti membuang nilai jual tanpa alasan biaya. Menguncinya di
  Premium = 100% margin dari fitur ini sendiri.
- **Simpan foto struk jadi fitur Premium baru** (sebelumnya sengaja TIDAK disimpan sama sekali di rencana lama)
  — dibalas positif oleh pemilik sebagai bagian dari paket "profesional".
- **Ekstraksi pintar via AI (dulu disebut "Fase 2") naik jadi fitur tier baru: Ultimate** (harga lebih mahal
  dari Premium, lihat §5) — bukan lagi bagian dari Premium yang sama.

### Struktur 3 tier hasil pivot ini

| Tier | Fitur terkait dokumen ini |
|---|---|
| Gratis | Tidak ada fitur scan struk sama sekali |
| **Premium** (Rp 7.500/bulan, Rp 75.000/tahun — final, diputuskan 2026-09-29) | Scan struk OCR on-device (ML Kit + heuristik) + foto struk tersimpan & ikut backup |
| **Ultimate** (Rp 12.500/bulan, Rp 125.000/tahun — final, diputuskan 2026-09-29) | Semua fitur Premium + ekstraksi otomatis lewat AI (merchant, kategori) |

## 2. Fitur Premium — OCR on-device + simpan foto

### 2.1 Package baru

- `image_picker` — kamera/galeri, menangani izin kamera Android secara internal.
- `google_mlkit_text_recognition` — OCR on-device (Text Recognition v2, skrip Latin, cukup untuk struk
  Indonesia).

Jalankan `flutter pub add image_picker google_mlkit_text_recognition` saat implementasi untuk versi terbaru yang
kompatibel — jangan hardcode versi dari dokumen ini.

### 2.2 Perubahan Android

- Tambah `<uses-permission android:name="android.permission.CAMERA"/>` di
  [android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml).
- Verifikasi ML Kit Text Recognition bisa jalan offline (app ini punya prinsip offline-first ketat) sebelum
  rilis — cek apakah model perlu di-download sekali di awal atau sudah ter-bundle.

### 2.3 Gating premium (pola yang sudah mapan di codebase)

Entry point "Scan Struk" **tetap TAMPIL** untuk pengguna gratis (dengan label "Fitur Premium"), mengikuti pola
yang sudah dipakai untuk toggle "Ingatkan saya" di transaksi berulang — bukan disembunyikan total. Tap oleh
pengguna gratis → arahkan ke `SubscriptionPage`, cek lewat `isPremiumProvider` yang sudah ada
([lib/data/providers.dart:133](../lib/data/providers.dart#L133)) — tidak ada provider baru yang dibutuhkan untuk
level Premium.

### 2.4 Alur UX

1. Entry point: tombol "Scan Struk" di `transaction_form_page.dart` (mode `create`) DAN/ATAU kartu Dashboard,
   mengikuti pola discovery-surface Agenda.
2. `image_picker` → pilih sumber (kamera/galeri) → dapat `File` foto.
3. Simpan foto ke direktori lokal app (`path_provider`, sudah jadi dependency) — **kompres/resize dulu** (mis.
   maks 1600px sisi terpanjang, JPEG quality ~80) sebelum disimpan, supaya ukuran file kecil baik untuk storage
   lokal maupun nanti diunggah ke Drive (§3). Perlu package baru untuk resize (mis. cek apakah `image_picker`
   sudah cukup lewat parameter compress bawaan sebelum menambah package image-processing terpisah).
4. `google_mlkit_text_recognition` proses foto (sebelum/sesudah kompres, pilih yang tidak menurunkan akurasi
   OCR) → `RecognizedText.text`.
5. Fungsi murni `parseReceiptText(String rawText) -> ParsedReceipt` (lihat 2.5) — pure Dart, testable tanpa ML
   Kit.
6. Simpan transaksi → path foto tersimpan di kolom baru `Transactions.receiptPath` (lihat 2.6).

**Penyesuaian desain saat implementasi (2026-09-29)**: rencana awal di sini mengusulkan parameter konstruktor
`fromScan` di `TransactionFormPage`, pola sama `fromAgenda`. Ternyata tidak cocok dengan struktur navigasi app
ini — `HomeShell` cuma punya SATU FAB bersama ("Catat", lihat
[lib/app.dart:279](../lib/app.dart#L279)), jadi tidak ada tempat alami untuk tombol terpisah yang membuka
`TransactionFormPage(fromScan: ...)` dari LUAR form yang sudah terbuka (beda dari Agenda yang punya halaman
sendiri untuk memicu `fromAgenda`). Diimplementasikan sebagai gantinya: tile "Scan Struk" **di dalam**
`TransactionFormPage` (mode `create` saja), yang saat ditekan memanggil `ref.read(receiptScannerProvider).scan()`
lalu `setState()` mengisi field yang sedang terbuka — bukan navigasi ke instance form baru. Testability yang
jadi alasan desain `fromScan`/`fromAgenda` (widget test tanpa menyentuh kamera sungguhan) tetap didapat lewat
cara lain: `ReceiptScanner` (`lib/features/transactions/receipt_scanner.dart`) adalah abstract interface yang
menyembunyikan `image_picker`+ML Kit — pola identik `NotificationSender`/`SubscriptionStatus`/
`CloudBackupService` yang sudah dipakai di app ini — sehingga tes widget memakai `FakeReceiptScanner`
(`test/support/harness.dart`) tanpa kamera/device sungguhan. Lihat `test/receipt_scan_flow_test.dart`.

### 2.5 Parser heuristik (`lib/data/receipt_parser.dart`, baru) — tidak berubah dari rencana sebelumnya

- **Total**: cari baris berkata kunci (`total`, `jumlah`, `grand total`, `total bayar`) → ambil angka terbesar di
  baris itu/berikutnya; fallback ke angka terbesar di seluruh teks.
- **Tanggal**: regex format umum ID (`dd/mm/yyyy`, `dd-mm-yyyy`, nama bulan Indonesia). Gagal → `null`, form
  default ke `DateTime.now()`.
- **Catatan/nama toko**: baris pertama non-angka sebagai tebakan kasar.
- **Kategori TIDAK ditebak** — tetap dipilih manual, bahkan untuk Premium. Tebakan kategori otomatis dicadangkan
  sebagai pembeda tier Ultimate (§4).

### 2.6 Perubahan skema (BARU — beda dari rencana sebelumnya)

Fitur simpan foto butuh migrasi, karena rencana lama sengaja tanpa skema baru:

- `Transactions.receiptPath` — `TextColumn` nullable, path relatif file lokal (bukan path absolut, supaya tidak
  rusak kalau direktori app berubah antar versi Android/perangkat). Pola sama `recurringId`/`agendaId` — nullable
  tanpa foreign key.
- **Selesai 2026-09-29: skema v6 → v7.** `Transactions` sudah ada sejak v1 (bukan tabel yang dibuat fresh di
  step migrasi manapun), jadi TIDAK kena gotcha guard `if (from >= N)` yang pernah menjangkiti
  `recurringRules`/`agendaReminders` — `addColumn` polos langsung dipakai di step `if (from < 7)`. Migrasi diuji
  di `test/migration_test.dart` (kasus v6→v7 baru: transaksi lama tanpa foto tetap utuh, transaksi baru bisa
  menautkan `receiptPath`). Fitur utang/piutang (dokumen sebelah) BELUM dikerjakan saat ini ditulis, jadi v7
  murni fitur ini — kalau urutan pengerjaan berbeda nanti, versi berikutnya perlu disesuaikan saat itu.

### 2.7 Backup foto ke Google Drive — SELESAI 2026-09-29

**Desain final berbeda dari rancangan awal di bawah** (lebih sederhana dari dugaan): `receiptPath` (path
RELATIF, mis. `receipts/<uuid>.jpg`) sudah otomatis ikut ter-backup sebagai field string biasa di JSON (drift
men-generate `toJson()`/`fromJson()` untuk semua kolom tanpa kode tambahan — sama seperti `recurringId`/
`agendaId` sebelumnya). Yang sebelumnya hilang cuma FILE foto-nya sendiri. Karena path SELALU relatif terhadap
direktori dokumen device yang sedang dipakai, **tidak perlu menulis ulang `receiptPath` sama sekali saat
restore** — cukup taruh file yang diunduh persis di path relatif yang sama pada device baru, string-nya otomatis
valid lagi. Ini menyederhanakan pekerjaan dibanding dugaan awal (tidak perlu remapping ID transaksi↔file).

Implementasi:
- **`BackupEncryptor`** ([lib/features/cloud_backup/backup_encryptor.dart](../lib/features/cloud_backup/backup_encryptor.dart))
  dapat varian biner `encryptBytes()`/`decryptBytes()` — varian String (`encrypt()`/`decrypt()`) yang sudah ada
  jadi pembungkus tipis di atasnya. Foto TIDAK boleh lewat `utf8.encode()` seperti JSON (merusak byte biner
  sembarang).
- **`CloudBackupService`** ([lib/features/cloud_backup/cloud_backup_service.dart](../lib/features/cloud_backup/cloud_backup_service.dart))
  dapat 2 method baru: `uploadFile(fileName, bytes)`/`downloadFile(fileName)` — generik per-file, dienkripsi
  otomatis dengan kunci yang SAMA dengan backup JSON utama (privasi konsisten: semua yang disimpan ke Drive
  pengguna terenkripsi, bukan cuma blob JSON). Internal `uploadBackup`/`downloadBackup` direfaktor memakai
  helper privat yang sama (`_uploadEncrypted`/`_downloadEncrypted`) — tidak ada duplikasi logika create-or-update
  file Drive.
- **`CloudBackupPage`** ([lib/features/cloud_backup/cloud_backup_page.dart](../lib/features/cloud_backup/cloud_backup_page.dart))
  jadi orkestrator (pola yang sudah ada — halaman ini yang memanggil `BackupService.export()`/`.parse()`, bukan
  service Drive): `_uploadReceiptPhotos()` jalan setelah JSON utama sukses diunggah, `_downloadReceiptPhotos()`
  jalan setelah `confirmAndRestore()` benar-benar memulihkan (bukan dibatalkan pengguna). Nama file Drive:
  `receipt_<nama-file-dari-receiptPath>.enc`.
- **`confirmAndRestore`** ([lib/features/settings/restore_confirm.dart](../lib/features/settings/restore_confirm.dart))
  sekarang mengembalikan `Future<bool>` (dulu `Future<void>`) — `true` kalau benar-benar dipulihkan, dipakai
  `CloudBackupPage` untuk tahu kapan foto perlu diunduh. Satu-satunya pemanggil lain (`SettingsPage`, restore
  dari file lokal) tidak perlu berubah — nilai kembaliannya diabaikan di sana, restore file lokal memang tidak
  pernah membawa foto (JSON lokal tidak pernah menyertakan file biner sama sekali, cuma referensi path yang
  kemungkinan tidak ada di device itu — batasan yang sudah ada, bukan regresi baru).
- **`lib/features/transactions/receipt_storage.dart`** (baru) — `resolveReceiptPath()`/`writeReceiptFile()`,
  dipakai bersama oleh alur scan (`receipt_scanner.dart`, TIDAK diubah) dan alur restore (`cloud_backup_page.dart`).
- **Kegagalan per-file tidak menggagalkan seluruhnya**: satu foto gagal unggah/unduh (jaringan putus di tengah)
  dilewati saja, tidak menggagalkan backup JSON yang sudah sukses atau transaksi lain yang berhasil dipulihkan —
  dicoba lagi di backup/restore berikutnya.
- **Kuota**: pakai kuota Google Drive milik pengguna sendiri (`appDataFolder`), bukan biaya server tambahan —
  konsisten dengan filosofi backup yang sudah ada. Kompresi di §2.4 (`image_picker`'s `maxWidth`/`imageQuality`)
  sudah menjaga ukuran file tetap kecil.

**Catatan implementasi lain**: format backup JSON (`formatVersion`) TIDAK naik untuk perubahan ini — `receiptPath`
sudah otomatis ikut lewat mekanisme drift yang sama seperti kolom lain, jadi tidak ada field baru yang perlu
ditambahkan secara eksplisit ke `BackupData`/`_checkIntegrity()` di `lib/data/backup.dart` (berbeda dari dugaan
di rancangan awal bagian ini).

### 2.8 Verifikasi manual di HP — SELESAI 2026-09-29

Diverifikasi penuh di perangkat nyata (Redmi Note 13 Pro 5G, terhubung lewat ADB atas VPN), build
`isPremiumProvider` di-hack sementara true lalu direvert bersih (pola sama sesi-sesi sebelumnya).

**Yang terbukti bekerja end-to-end:**
- Tile "Scan Struk" tampil benar sesuai status premium (tanpa label "Fitur Premium" saat premium aktif).
- Bottom sheet pilihan sumber (Kamera/Galeri), kamera native terbuka, foto diambil dan dikonfirmasi.
- ML Kit OCR berjalan sungguhan (bukan cuma di emulator/test) atas foto struk SPBU Pertamina asli.
- **Ekstraksi tanggal SEMPURNA** — "28/09/2026" di struk → terisi tepat "Senin, 28 September 2026" di form.
- Foto tersimpan lokal dengan kompresi bekerja (~304KB, dari foto kamera yang jauh lebih besar).
- Transaksi tersimpan dengan `receiptPath` terisi benar.
- **Backup Cloud ke Drive asli (akun nudadan@gmail.com) berhasil**, termasuk foto terenkripsi.
- **Simulasi ganti HP**: file foto lokal dihapus manual (`run-as` + `rm`), lalu "Pulihkan dari cloud" dijalankan
  dengan data restore sungguhan (28 transaksi, 5 dompet, 9 anggaran) — foto muncul kembali persis di path yang
  sama (`receipts/<uuid>.jpg`, ukuran byte identik), transaksi dan seluruh data lain ikut pulih benar.
- Efek samping yang juga ikut terkonfirmasi: notifikasi "Anggaran Transportasi terlampaui" otomatis terpicu
  begitu transaksi baru ini disimpan (fitur lama, bukti tidak ada regresi).

**Temuan nyata soal akurasi parser heuristik (§2.5) — dua kelemahan ditemukan di struk kompleks:**
1. **Total salah tebak**: struk SPBU ini punya tabel harga per-liter ("Subsidi Pemerintah : 5.892") SEBELUM
   bagian "Total Penjualan (Rp)" yang sebenarnya berisi total ("Dibayar Konsumen : 244.850"). Parser mengambil
   5.892, bukan 244.850. Kemungkinan urutan baris hasil `RecognizedText.text` dari ML Kit tidak selalu mengikuti
   urutan visual atas-ke-bawah untuk layout struk yang punya beberapa blok teks berdekatan — perlu diteliti
   lebih lanjut kalau ingin diperbaiki (mis. pertimbangkan posisi Y sebenarnya per baris via `TextBlock.boundingBox`,
   bukan cuma urutan string gabungan `RecognizedText.text`).
2. **Nama toko salah tebak**: heuristik "baris pertama yang bukan angka" mengambil "Shift: 1 No. Trans: 5398872"
   alih-alih "PERTAMINA" atau "SPBU SOEKARNO HATTA" — kemungkinan penyebab sama seperti di atas (urutan baris
   OCR tidak sesuai urutan visual).

**Kedua kelemahan ini TIDAK menggagalkan fitur** — pengguna mengoreksi manual sebelum simpan, persis sesuai
desain ("field yang gagal ditebak dibiarkan... bukan error"). Tapi ini bukti nyata bahwa heuristik berbasis
urutan baris string sederhana kurang andal untuk struk dengan layout kompleks (banyak sub-total sebelum total
asli) — dicatat sebagai perbaikan potensial di masa depan, bukan blocker rilis. Struk minimarket sederhana
(fixture di `test/receipt_parser_test.dart`) kemungkinan besar tetap akurat karena strukturnya lebih linear.

#### Perbaikan diterapkan (2026-09-29) + verifikasi ulang di HP

Dua perbaikan diterapkan di hari yang sama:
1. `lib/features/transactions/receipt_scanner.dart` — baris hasil OCR sekarang diurutkan ulang berdasarkan
   posisi Y sebenarnya (`TextLine.boundingBox.top` dari semua blok, bukan urutan string gabungan
   `RecognizedText.text`) sebelum dikirim ke parser.
2. `lib/data/receipt_parser.dart` — `_extractAmount` sekarang 2 tingkat: kata kunci spesifik ("dibayar", "total
   bayar", "grand total", "total belanja") dicoba DULU sebelum fallback ke kata kunci generik ("total"/"jumlah"
   polos) yang sering cuma label bagian. Kasus SPBU asli di atas ditambahkan sebagai test baru di
   `test/receipt_parser_test.dart` (lolos: sekarang mengembalikan 244.850, bukan 5.892).

**Verifikasi ulang di HP dengan struk YANG SAMA (SPBU Pertamina)**: hasil membaik tapi belum sempurna —
nominal jadi **250.000** (nilai "CASH", bukan lagi 5.892 yang sama sekali salah arah, tapi juga bukan 244.850
"Dibayar Konsumen" yang benar). Dugaan: struk ini berlayout 2-kolom (label rata-kiri, nominal rata-kanan
terpisah jauh) — ML Kit kemungkinan mendeteksi kolom label dan kolom nominal sebagai blok terpisah, sehingga
mengurutkan berdasarkan Y saja tidak cukup untuk memasangkan label dengan nilainya yang benar pada baris yang
sama. Memperbaiki ini dengan tuntas butuh penataan ulang tabel 2D (pencocokan posisi X *dan* Y), bukan sekadar
urutkan-berdasarkan-Y — pekerjaan lanjutan yang lebih besar, **sengaja tidak dikejar lebih jauh** di sesi ini
setelah didiskusikan dengan pemilik (biaya riset lebih lanjut vs manfaat, mengingat jaring pengaman koreksi
manual sudah menangani kasus ini).

**Verifikasi ulang dengan struk BERBEDA (Indomaret, satu-kolom, lebih umum)**: hasil **sempurna** —
nominal Rp 40.100 (persis "TOTAL BELANJA : 40.100"), tanggal Senin 28 September 2026 (persis "28.09.26"),
catatan "PTINDOMARCO PRISATAMA" (nyaris persis "PT.INDOMARCO PRISMATAMA", beda dikit karena salah baca OCR
huruf, bukan bug logika). **Kesimpulan**: perbaikan ini terbukti bekerja sangat baik untuk struk retail standar
satu-kolom (mayoritas struk sehari-hari — minimarket, resto, dll., sesuai fixture di
`test/receipt_parser_test.dart`) — kelemahan yang tersisa spesifik untuk struk 2-kolom kompleks seperti SPBU,
sudah didokumentasikan sebagai batasan yang diketahui, bukan regresi baru.

### 2.9 Testing — selesai untuk bagian yang sudah dikerjakan

- `parseReceiptText()`: **selesai**, `test/receipt_parser_test.dart` — 6 kasus (Indomaret, Alfamart, resto,
  SPBU, teks kosong, teks tanpa angka), semua lolos.
- Widget test alur scan: **selesai**, `test/receipt_scan_flow_test.dart` — 3 kasus (belum premium diarahkan ke
  `SubscriptionPage` tanpa memanggil scanner sama sekali; premium berhasil mengisi nominal/tanggal/catatan/tanda
  foto tersimpan lalu benar-benar tersimpan ke `Transactions.receiptPath`; premium tapi pengguna membatalkan
  pemilihan foto tidak mengubah apa pun). Memakai `FakeReceiptScanner` baru di `test/support/harness.dart`
  (pola sama `FakeCloudBackupService`/`FakeNotificationSender`) — tidak menyentuh kamera/ML Kit sungguhan.
- Migrasi skema v6→v7: **selesai**, kasus baru di `test/migration_test.dart`.
- `BackupEncryptor.encryptBytes`/`decryptBytes`: **selesai**, 2 kasus baru di `test/backup_encryptor_test.dart`
  (round-trip byte biner sembarang bukan UTF-8 valid; kunci salah gagal decrypt).
- Sinkronisasi foto ke Drive lewat `CloudBackupPage`: **selesai**, `test/receipt_cloud_sync_test.dart` — 3 kasus
  pure function (`resolveReceiptPath`/`writeReceiptFile`) + 1 kasus integrasi widget penuh (backup lewat UI →
  foto masuk ke `FakeCloudBackupService.storedFiles` → file lokal dihapus untuk mensimulasikan "perangkat lain"
  → restore lewat UI → foto benar-benar tertulis ulang dengan isi yang sama). **Gotcha ditemukan saat menulis tes
  ini**: I/O nyata (`File.delete()`/`.exists()`/`.readAsBytes()`) yang di-`await` LANGSUNG di badan `testWidgets`
  (bukan lewat `tester.runAsync()`) menggantung SELAMANYA — `testWidgets` berjalan di zona fake-async yang tidak
  pernah mengalirkan callback real I/O tanpa `runAsync` membuka jendela ke zona nyata (persis alasan `settle()`
  di `test/support/harness.dart` memakai `tester.runAsync(() => Future.delayed(...))` berulang). Pelajaran baru,
  dicatat di memory proyek supaya tidak terulang di file foto/tes I/O lain nanti.
- Integrasi kamera + ML Kit sungguhan **tidak bisa diuji lewat `flutter test`** (butuh native platform channel)
  — **verifikasi manual di HP masih wajib dan belum dilakukan**, termasuk cek mode offline (ML Kit butuh model
  ter-download/bundled) dan hasil OCR di struk asli (bukan cuma teks fixture buatan tangan).

## 3. Fitur Ultimate — ekstraksi pintar via AI

Bangun DI ATAS fitur Premium (§2) yang sama — teks OCR yang sudah diekstrak dikirim ke backend untuk diproses
LLM, tidak ada alur capture/OCR terpisah.

### 3.1 Gating tier (BARU — desain RevenueCat dua-entitlement)

- Produk langganan "Ultimate" di Play Console/RevenueCat dikaitkan ke **dua** entitlement: `premium` DAN
  `ultimate`. Produk "Premium" biasa cuma dikaitkan ke `premium`.
- Efeknya: `isPremiumProvider` yang sudah ada ([lib/data/providers.dart:133](../lib/data/providers.dart#L133))
  **tidak perlu diubah** — pengguna Ultimate otomatis lolos semua gate premium yang sudah ada di seluruh app.
- Tambah provider baru `isUltimateProvider` (pola identik `isPremiumProvider`, cek entitlement `ultimate`) +
  konstanta `kUltimateEntitlementId = 'ultimate'` di
  [lib/features/subscription/revenuecat_config.dart](../lib/features/subscription/revenuecat_config.dart) —
  murni tambahan, tidak mengubah kode yang sudah ada.

### 3.2 Infrastruktur backend (belum berubah dari analisis sebelumnya)

App ini tidak punya backend sama sekali. Fitur ini butuh backend kecil pertama kalinya:
1. Terima teks hasil OCR (bukan gambar) + bukti pengguna ini Ultimate.
2. Panggil **Claude Haiku 4.5** (API key di backend, TIDAK PERNAH di app).
3. Rate-limit per pengguna.
4. Kembalikan hasil terstruktur (merchant, tebakan kategori).

### 3.3 Keputusan (final 2026-09-29) dan implementasi

1. **Platform backend: Cloudflare Workers** — kode di `backend/receipt-extraction-worker/` (lihat README-nya
   untuk deploy). Tanpa server yang harus dirawat, free tier cukup.
2. **Verifikasi entitlement**: app mengirim `appUserId` RevenueCat (ID anonim, sulit ditebak); Worker
   memanggil RevenueCat REST `GET /v1/subscribers/{id}` dengan **secret key** dan memeriksa entitlement
   `ultimate` aktif (`expires_date` null / di masa depan). Gagal cek = ditolak (fail closed).
3. **Rate limit: 60 scan/bulan per pengguna**, penghitung di Workers KV (kunci `usage:{id}:{YYYY-MM}`,
   kedaluwarsa 35 hari). Hanya ekstraksi yang berhasil dihitung. Lewat batas → 429 → app menampilkan
   "Kuota scan AI bulan ini habis" dan tetap memakai hasil heuristik.
4. **Data yang dikirim**: teks OCR (maks 4000 karakter, BUKAN foto) + daftar kategori aktif pengguna
   (id + nama; sub-kategori "Induk › Anak"). Model diminta lewat tool-use paksa (`record_receipt`) dengan
   `enum` id kategori, jadi keluarannya terstruktur; server & app sama-sama membuang `categoryId` di luar
   daftar. Teks struk diperlakukan sebagai data (anti prompt-injection di system prompt).
5. **Client**: `AiExtractionService` (`lib/features/ai/`), dipanggil dari `_scanReceipt()` SETELAH heuristik
   mengisi form, hanya untuk pengguna Ultimate. Hasil AI menimpa catatan/kategori hanya bila belum diubah
   pengguna selama menunggu. Timeout 15 dtk; semua kegagalan = diam (heuristik tetap). Persetujuan sekali
   ("Isi otomatis dengan AI?") disimpan di `KeyValueStore` (`ai_extraction_consent`).
6. **Konfigurasi build**: `--dart-define=AI_EXTRACTION_URL=<url worker>/extract`; kosong = fitur mati diam-diam.

### 3.4 Biaya AI — bukan faktor pembatas harga

Claude Haiku 4.5 ($1,00/$5,00 per 1M token), ~800 token input + ~200 token output per scan ≈ **Rp 29/scan**
(kurs ilustratif Rp16.000/USD). Bahkan pengguna sangat aktif (100 scan/bulan) cuma menambah ±Rp 2.900/bulan
biaya AI — jauh di bawah selisih harga Premium→Ultimate berapa pun angkanya nanti. **Harga Ultimate adalah
keputusan value-based (seberapa besar orang mau bayar untuk kenyamanan auto-fill), bukan soal menutup biaya AI.**

## 4. Harga — final (diputuskan 2026-09-29)

- **Premium: Rp 7.500/bulan, Rp 75.000/tahun**
- **Ultimate: Rp 12.500/bulan, Rp 125.000/tahun**

Angka tahunan mengikuti rasio 10x bulanan (diskon ~17%) yang konsisten dipakai di semua keputusan harga
sebelumnya — belum dikonfirmasi eksplisit oleh pemilik untuk pasangan angka ini secara spesifik, cek ulang
sebelum submit ke Play Console (lihat `docs/CHECKLIST-REVENUECAT-ADMOB.md` §2 untuk riwayat revisi lengkap).
Kedua angka ini di bawah kompetitor terdekat (Rekapin Rp 15.000/bulan, satu tier) — konsisten dengan strategi
"paket profesional terjangkau" di §1, sekaligus tetap ada jarak harga berarti antara Premium dan Ultimate untuk
mendorong upgrade.

## 5. Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| Model ML Kit butuh download saat pertama pakai, gagal kalau offline | Verifikasi di HP mode pesawat sebelum rilis |
| Heuristik total/tanggal salah tebak | User selalu review sebelum simpan — kesalahan tebakan cuma inconvenience |
| Backup foto adalah arsitektur baru (biner, bukan cuma JSON) — risiko bug restore paling tinggi di seluruh rencana ini | Test khusus skenario restore-di-device-lain (§2.8) sebelum dianggap selesai, jangan cuma widget test biasa |
| Kuota Drive pengguna terkuras kalau foto tidak dikompres | Kompresi wajib sebelum simpan (§2.4), bukan opsional |
| Ultimate butuh verifikasi entitlement dari backend yang aman, desain belum final | Jangan mulai §3 sebelum §3.3 butir 2 selesai — fitur Premium (§2) tidak bergantung padanya sama sekali |
| Biaya AI membengkak dari penyalahgunaan | Rate limit per pengguna (§3.3 butir 3), wajib sebelum Ultimate live |

## 6. Checklist implementasi (centang lintas sesi)

### Fitur Premium — OCR + simpan foto
- [x] `flutter pub add image_picker google_mlkit_text_recognition` — **selesai 2026-09-29**
      (`image_picker: 1.2.3`, `google_mlkit_text_recognition: 0.17.1`)
- [x] Tambah `CAMERA` permission di `AndroidManifest.xml` — **selesai**
- [x] `lib/data/receipt_parser.dart` — `ParsedReceipt` + `parseReceiptText()` — **selesai**
- [x] `test/receipt_parser_test.dart` — **selesai**, 6 kasus (lebih dari minimal 4 yang direncanakan)
- [x] Kompresi/resize foto sebelum simpan lokal — **selesai**, pakai parameter bawaan `image_picker`
      (`maxWidth`/`imageQuality`), tidak perlu package tambahan seperti diduga di §2.4
- [x] Skema: `Transactions.receiptPath` — **selesai**, skema naik v6→v7
- [x] ~~Tambah param `fromScan`~~ — **desain diganti saat implementasi** (lihat catatan di §2.4): tile di dalam
      form + `ReceiptScanner` interface + `FakeReceiptScanner`, bukan parameter konstruktor terpisah
- [x] Widget test alur scan — **selesai**, `test/receipt_scan_flow_test.dart` (3 kasus)
- [x] Halaman/alur capture: pilih sumber → OCR → isi form — **selesai** (`lib/features/transactions/receipt_scanner.dart`
      + tile "Scan Struk" di `transaction_form_page.dart`)
- [x] Entry point UI (form transaksi), gating premium (tampil untuk gratis, label "Fitur Premium") — **selesai**.
      Dashboard quick-action ("DAN/ATAU" di rencana awal) BELUM ditambahkan — entry point form transaksi sudah
      cukup untuk fungsi inti, bisa menyusul kalau dirasa perlu jalur discovery kedua
- [x] Backup: unggah foto ke Drive saat backup, unduh saat restore — **selesai 2026-09-29** (lihat §2.7; ternyata
      TIDAK perlu reassign path atau naikkan `formatVersion`, lebih sederhana dari dugaan)
- [x] Test backup/restore foto termasuk skenario device lain — **selesai**, `test/receipt_cloud_sync_test.dart`
- [x] `flutter analyze` + `flutter test` penuh — **selesai 2026-09-29**, **374 tes lolos**, analyze bersih (1 info
      lint lama tidak terkait)
- [x] Verifikasi manual di HP: scan struk sungguhan + cek backup/restore foto sungguhan — **selesai 2026-09-29**
      (lihat §2.8 untuk detail lengkap + 2 temuan akurasi parser). Cek mode offline (ML Kit tanpa jaringan)
      BELUM sempat dilakukan di sesi ini — item kecil yang masih terbuka.
- [ ] Update `docs/GAP-ANALISA-2026-09-24.md` — OCR bisa pindah ke ✅ (fungsional selesai & teruji; akurasi
      parser untuk struk kompleks jadi catatan pengembangan lanjutan, bukan blocker)

### Fitur Ultimate — ekstraksi AI (jangan mulai sebelum §3.3 selesai & harga §4 dikunci)
- [x] Putuskan harga Ultimate (§4) — **selesai 2026-09-29**: Rp 12.500/bulan, Rp 125.000/tahun
- [x] Putuskan platform backend — Cloudflare Workers (§3.3)
- [x] Desain verifikasi entitlement `ultimate` yang aman dari backend — REST RevenueCat server-ke-server (§3.3)
- [x] Putuskan rate limit per pengguna — 60 scan/bulan
- [x] Tambah `isUltimateProvider` + `kUltimateEntitlementId` di kode — **selesai 2026-09-29**
- [ ] Setup produk "Ultimate" di RevenueCat dengan 2 entitlement (`premium` + `ultimate`)
- [x] Bangun backend function (teks → Haiku 4.5 → JSON terstruktur) — **selesai 2026-09-29**, 9 tes handler; panggilan ke Anthropic/RevenueCat sungguhan BELUM diuji (butuh kunci pemilik)
- [x] Integrasi client: kirim teks OCR ke backend untuk pengguna Ultimate, fallback ke heuristik kalau
      gagal/offline — **selesai 2026-09-29** (`test/ai_receipt_extraction_test.dart`, 13 tes)
- [ ] Deploy Worker + set secret (`ANTHROPIC_API_KEY`, `REVENUECAT_SECRET_KEY`) + KV namespace — oleh pemilik
- [x] Revisi kebijakan privasi untuk aliran data baru ini (ditulis ulang 2026-09-30: docs/kebijakan-privasi/index.html; tinggal dihosting ke URL publik)
- [ ] Verifikasi biaya sungguhan setelah live
- [ ] Verifikasi manual di HP dengan akun Ultimate sungguhan
