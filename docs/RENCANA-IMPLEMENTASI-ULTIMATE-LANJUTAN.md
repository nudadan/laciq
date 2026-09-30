# Rencana Implementasi — Kelanjutan Tier Ultimate

> Dibuat 2026-09-30 dari audit di [MATRIKS-FITUR-PAKET.md §6b](MATRIKS-FITUR-PAKET.md). Melengkapi §3 di
> [RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md](RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md) (yang mencatat kode Ultimate awal).
> Belum ada yang dikerjakan; tidak ada perubahan kode saat dokumen ini ditulis. Status centang ada di §7.

## 0. Ringkasan dan urutan

| Fase | Isi | Menyelesaikan | Jenis | Bergantung pada |
|---|---|---|---|---|
| **A** | Jalur upgrade dan UI tier | T1, T2, T3, T4, T5 | Kode Flutter | — |
| **B** | Ganti penyedia AI ke Gemini (B0) dan AI ikut mengekstrak total dan tanggal (B1–B3) | keputusan penyedia 2026-09-30, kesenjangan rancangan | Kode Worker + Flutter | — (paralel dengan A) |
| **C** | Pengerasan Worker | T6 | Kode Worker | — (paralel) |
| **D** | Operasional: Play, RevenueCat, deploy Worker | 6 langkah penghalang | Konsol, bukan kode | A dan B selesai dan lulus tes |
| **E** | Rilis 4 dan uji nyata | verifikasi | Build + HP | A–D |

**Fitur Ultimate kedua (ditambahkan 2026-09-30): multi buku kas.** Rencananya terpisah di
[RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md](RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md) (fase F0–F7, perubahan skema v10 dan
backup v7). Fase A–E di dokumen ini tidak bergantung padanya; hubungannya hanya tiga: (1) teks `_ultimateBenefits`
(A3) harus memuat kedua fitur, (2) keputusan K3/K7 soal harga dan rilis Ultimate (apakah menunggu buku kas), dan
(3) langkah D7 (listing Play) harus menyebut buku kas bila ikut dirilis.

**Aturan urutan:** jangan menjual Ultimate (fase D) sebelum A2 selesai, karena tanpa penggantian produk pelanggan
Premium yang membeli Ultimate membayar dua langganan. Fase D bisa dimulai setelah A dan B, sedangkan C boleh menyusul
selama batas biaya (C1) sudah dipasang sebelum Worker dibuka untuk pengguna.

## 1. Keputusan yang menunggu pemilik

| # | Keputusan | Rekomendasi |
|---|---|---|
| K1 | Upgrade Premium → Ultimate: boleh lintas periode (mis. Premium tahunan → Ultimate bulanan)? | Izinkan semua kombinasi; mode penggantian `chargeProratedPrice` (dibayar selisih untuk sisa siklus). Kombinasi lintas periode makin rumit, jadi uji ketiganya di §6 |
| K2 | Downgrade Ultimate → Premium lewat aplikasi? | Tidak. Arahkan ke "Kelola" di Play Store (perubahan berlaku di akhir siklus) |
| K3 | Harga Ultimate Rp12.500/Rp125.000 sudah final? | Konfirmasi ulang sebelum D1 (rencana lama minta dicek) |
| K4 | Rincian item struk (bukan hanya total) masuk lingkup? | Tidak sekarang. Skema database tidak punya tabel item, dan nilainya belum jelas. Catat sebagai ide, bukan rencana |
| K5 | Batas harian di samping kuota 60/bulan (C1)? | Ya, 15 scan/hari, supaya satu akun bocor tidak menghabiskan sebulan dalam satu jam |
| K6 | Penyedia AI (diputuskan pemilik 2026-09-30: **Google Gemini**) | **Gemini paid tier**, model dipilih lewat uji kepala-ke-kepala di B3 (kandidat `gemini-3.1-flash-lite` dan `gemini-3.8-flash`, pembanding Claude Haiku 4.5). Kembali ke Haiku 4.5 hanya bila Haiku jelas lebih akurat pada total. Rincian di B0 |

## 2. Fase A — Jalur upgrade dan UI tier (Flutter)

### A1. Model tier dan produk aktif
- Tambah `enum ActiveTier { free, premium, ultimate }` dan `subscriptionTierProvider` di
  `lib/data/providers.dart`, diturunkan dari `isPremiumProvider` dan `isUltimateProvider` yang sudah ada
  (tanpa panggilan jaringan baru).
- Tambah ke antarmuka `SubscriptionStatus` (`subscription_status.dart`): `Future<String?> activeSubscriptionProductId()`.
  Implementasi RevenueCat: `Purchases.getCustomerInfo()` lalu
  `entitlements.active[kPremiumEntitlementId]?.productIdentifier`. Ini produk yang akan digantikan (A2).
- Perbarui `FakeSubscriptionStatus` (`test/support/harness.dart`) supaya bisa mengembalikan produk aktif dan tier.

### A2. Penggantian produk saat upgrade (T2, prioritas tertinggi)
- Di `RevenueCatSubscriptionStatus.purchase()`: bila paket target `tier == ultimate` dan pengguna sudah Premium
  (bukan Ultimate), lewatkan
  `PurchaseParams.package(native, productChangeInfo: StoreProductChangeInfo(oldProductId, replacementMode: StoreReplacementMode.chargeProratedPrice))`.
  API ada di `purchases_flutter 10.13.1` (`lib/models/store_product_change.dart`); parameter `googleProductChangeInfo`
  lama sudah deprecated, jangan dipakai.
- `oldProductId` berasal dari A1. **Perlu diverifikasi saat uji (§6)**: apakah SDK menghendaki ID langganan
  (`dompetku_premium`) atau `langganan:base-plan` (`dompetku_premium:monthly`). Dokumentasikan hasilnya di sini.
- Tanpa produk aktif (pengguna gratis) perilaku tidak berubah.
- Tes unit: fungsi murni `shouldReplaceProduct(activeTier, targetTier)` (pola sama `shouldConfigureRevenueCat`),
  ditambah tes bahwa pembelian dari gratis tidak memakai `productChangeInfo`.

### A3. Tampilan tier (T1 dan T3)
- `SettingsPage` (`_SubscriptionTile`, `settings_page.dart:440`) menjadi tiga kondisi:
  | Tier | Judul | Subjudul | Aksi |
  |---|---|---|---|
  | Gratis | Upgrade ke Premium | (tetap) | buka `SubscriptionPage` |
  | Premium | DompetKu Premium aktif | Tanpa iklan · Upgrade ke Ultimate untuk isi struk otomatis dengan AI | tombol "Upgrade" membuka `SubscriptionPage(upgradeOnly: true)`, plus "Kelola" |
  | Ultimate | DompetKu Ultimate aktif | Tanpa iklan · Ekstraksi struk AI | "Kelola" saja |
  Tombol "Upgrade" hanya tampil bila `kAiExtractionUrl` tidak kosong **dan** paket Ultimate ada di offering
  (jangan menawarkan produk yang belum bisa dibeli).
- `SubscriptionPage`: parameter `upgradeOnly` menyembunyikan kartu Premium dan mengganti judul menjadi "Upgrade ke
  Ultimate" dengan kalimat pengantar sendiri. Untuk pengguna gratis, judul tetap "DompetKu Premium".
- Konsistensi teks: perbarui `_ultimateBenefits` agar menyebut total dan tanggal setelah B selesai.

### A4. Sisa kuota (T4)
- `AiReceiptExtraction` mendapat field `remaining` (int?), diisi dari respons Worker.
- Setelah ekstraksi sukses, `TransactionFormPage` menampilkan `notify(...)` singkat hanya bila `remaining <= 10`:
  "Sisa scan AI bulan ini: N". Tidak setiap kali, supaya tidak berisik. Pesan 429 yang sudah ada tetap.
- Tes: kasus `remaining` di atas dan di bawah ambang di `test/ai_receipt_extraction_test.dart`.

### A5. Ajakan Ultimate di alur Scan struk (T5)
- Setelah scan sukses dan bila tier Premium (bukan Ultimate), tampilkan satu baris kecil di bawah tile Scan Struk:
  "Isi toko & kategori otomatis dengan AI — Ultimate" yang membuka `SubscriptionPage(upgradeOnly: true)`.
- Aturan: hanya bila syarat A3 terpenuhi (backend terkonfigurasi dan paket ada); muncul paling sering sekali per
  sesi (simpan flag di memori, bukan `KeyValueStore`); bisa ditutup dan tidak muncul lagi setelah ditutup 2 kali
  (tersimpan di `KeyValueStore`).

## 3. Fase B — AI mengekstrak total dan tanggal (Worker + Flutter)

Tujuan: menutup kesenjangan "AI hanya toko dan kategori" dan menolong kasus yang terbukti gagal di heuristik
(total salah pada struk SPBU 2-kolom, lihat OCR-SCAN-STRUK §2.8).

### B0. Ganti penyedia AI: Claude Haiku 4.5 → Google Gemini (keputusan 2026-09-30)

Kopling ke Anthropic terisolasi: `src/anthropic.ts` (pemanggil model), `Env.ANTHROPIC_API_KEY` di `src/index.ts`,
dependensi `@anthropic-ai/sdk`, dan README. `handler.ts` dan `test/handler.test.ts` tidak tahu soal penyedia (fungsi
`extract` disuntikkan), jadi penggantian cukup kecil.

**Ringkasan perbandingan** (sumber: halaman harga dan ketentuan resmi Google dan Anthropic, dibaca 2026-09-30;
harga bisa berubah, cek ulang saat implementasi):

| Aspek | Claude Haiku 4.5 | Gemini |
|---|---|---|
| Harga per 1 juta token (masuk/keluar) | $1 / $5 | 2.5 Flash-Lite $0,10/$0,40 · 3.1 Flash-Lite $0,25/$1,50 · 3.5 Flash-Lite $0,30/$2,50 · 3.8 Flash $0,75/$3,75 (naik jadi $1,50/$7,50 mulai 1 Jan 2027) |
| Perkiraan per scan (800 masuk, 200 keluar, Rp16.000/USD) | ≈ Rp29 | ≈ Rp3 (2.5 FL) · Rp8 (3.1 FL) · Rp12 (3.5 FL) · Rp22 (3.8 F; ≈ Rp43 mulai 2027) |
| Data untuk pelatihan | Tidak secara bawaan (produk komersial) | Free tier: **ya** + tinjauan manusia + dilarang untuk data pribadi/sensitif. Paid tier: **tidak** |
| Stabilitas API | Stabil | Dokumentasi menonjolkan endpoint `interactions` dan menyebut "breaking changes (May 2026)"; status `generateContent` tidak dinyatakan di halaman yang dibaca |
| Siklus model | Satu model | Beberapa generasi bersamaan; model lama cenderung dipensiunkan |

**Aturan yang mengikat:**
1. **Wajib paid tier** untuk data pengguna mana pun. Free tier hanya untuk uji dengan teks struk buatan atau yang
   sudah disamarkan (tanpa nama, nomor kartu, alamat). Data penguji nyata tidak boleh lewat free tier.
2. Kunci API dibuat di **project Google Cloud terpisah** dari project OAuth (`dompetku-509508`), dengan billing dan
   anggaran sendiri. Kebocoran kunci tidak boleh menyentuh login Google.
3. Ketentuan Gemini menyatakan aplikasi yang ditujukan bagi atau kemungkinan diakses pengguna di bawah 18 tahun tidak
   boleh memakai API. Periksa jawaban target audiens dan rating konten DompetKu di Play Console sebelum D1.

**Langkah:**
- **B0.1 Verifikasi API yang berlaku** sebelum menulis kode: endpoint (`generateContent` atau `interactions`), nama
  field keluaran terstruktur (dokumentasi terbaru: `response_format` dengan `schema`; `enum` didukung; nullable lewat
  tipe `["string","null"]`), header kunci (`x-goog-api-key`), dan bentuk respons berisi penggunaan token. Uji dengan
  satu permintaan `curl` memakai kunci uji dan teks struk buatan.
- **B0.2 `src/gemini.ts`**: pemanggil lewat `fetch` (tanpa SDK), menjaga tanda tangan
  `makeExtractor(apiKey, model)` sehingga `handler.ts` tidak berubah. Keluaran terstruktur dengan `enum` id kategori
  seperti sekarang; parsing defensif (JSON rusak, field hilang, id di luar `enum` menjadi `null`). Matikan atau
  minimalkan mode *thinking* (token berpikir biasanya ditagih sebagai token keluaran; verifikasi di B0.1).
- **B0.3 Konfigurasi**: `Env.GEMINI_API_KEY` (secret) menggantikan `ANTHROPIC_API_KEY`; ID model di
  `wrangler.toml` sebagai `AI_MODEL` (bukan konstanta di kode) supaya penggantian model tidak perlu rilis kode. Log
  jumlah token dari respons ke log Worker untuk mengukur biaya nyata (bahan E3).
- **B0.4 Tes**: tes unit `gemini.ts` dengan `fetch` palsu (respons valid, JSON rusak, field hilang, id kategori di
  luar daftar, HTTP 4xx/5xx). Tes handler tidak diubah.
- **B0.5 Bersih-bersih setelah B3 memilih**: bila Gemini menang, hapus `src/anthropic.ts` dan dependensi
  `@anthropic-ai/sdk`, perbarui README Worker. Bila Haiku menang, biarkan berkas apa adanya dan cukup catat hasilnya.
- **B0.6 Skrip evaluasi** (`backend/receipt-extraction-worker/eval/`): membaca kumpulan teks struk + nilai yang
  diharapkan, memanggil tiap model kandidat, dan mencetak tabel benar/salah per kolom serta token terpakai. Dipakai
  di B3; tidak ikut di-deploy.

### B1. Worker (`backend/receipt-extraction-worker/`)
- Perluas skema keluaran (tool `record_receipt` bila memakai Claude, skema respons Gemini bila memakai Gemini) dan
  `Extraction` dengan `total: number | null` (Rupiah bulat) dan
  `date: string | null` (`YYYY-MM-DD`).
- Validasi di server, jangan percaya keluaran model (pola sama `categoryId`): `total` bilangan bulat
  1 ≤ n ≤ 1.000.000.000; `date` valid dan dalam rentang [hari ini − 5 tahun, hari ini + 1 hari]; selain itu `null`.
- Perbarui system prompt: instruksi memilih nilai yang benar-benar dibayar (bukan tunai/kembalian/subsidi/sub-total),
  serta tetap memperlakukan teks struk sebagai data (anti prompt-injection).
- Respons menjadi `{ merchant, categoryId, total, date, remaining }`. Klien lama mengabaikan field baru, jadi tidak
  ada kompatibilitas mundur yang rusak.
- Tes handler: tambah kasus total di luar rentang, tanggal tidak valid, dan nilai `null`.

### B2. Klien
- `AiReceiptExtraction` mendapat `total` (int?) dan `date` (DateTime?); parsing defensif di
  `HttpAiExtractionService` (tipe salah = `null`).
- Di `_enhanceWithAi`: terapkan `total` dan `date` **hanya bila** kolom belum diubah pengguna sejak scan (snapshot
  awal, sama seperti `note` dan `category`). Jika total AI berbeda dari total heuristik, AI menang, karena itu
  tujuan fitur ini.
- Tes: total AI menimpa nilai heuristik yang salah; tidak menimpa bila pengguna sudah mengetik.

### B3. Evaluasi akurasi dan pemilihan model (sebelum rilis)
- Kumpulkan minimal 10 struk nyata (termasuk SPBU 2-kolom yang sudah ada fixture-nya, minimarket, restoran). Samarkan
  teks (nama, nomor kartu, alamat) sebelum dipakai, karena kandidat Gemini akan diuji lewat free tier atau paid tier.
- Jalankan skrip B0.6 untuk: heuristik saja, **Gemini 3.1 Flash-Lite**, **Gemini 3.8 Flash** (batas atas akurasi), dan
  **Claude Haiku 4.5** (pembanding). Bandingkan total, tanggal, toko, dan kategori per struk. Simpan tabel hasil di §8.
- **Aturan pemilihan:** pilih model **termurah** yang benar pada total di ≥ 8 dari 10 struk **dan** tidak lebih buruk
  dari heuristik pada struk mana pun yang heuristiknya sudah benar. Bila ada dua model seimbang, pilih Gemini (biaya
  lebih rendah, satu akun Google). Bila hanya Haiku yang lolos, pakai Haiku; selisih ±Rp1.200 per pengguna aktif per
  bulan tidak sebanding dengan total yang salah. Bila tidak ada yang lolos, tinjau prompt, jangan rilis dengan klaim
  "otomatis".
- Hitung ulang biaya per scan dari token nyata (bukan perkiraan) dan bandingkan dengan pendapatan bersih Ultimate
  bulanan (±Rp10.600 setelah potongan Play ±15%). Biaya 60 scan harus jauh di bawahnya.
- Kebijakan privasi berubah pada penyedia (Anthropic → Google), bukan pada jenis data: yang dikirim tetap teks OCR +
  daftar kategori. Lihat D8.

## 4. Fase C — Pengerasan Worker (T6)

| ID | Langkah | Alasan |
|---|---|---|
| C1 | Batas harian per pengguna (15/hari) di samping 60/bulan; kunci KV `usage:{id}:{YYYY-MM-DD}` kedaluwarsa 2 hari | Membatasi kerugian bila satu ID bocor |
| C2 | Cache hasil pengecekan entitlement di KV selama ±5 menit (hasil `true`); hasil `false` disimpan ±1 menit | Mengurangi panggilan ke RevenueCat dan mencegah permintaan sampah dari non-Ultimate menguras batas REST RevenueCat |
| C3 | Pembatasan laju per IP lewat fitur *Rate limiting* Cloudflare (atau aturan WAF) pada rute `/extract` | Melindungi dari lonjakan sebelum sampai ke logika aplikasi |
| C4 | Pasang anggaran dan peringatan biaya di Google Cloud Billing pada project khusus kunci Gemini (B0). Bila Haiku yang menang di B3, pasang batas pengeluaran di konsol Anthropic | Jaring pengaman terakhir untuk biaya |
| C5 | Penghitung atomik (Durable Object) | **Tidak sekarang.** Selisih akibat permintaan paralel kecil (paling banyak beberapa scan di atas 60). Kerjakan hanya bila terbukti disalahgunakan |
| C6 | Catat sebagai risiko yang diterima: `appUserId` bukan bukti kepemilikan | Bukti kepemilikan sungguhan butuh login/atestasi (mis. Play Integrity), terlalu berat untuk tahap ini |

## 5. Fase D — Operasional (konsol, bukan kode)

Dikerjakan setelah A dan B lulus tes. Setiap langkah yang mengubah konsol saya lakukan dengan konfirmasi Anda per
formulir, seperti pada Premium.

1. **Deploy Worker.** Dari `backend/receipt-extraction-worker/` (lihat README-nya): buat KV namespace `RATE_LIMIT`,
   isi secret `GEMINI_API_KEY` (atau `ANTHROPIC_API_KEY` bila Haiku yang menang di B3) dan `REVENUECAT_SECRET_KEY`
   (kunci **secret** v1 dari RevenueCat, bukan kunci `goog_`), atur `AI_MODEL` di `wrangler.toml`, lalu
   `wrangler deploy`. Butuh akun Cloudflare dan kunci API milik Anda: untuk Gemini, kunci dari project Google Cloud
   terpisah dengan **billing aktif (paid tier)** dan anggaran (C4). Saya tidak boleh mengetik kunci itu sendiri.
   Uji dengan `curl` memakai `appUserId` uji: harus 403 `not_ultimate` sebelum produk ada.
2. **Produk Play `dompetku_ultimate`.** Langganan baru dengan base plan `monthly` (Rp12.500) dan `yearly`
   (Rp125.000), ketersediaan hanya Indonesia (pelajaran dari Premium: harga wajib per wilayah), lalu aktifkan.
3. **RevenueCat — produk.** Impor `dompetku_ultimate:monthly` dan `:yearly` dari Play Store.
4. **RevenueCat — entitlement.** Buat entitlement `ultimate`. Kaitkan kedua produk Ultimate ke **`ultimate` dan
   `premium`** (supaya semua gate Premium ikut terbuka).
5. **RevenueCat — offering `dompetku`.** Tambah dua paket dengan **identifier khusus** `ultimate_monthly` dan
   `ultimate_annual` (identifier standar `$rc_monthly`/`$rc_annual` sudah dipakai paket Premium dan harus unik).
   Aplikasi menentukan tier lewat kata "ultimate" di identifier paket atau produk
   (`subscription_status.dart:163`) dan periode lewat "month"/"year"/"annual", jadi nama-nama ini wajib dipakai.
6. **Build.** Rilis dengan `--dart-define=AI_EXTRACTION_URL=https://<worker>/extract`. Tanpa itu fitur mati diam-diam
   dan tombol upgrade tidak muncul (A3).
7. **Play Console.** Tambahkan lagi bagian Ultimate di deskripsi listing (`docs/LISTING-PLAY-STORE.md`); tinjau ulang
   formulir Data Safety untuk aliran data AI.
8. **Kebijakan privasi.** Bagian Ultimate sudah ada tetapi masih menyebut **Anthropic**. Saat Gemini terpilih dan
   Worker akan di-deploy, ubah `docs/kebijakan-privasi/index.html` (butir ringkasan di baris ±42, bagian 6 di baris
   ±90, dan daftar penyedia di baris ±93): ganti "Anthropic (model Claude)" menjadi "Google (model Gemini melalui
   Gemini API berbayar)" dan tautan kebijakan Google. Tegaskan bahwa data dari API berbayar tidak dipakai Google untuk
   melatih model. Lalu hosting ulang ke `https://dompetku.hardan-ti.com/privacy`. **Jangan ubah berkas ini sebelum
   Worker di-deploy**, karena versi online harus sesuai kenyataan. Cek ulang juga jawaban formulir Data Safety.

## 6. Fase E — Rilis 4 dan uji nyata

- Naikkan `pubspec.yaml` ke `1.0.0+4` (Play menolak versionCode yang sudah dipakai). Perubahan teks manfaat
  Scan struk yang sudah di-commit ikut terbawa.
- Semua uji memakai akun penguji lisensi (daftar Nugaduh, sudah aktif), jadi tidak ada tagihan sungguhan.
- Matriks uji pembelian:

| Skenario | Yang diverifikasi |
|---|---|
| Gratis → Premium bulanan | Gate terbuka, iklan hilang (sudah ada rencana uji sejak Premium) |
| Gratis → Ultimate bulanan | Entitlement `premium` **dan** `ultimate` aktif, scan AI berfungsi |
| Premium bulanan → Ultimate bulanan | Langganan Premium **digantikan** (bukan ganda), tagihan prorata, entitlement berpindah |
| Premium tahunan → Ultimate bulanan/tahunan | Sama; catat perilaku prorata |
| Ultimate → batal → kedaluwarsa | Kembali ke gratis; scan AI berhenti; data lama tidak hilang |
| Kuota | Simulasikan `MONTHLY_LIMIT=2` di staging: pesan 429 dan pesan sisa kuota (A4) muncul, heuristik tetap dipakai |
| Offline / Worker mati | Scan tetap berfungsi dengan heuristik, tanpa error terlihat |
| Pulihkan pembelian pada HP lain | Tier terpulihkan dan `activeSubscriptionProductId` benar |

- Catat di sini nilai `oldProductId` yang ternyata benar untuk A2 (lihat A2).
- Verifikasi biaya sungguhan setelah beberapa hari live (item terbuka di checklist OCR-SCAN-STRUK §6).

## 7. Checklist

### A — Jalur upgrade dan UI
- [ ] A1 `ActiveTier` + `subscriptionTierProvider` + `activeSubscriptionProductId()` + fake di harness
- [ ] A2 penggantian produk (`StoreProductChangeInfo`) + `shouldReplaceProduct` + tes
- [ ] A3 tile Pengaturan tiga kondisi + `SubscriptionPage(upgradeOnly)` + teks manfaat
- [ ] A4 tampilan sisa kuota + tes
- [ ] A5 ajakan Ultimate di alur Scan struk + aturan tampil + tes

### B — Penyedia AI dan total/tanggal dari AI
- [x] Keputusan pemilik: pakai Google Gemini (2026-09-30), model dipilih di B3
- [ ] B0.1 verifikasi endpoint dan format keluaran terstruktur Gemini · [ ] B0.2 `src/gemini.ts`
- [ ] B0.3 `GEMINI_API_KEY` + `AI_MODEL` + log token · [ ] B0.4 tes unit `gemini.ts`
- [ ] B0.5 bersih-bersih setelah pemilihan · [ ] B0.6 skrip evaluasi
- [ ] Cek target audiens/rating konten Play (klausul di bawah 18 tahun)
- [ ] B1 Worker: skema `total`/`date`, validasi, prompt, tes handler
- [ ] B2 Klien: parsing, penerapan di `_enhanceWithAi`, tes
- [ ] B3 Evaluasi 10 struk (heuristik, 3.1 Flash-Lite, 3.8 Flash, Haiku 4.5) + pilih model + biaya per scan dari token nyata

### C — Pengerasan Worker
- [ ] C1 batas harian · [ ] C2 cache entitlement · [ ] C3 rate limit per IP · [ ] C4 anggaran Google Cloud Billing (atau batas Anthropic bila Haiku menang)
- [x] C5 dan C6 diputuskan tidak dikerjakan sekarang (lihat tabel C)

### D — Operasional
- [ ] D0 project Google Cloud khusus kunci Gemini + billing aktif (paid tier)
- [ ] D1 deploy Worker + secret + KV + `AI_MODEL` · [ ] D2 produk Play Ultimate · [ ] D3 impor produk RevenueCat
- [ ] D4 entitlement `ultimate` (+ `premium`) · [ ] D5 paket di offering `dompetku` · [ ] D6 build dengan `AI_EXTRACTION_URL`
- [ ] D7 listing dan Data Safety · [ ] D8 kebijakan privasi: Anthropic → Google, hosting ulang (setelah Worker di-deploy)

### E — Rilis dan uji
- [ ] E1 versi `1.0.0+4`, build AAB, unggah ke uji internal
- [ ] E2 matriks uji pembelian (§6) lulus semua baris
- [ ] E3 verifikasi biaya sungguhan

## 8. Catatan hasil (diisi saat dikerjakan)

- Nilai `oldProductId` yang benar untuk penggantian produk: _belum diuji_.
- Hasil evaluasi 10 struk (B3): _belum dilakukan_. Tabel yang harus diisi: baris = struk, kolom = heuristik / 3.1
  Flash-Lite / 3.8 Flash / Haiku 4.5, sel = benar/salah untuk total, tanggal, toko, kategori.
- Model AI terpilih dan ID model: _belum dipilih_ (keputusan penyedia: Gemini).
- Endpoint Gemini yang berlaku (`generateContent` atau `interactions`) dan nama field keluaran terstruktur: _belum diverifikasi_.
- Token nyata per scan dan biaya per scan setelah B: _belum diukur_.
