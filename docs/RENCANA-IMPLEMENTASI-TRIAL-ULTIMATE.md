# Rencana implementasi: uji coba Ultimate 30 hari tanpa kartu (Jalur B)

> Disusun 2026-10-14. Status: **rencana yang disetujui sebagian (keputusan di bagian 10), belum ada kode**. Dasar: keputusan pemilik memberi pengguna baru uji coba penuh Ultimate
> selama satu bulan, dibiayai dari anggaran promosi. Dokumen ini memilih **Jalur B** (tanpa kartu, diberikan Worker lewat
> *promotional entitlement* RevenueCat), bukan Jalur A (memperpanjang trial Play 15 hari). Bagian 4 menjawab pertanyaan utama:
> bagaimana mencegah pengguna yang memasang ulang dan memulihkan backup untuk mengulang trial.
>
> Hal yang **belum diverifikasi** ditandai ⚠️ dan dikumpulkan di bagian 9. Jangan membangun di atasnya sebelum diuji.

## 1. Ringkasan keputusan

| Hal | Keputusan |
|---|---|
| Mekanisme | Tombol opt-in "Coba semua fitur 30 hari gratis" memanggil endpoint Worker baru `/trial/claim`; Worker memberi entitlement `ultimate` **dan** `premium` (Ultimate memegang keduanya, lihat `revenuecat_config.dart`) selama 30 hari lewat API RevenueCat |
| Kunci kelayakan | **Identitas perangkat yang bertahan pasang ulang** (`ANDROID_ID`, di-hash di server), BUKAN ID anonim RevenueCat (ID itu baru setiap pasang ulang) |
| Kuota AI saat trial | Lebih kecil daripada pelanggan berbayar: **60 scan/bulan (10/hari)** dan **6 ringkasan/bulan (2/hari)**, sehingga biaya terburuk per trial ≈ **Rp460** (bukan Rp2.280) |
| Pengaman biaya | Batas klaim baru per hari, anggaran AI promo global per bulan dengan saklar mati, batas per IP |
| Akhir trial | Layar penjelasan sekali + tawaran Premium/Ultimate; tidak ada data yang dihapus |
| Anti-penyalahgunaan | Berlapis (bagian 4); tujuannya membuat pengulangan **mahal dan tidak sepadan**, bukan mustahil |

## 2. Fakta kode yang menjadi dasar

| Fakta | Sumber | Dampak ke rancangan |
|---|---|---|
| Aplikasi menganggap Ultimate aktif bila `CustomerInfo.entitlements.active` memuat `ultimate` (juga `premium` untuk gate Premium) | `subscription_status.dart` | Entitlement promosional otomatis diterima tanpa mengubah gate fitur, **asal keduanya diberikan** |
| Worker mengecek `entitlements[ultimate].expires_date` ke RevenueCat dengan secret key, hasil di-cache KV 300 dtk (positif) / 60 dtk (negatif) | `revenuecat.ts`, `entitlement_cache.ts` | Entitlement promosional lolos tanpa perubahan; cache positif perlu dipendekkan untuk trial berakhir (lihat 5.3) |
| Kuota dihitung per `appUserId` di KV: bulanan 300, harian 15 (scan); 30 dan 5 (ringkasan) | `handler.ts`, `wrangler.toml` | Kuota trial butuh pembeda sumber entitlement |
| ID RevenueCat anonim, tidak ada login | `subscription_status.dart` | ID baru tiap pasang ulang: tidak bisa dipakai sebagai kunci anti-ulang |
| Backup berkas `.json` gratis, tidak terenkripsi, memuat semua buku kas; backup cloud (terenkripsi) fitur Premium | `backup.dart`, `cloud_backup_*` | Pemulihan berkas adalah jalur pengulangan yang dikhawatirkan |
| Bukan Ultimate: semua buku selain Buku Utama **terkunci** (data utuh, transaksi berulang dijeda); Tabungan hanya bisa ditarik | `lockedLedgerIds`, `savings_page.dart` | Insentif pengulangan = membuka kembali buku kas tambahan dan fitur Premium/Ultimate |
| Data Safety sudah mendeklarasikan "ID perangkat atau ID lainnya" (AdMob + ID anonim RevenueCat), tujuan termasuk pencegahan penipuan | `DATA-SAFETY-PLAY.md` | Penambahan kunci perangkat ber-hash masih satu kategori, tetapi teks kebijakan privasi wajib diperbarui |
| Biaya AI terukur ≈ Rp4,6/scan (5 scan), ≈ Rp30/ringkasan (perkiraan, belum terukur) | `PROYEKSI-FINANSIAL.md` | Ukur dulu di log `ai_usage` sebelum menaikkan skala |

## 3. Rancangan

### 3.1 Alur klaim

```
Aplikasi                         Worker (/trial/claim)                 RevenueCat
   | 1. tombol "Coba 30 hari"        |                                      |
   | 2. baca ANDROID_ID, appUserId   |                                      |
   |-- POST {appUserId, deviceId} -->|                                      |
   |                                 | 3. validasi format, batas IP/global  |
   |                                 | 4. h = HMAC(RAHASIA, deviceId)       |
   |                                 | 5. KV get trial:h                    |
   |                                 |    - tidak ada: grant 2 entitlement->|
   |                                 |      KV put trial:h {at, appUserId}  |
   |                                 |    - ada & masih berlaku:           |
   |                                 |      grant SISA hari ke appUserId    |
   |                                 |    - ada & sudah habis: already_used |
   |<-- {status, endsAt} ------------|                                      |
   | 6. refresh CustomerInfo         |                                      |
   | 7. tampilkan hitung mundur      |                                      |
```

Sifat penting:
- **Idempoten**: klaim ulang dengan `appUserId` yang sama mengembalikan hasil yang sama, tanpa efek ganda.
- **Pasang ulang di masa trial** (perangkat sama, ID RevenueCat baru): pengguna jujur mendapat **sisa hari**, bukan trial baru dan bukan kehilangan.
- Hash memakai **HMAC dengan rahasia server**, jadi `ANDROID_ID` mentah tidak pernah disimpan dan tabel KV tidak bisa dipakai membalik identitas.

### 3.2 Worker

| Bagian | Perubahan |
|---|---|
| Endpoint | `POST /trial/claim` di `index.ts`, handler baru `trial_handler.ts` (pola sama `report_handler.ts`: batas IP lebih dulu, validasi ketat, `json()`) |
| KV | `trial:{h}` → `{grantedAt, endsAt, appUserId}` **tanpa TTL** (atau TTL ≥ 400 hari). `trialday:{yyyy-mm-dd}` penghitung klaim harian. `promo_ai:{yyyy-mm}` anggaran AI promo |
| RevenueCat | Panggil API v1 *promotional entitlement* untuk `ultimate` dan `premium` dengan `end_time_ms` ⚠️; gagal separuh = coba ulang idempoten, jangan catat KV sebelum keduanya berhasil |
| Sumber entitlement | Ubah `makeEntitlementChecker` agar mengembalikan `{active, source}`; `source = "promo"` bila `product_identifier` berawalan `rc_promo_` ⚠️. Cache KV menyimpan `1p` (promo) / `1s` (berbayar) / `0` |
| Kuota | Variabel baru di `wrangler.toml`: `TRIAL_MONTHLY_LIMIT=60`, `TRIAL_DAILY_LIMIT=10`, `TRIAL_REPORT_MONTHLY_LIMIT=6`, `TRIAL_REPORT_DAILY_LIMIT=2`. `handler.ts` dan `report_handler.ts` memilih batas menurut `source` |
| Rahasia baru | `TRIAL_HASH_SECRET` (acak panjang, lewat `wrangler secret put`) |
| Saklar | `TRIAL_ENABLED` ("1"/"0") dan `TRIAL_DAILY_CLAIM_CAP`, `PROMO_AI_MONTHLY_BUDGET_CALLS` |

### 3.3 Aplikasi

| Bagian | Rincian |
|---|---|
| ID perangkat | `MethodChannel` kecil di `MainActivity.kt` yang membaca `Settings.Secure.ANDROID_ID` (atau paket `android_id`); tanpa izin baru |
| Layanan | `lib/features/subscription/trial_service.dart`: `eligibility()`, `claim()`, antarmuka palsu untuk tes (pola `FakeSubscriptionStatus`) |
| Penanda trial | `EntitlementInfo.store == Store.promotional` ⚠️ menandai "ini trial"; ditambahkan sebagai `isTrial` + `trialEndsAt` pada `SubscriptionStatus` |
| UI | Kartu ajakan di Dashboard/slide onboarding terakhir (hanya bila layak dan bukan pelanggan); di Pengaturan > Langganan: "Uji coba Ultimate: sisa N hari"; **pengguna harus menekan tombol** (opt-in), dengan keterangan singkat bahwa pengenal perangkat dikirim untuk mencegah pengulangan |
| Akhir trial | Saat entitlement lapas: dialog sekali (disimpan di `KeyValueStore`) berisi daftar yang berubah (buku kas terkunci, Tabungan hanya-tarik, iklan kembali, backup cloud berhenti), tombol ke halaman langganan |
| Gate lain | Tidak ada perubahan: `isUltimateProvider`/`lockedLedgerIds`/Tabungan sudah bereaksi pada entitlement |

## 4. Mitigasi: pengguna yang memasang ulang dan memulihkan backup

### 4.1 Memahami insentifnya (penting)
Setelah trial habis, pengguna **tetap bisa mencatat** di paket Gratis (transaksi, dompet, anggaran, ekspor CSV). Yang tidak mereka
punya hanyalah fitur Ultimate/Premium: buku kas tambahan, Tabungan, scan/ringkasan AI, Excel, backup cloud, dan tanpa iklan.
Jadi pelaku **bukan** mengejar kemampuan mencatat, melainkan membuka lagi fitur-fitur itu. Ini menentukan prioritas: yang perlu
dijaga adalah **biaya AI** dan **kebocoran konversi**, bukan keamanan data pengguna.

### 4.2 Bagaimana pengulangan itu terjadi bila tidak dijaga
1. Trial habis, buku kas tambahan terkunci.
2. Ekspor backup berkas (gratis, tidak terenkripsi) → copot pasang → pasang ulang.
3. Pasang ulang menghasilkan **ID anonim RevenueCat baru** → tampak seperti pengguna baru → klaim trial lagi.
4. Pulihkan backup berkas → semua buku dan Tabungan kembali terbuka selama 30 hari berikutnya.

Backup memulihkan data, **bukan** identitas langganan; langkah 3 adalah titik lemahnya.

### 4.3 Lapisan pertahanan

| # | Lapisan | Cara kerja | Menghentikan | Biaya/risiko |
|---|---|---|---|---|
| L1 | **Kunci perangkat tahan pasang ulang** (wajib, Fase 1) | `ANDROID_ID` bernilai sama setelah uninstall/reinstall pada perangkat dan pengguna Android yang sama (selama kunci tanda tangan sama; build Play konsisten) ⚠️. Server menyimpan HMAC-nya selamanya; klaim kedua dari perangkat sama ditolak | Pasang ulang + pulihkan backup di **HP yang sama** (kasus yang Anda khawatirkan) | Gratis. Berubah setelah *factory reset*; bisa dipalsukan di perangkat root |
| L2 | **Kuota trial kecil** (wajib, Fase 1) | 60 scan + 6 ringkasan per trial | Menekan kerugian per pengulangan menjadi ≈ Rp460 | Gratis; trial terasa lebih terbatas, tetapi cukup untuk "mencicipi" |
| L3 | **Batas global dan saklar mati** (wajib, Fase 1) | Klaim baru ≤ N/hari, anggaran panggilan AI promo per bulan; bila habis, trial tetap aktif tanpa AI atau klaim baru ditunda | Serangan massal / pemakaian di luar rencana; menjamin anggaran promosi tidak jebol | Gratis |
| L4 | **Batas per IP** | Maks. klaim per IP per hari, **longgar** (jaringan seluler Indonesia memakai CGNAT, banyak orang berbagi satu IP) | Skrip otomatis sederhana | Terlalu ketat menolak pengguna sah |
| L5 | **Play Integrity** (Fase 3) | Aplikasi mengirim token; Worker memeriksa `MEETS_DEVICE_INTEGRITY`, `PLAY_RECOGNIZED`, `LICENSED` | Emulator, perangkat root yang memalsukan ID, APK modifikasi/klon, pemasangan non-Play | Perlu proyek Google Cloud + dekode di server ⚠️; sedikit pengguna sah gagal lulus |
| L6 | **Resi trial di dalam backup** (Fase 3, opsional) | Worker menandatangani resi `HMAC(h, grantedAt)`; aplikasi menyimpannya dan menyertakannya di backup (format v9). Saat pemulihan di perangkat baru, resi dikirim ke Worker | Pengguna jujur ganti HP: dapat **sisa hari**, bukan trial baru | Bukan pagar: pelaku bisa membuang resi dari berkas yang tidak terenkripsi. Nilainya di pengalaman pengguna sah, bukan keamanan |
| L7 | **Penguat identitas lain** (hanya bila L1 jebol) | Block Store / Play Integrity *device recall* ⚠️ (status beta) menyimpan bit penanda per perangkat yang bertahan pasang ulang dan reset | Factory reset | Kompleksitas, status API belum pasti |

### 4.4 Risiko sisa yang diterima (jujur)
| Celah | Seberapa sulit | Kerugian per kejadian |
|---|---|---|
| *Factory reset* HP lalu klaim lagi | Sedang (kehilangan semua data HP) | ≤ Rp460, plus satu trial |
| Memakai HP lain / akun pengguna Android lain | Sedang | ≤ Rp460 |
| Perangkat root memalsukan `ANDROID_ID` | Tinggi | ≤ Rp460, dan L5 menutupnya |
| Memakai nama pengguna baru di aplikasi yang sama | Tidak berlaku (tidak ada akun) | - |

Maka ekonominya: pengulangan butuh usaha berarti **dan** hanya menghasilkan fitur senilai < Rp500 biaya bagi Anda. Itu cukup
untuk mencegah penyalahgunaan kasual (pasang ulang + pulihkan) tanpa membuat pengguna sah terganggu. Pelaku yang bertekad
tidak bisa dicegah sepenuhnya dan tidak sebanding untuk dilawan.

### 4.5 Mengurangi dorongan untuk curang (tanpa teknis)
- **Jangan sandera data.** Saat ini buku kas tambahan "terkunci". Pertimbangkan membuatnya **hanya-baca + bisa diekspor CSV**
  di paket Gratis, supaya pengguna jujur tidak merasa terpaksa mencari celah. ⚠️ Perlu diperiksa dulu bagaimana tepatnya
  perilaku terkunci sekarang di UI sebelum dijanjikan.
- **Jalur naik yang murah.** Tawarkan Premium (Rp7.500) sebagai pijakan di layar akhir trial, bukan hanya Ultimate.
- **Trial Play 15 hari tetap ada** untuk yang mau menautkan pembayaran; pelaku tidak bisa memakainya berulang karena Play
  menolak kelayakan untuk akun yang sudah pernah berlangganan.

## 5. Detail teknis penting

### 5.1 Dua entitlement
Produk Ultimate di dashboard dikaitkan ke `premium` **dan** `ultimate`. Hibah promosional harus **dua kali** (satu per
entitlement) dengan `end_time_ms` yang sama; bila hanya `ultimate` yang diberikan, gate Premium (backup cloud, Utang, Excel,
tanpa iklan) tidak terbuka.

### 5.2 Interaksi dengan pembelian
- Membeli Premium/Ultimate saat trial: entitlement berbayar berjalan berdampingan dengan hibah; yang terpanjang berlaku.
- **RISIKO PENAGIHAN GANDA (wajib ditangani sebelum menawarkan trial ke pelanggan Premium, keputusan 2c).**
  `shouldReplaceProduct` memutuskan penggantian produk Play dari `ActiveTier`, dan tier itu dihitung dari entitlement
  *termasuk yang promosional*. Pelanggan Premium berbayar yang sedang trial Ultimate akan dihitung `ultimate`, sehingga bila ia
  membeli Ultimate, aplikasi **tidak** meminta penggantian produk dan Play menagih **Premium dan Ultimate sekaligus**.
  Perbaikan: pisahkan dua pengertian tier. (a) *Tier akses* (membuka fitur) boleh memasukkan hibah promosional; (b) *tier
  berbayar* (menentukan penggantian produk, tombol beli, tampilan "Kelola langganan") hanya dari entitlement bertoko Play
  (`Store.playStore`). Tambah tes: Premium berbayar + trial Ultimate lalu beli Ultimate = produk Premium diganti; Gratis + trial
  lalu beli = pembelian biasa tanpa penggantian; trial berakhir saat masih Premium berbayar = tetap Premium.

### 5.3 Cache dan kedaluwarsa
Cache positif 300 dtk berarti trial yang baru berakhir bisa lolos hingga 5 menit. Dapat diterima (biaya ≈ nol), tetapi untuk
hibah promosional pakai TTL 60 dtk agar kuota trial tidak "bocor" setelah habis.

### 5.4 Bila trial berakhir di tengah pencatatan
Aturan yang sudah ada berlaku apa adanya: buku selain Buku Utama terkunci, transaksi berulang di buku itu dijeda, Tabungan
hanya-tarik. Tidak ada migrasi dan tidak ada penghapusan data.

## 6. Privasi, kebijakan Play, dan teks

| Item | Tindakan |
|---|---|
| Kebijakan privasi (`laciq.solusimandiri.id/privacy`) | Tambah bagian: pengenal perangkat dikirim dan disimpan dalam bentuk ber-hash satu arah untuk mencegah klaim uji coba berulang; tidak dibagikan; lama simpan |
| Data Safety (Play Console) | Kategori "ID perangkat atau ID lainnya" sudah **Ya**; tambahkan tujuan "Pencegahan penipuan, keamanan" bila belum, dan sebut `ANDROID_ID` ber-hash di `DATA-SAFETY-PLAY.md` |
| Teks tombol | Jujur: "30 hari gratis, tanpa kartu. Setelah itu kembali ke paket Gratis kecuali Anda berlangganan." Tidak ada penagihan otomatis |
| Kebijakan Play | Hibah akses gratis di luar Play Billing diperbolehkan (bukan penjualan). Jangan menyebutnya "langganan gratis" |
| Persetujuan | Opt-in lewat tombol; tidak ada klaim otomatis di latar belakang |

## 7. Metrik, ambang, dan evaluasi

Catat (log Worker/KV, RevenueCat): klaim per hari, `already_used` (percobaan pengulangan yang ditolak), pemakaian AI per trial
(rata-rata dan persentil 95), biaya nyata per trial, retensi hari-7, konversi trial → berbayar dalam 14 hari sesudah akhir.

| Metrik | Ambang usulan (belum ada data, sesuaikan) | Tindakan |
|---|---|---|
| Biaya AI nyata per trial | < Rp500 | Bila lebih, turunkan kuota trial |
| Konversi trial → berbayar | ≥ 3% setelah ≥ 500 trial selesai | Pertahankan; < 1,5% = tinjau durasi/isi |
| `already_used` / klaim | Ratusan persen adalah wajar bila banyak yang mencoba ulang; yang dipantau adalah **klaim sukses per perangkat unik** | Bila klaim sukses melonjak tanpa pengguna baru, aktifkan L5 |
| Anggaran AI promo | ≤ anggaran promosi yang dialokasikan | Saklar mati otomatis di 100% |

Catatan: ambang di `rencana_implementasi_laciq.md` (≥ 30% trial-to-paid) berlaku untuk trial berkartu Play; trial tanpa kartu
wajar jauh lebih rendah, jadi jangan dibandingkan langsung.

## 8. Tahapan

| Fase | Isi | Prasyarat/Keluaran |
|---|---|---|
| **0. Verifikasi** (tanpa kode produksi) | Uji `curl` hibah promosional ke akun uji; periksa `product_identifier`, `store`, dukungan `end_time_ms`; pastikan `ANDROID_ID` bertahan pasang ulang di Fold (build Play vs debug berbeda tanda tangan); putuskan angka kuota/anggaran; ukur biaya ringkasan sungguhan | Daftar ⚠️ di bagian 9 tertutup |
| **1. Worker** | `/trial/claim`, KV, kuota trial, batas harian/IP, saklar, anggaran promo; tes unit (diberikan, sisa hari, ditolak, batas, saklar, ID tidak valid, gagal separuh); deploy | Worker siap, aplikasi lama tidak terpengaruh |
| **2. Aplikasi** | Channel `ANDROID_ID`, `TrialService`, kartu ajakan, hitung mundur, dialog akhir trial, teks onboarding/langganan; tes widget dengan layanan palsu | Satu build bersama v1.1 (bagian "paywall trial") |
| **3. Penguatan** | Play Integrity (L5), resi di backup format v9 (L6) | Hanya bila data fase 4 menunjukkan penyalahgunaan |
| **4. Pantau** | 4-6 minggu metrik bagian 7; putuskan durasi, kuota, perluasan | Keputusan berdasarkan data |

### Uji manual wajib (HP nyata)
1. Klaim → Ultimate aktif, hitung mundur tampil, scan AI berjalan, kuota trial berlaku (cek batas ke-61 ditolak).
2. Pasang ulang di HP yang sama saat trial → dapat **sisa hari**, bukan 30 hari baru.
3. Trial habis (uji dengan `end_time_ms` 5 menit) → fitur terkunci sesuai aturan; pasang ulang + pulihkan backup berkas →
   klaim **ditolak** `already_used`.
4. Beli Premium/Ultimate saat trial → tidak ada penggantian ganda, entitlement tetap setelah trial lewat.
5. HP kedua (perangkat lain) → trial baru diberikan (perilaku yang diterima).
6. Saklar `TRIAL_ENABLED=0` → tombol tidak muncul/klaim ditolak dengan pesan jelas, trial aktif tetap berjalan.
7. Tanpa jaringan → pesan jelas, tidak ada trial setengah jadi.

## 9. Asumsi yang HARUS diverifikasi (⚠️) sebelum membangun

| # | Asumsi | Cara memeriksa |
|---|---|---|
| 1 | API v1 RevenueCat menerima hibah promosional per entitlement dengan `end_time_ms` (atau durasi tetap `monthly`) | `curl` dengan secret key ke ID uji; baca dokumentasi RevenueCat saat Fase 0 |

> **Terverifikasi dari dokumentasi (2026-10-14), belum dari panggilan nyata:** `POST /v1/subscribers/{id}/entitlements/{entitlement}/promotional` menerima `end_time_ms`; `duration` dan `start_time_ms` ditandai *deprecated*; sukses = HTTP 201; ada `POST …/revoke_promotionals`. **Catatan baru:** hibah dengan `end_time_ms` dalam 2 jam dari hibah promosional aktif dianggap duplikat dan tidak memperpanjang. Skrip uji Fase 0 ada di `tools/fase0-trial/` (lihat README di sana).
| 2 | Entitlement promosional tampil di `CustomerInfo` aplikasi dan `EntitlementInfo.store` bernilai promotional | Hibah ke ID uji lalu cek di build debug |
| 3 | `product_identifier` promosional di API subscriber berawalan `rc_promo_` | Baca respons `subscribers/{id}` setelah hibah |
| 4 | `ANDROID_ID` bernilai sama setelah uninstall/reinstall di Galaxy Z Fold6 pada build Play | Pasang, catat, copot, pasang ulang, bandingkan |
| 5 | Kunci API secret yang dipakai Worker punya izin menulis (hibah) | Coba hibah; bila 401, buat kunci V1 dengan izin yang sesuai |
| 6 | Play Integrity (fase 3): kuota harian standar mencukupi dan token bisa diverifikasi dari Worker | Baca dokumentasi saat Fase 3 |
| 7 | Perilaku buku kas terkunci di UI (apakah masih bisa dibaca) | Baca `ledgers_page.dart`/pengalih buku sebelum mengubah janji ke pengguna |

### Hasil Fase 0 (dijalankan 2026-10-14)

Dijalankan dengan `tools/fase0-trial/` pada Galaxy Z Fold6 (adb nirkabel) dan ID uji dari probe; hibah uji dicabut di akhir.

| # | Asumsi | Hasil | Bukti |
|---|---|---|---|
| 1 | Hibah promosional per entitlement dengan `end_time_ms` | **Terbukti** | HTTP 201 untuk `ultimate` dan `premium`; `expires_date` tepat sama dengan `end_time_ms` (selisih 0 ms) |
| 2 | Hibah terlihat di `CustomerInfo` aplikasi, `store` promotional | **Terbukti** | Probe di Fold: `ultimate` dan `premium` aktif, `store=promotional`, berakhir sama; tanpa perubahan kode aplikasi |
| 3 | `product_identifier` berawalan `rc_promo_` | **Terbukti** | `rc_promo_ultimate_custom` dan `rc_promo_premium_custom` (bentuk `rc_promo_<entitlement>_custom` untuk hibah `end_time_ms`) |
| 4 | `ANDROID_ID` sama setelah pasang ulang | **Terbukti pada kunci uji** | Nilai sama pada dua kali copot-pasang dengan kunci tanda tangan khusus probe; ID RevenueCat berubah tiap kali. **Belum terbukti dengan kunci Play** (konfirmasi di Fase 2) |
| 5 | Kunci secret boleh menulis | **Terbukti** | Hibah HTTP 201 dengan kunci V1 yang dipakai uji. *Catatan:* pastikan itu kunci yang sama dengan rahasia Worker |
| W | Keputusan Worker benar | **Terbukti** (aktif, kedaluwarsa alami, dan dicabut) | `hasUltimate=true` saat hibah aktif, `false` setelah dicabut. Uji ulang dengan ID segar: `hasUltimate=true` saat aktif, `false` setelah kedaluwarsa tanpa pencabutan (selisih end_time_ms 659 ms); uji pertama tidak sahih karena ID bekas hibah (lihat temuan) |
| i | Hibah ulang < 2 jam | **Sesuai dokumentasi** | Hibah +30 menit di atas hibah aktif tidak memperpanjang |

**Temuan dari uji kedaluwarsa pertama (2026-10-14, hasil tidak sahih tetapi sangat berguna):**

Uji `--wait-expiry` dijalankan pada ID yang sama dengan uji sebelumnya, beberapa menit setelah hibah lama dicabut. Hasilnya:

| Pengamatan | Arti |
|---|---|
| Hibah baru dijawab **HTTP 201**, tetapi `expires_date` tidak berubah (tetap waktu pencabutan lama) | **Hibah baru DIABAIKAN diam-diam.** Aturan "end_time_ms dalam 2 jam dari hibah promosional sebelumnya = duplikat" berlaku juga terhadap hibah yang sudah dicabut/kedaluwarsa pada ID yang sama |
| Pencabutan mengembalikan **HTTP 404** | Tidak ada hibah aktif untuk dicabut; wajar, bukan galat |
| Setelah pencabutan, entitlement **tetap tercantum** dengan `expires_date` = saat pencabutan | Pencabutan = memajukan kedaluwarsa, bukan menghapus entri. Pengecekan Worker (membandingkan tanggal) sudah benar |

Akibat bagi Worker (masuk ke Fase 1):
1. **Jangan mempercayai HTTP 201.** Setelah menghibahkan, baca ulang pelanggan (atau pakai badan respons) dan pastikan `expires_date` ≈ `end_time_ms`; bila tidak, perlakukan sebagai gagal (`grant_ignored`), jangan catat KV, dan laporkan.
2. **Aman untuk alur utama:** klaim dan "sisa hari" selalu menyasar **ID RevenueCat baru** (pasang ulang menghasilkan ID baru), jadi tidak tersandung aturan 2 jam. Aturan ini hanya mengena bila Worker menghibahkan lagi ke **ID yang sama**, mis. klaim berulang pada ID yang sama setelah trial berakhir; kasus itu seharusnya sudah ditolak oleh catatan KV perangkat (`already_used`).
3. **Pengujian harus memakai ID segar** untuk setiap uji hibah (skrip kini memperingatkan bila ID pernah menerima hibah).

**Akibat bagi rancangan:** tidak ada perubahan. Penentu sumber promosional di Worker memakai awalan `rc_promo_` pada `product_identifier`; tambahan: verifikasi hibah dengan membaca ulang (lihat temuan di atas).

**Sisa verifikasi sebelum/ saat membangun:**
1. ~~Uji kedaluwarsa alami~~ **selesai (lulus)**.
2. `ANDROID_ID` pada build bertanda tangan Play (jalur pengujian internal) di Fase 2.
3. Butir 6 (Play Integrity di Worker) dan butir 7 (perilaku buku terkunci di UI): bukan bagian skrip ini.
4. Konfirmasi kunci secret yang dipakai uji sama dengan `REVENUECAT_SECRET_KEY` Worker (bila berbeda, hibah dari Worker bisa gagal berizin).

### Status Fase 1 (Worker) — diselesaikan 2026-10-14, BELUM di-deploy

Cabang `trial-ultimate-worker`. 134 tes Worker lulus (84 lama + 50 baru), typecheck bersih, `wrangler deploy --dry-run` valid.

| Bagian | Status |
|---|---|
| `POST /trial/claim` (kunci HMAC perangkat, idempoten, sisa hari saat pasang ulang, `already_used`, `already_ultimate`) | Selesai + tes |
| Hibah `ultimate` + `premium` dengan **pembacaan ulang** (`GrantIgnoredError`) | Selesai + tes |
| Pengenal sumber entitlement (`promo` vs `store`, pelanggan berbayar tidak kena kuota uji coba) | Selesai + tes |
| Kuota uji coba 60/10 scan dan 6/2 ringkasan; cache hibah 60 dtk | Selesai + tes |
| Anggaran AI promo global (Rp1,35 jt, scan Rp5 / ringkasan Rp30), klaim baru dijeda tanpa menghabiskan hak perangkat | Selesai + tes |
| Batas klaim harian, saklar `TRIAL_ENABLED` (bawaan mati), pembatas IP | Selesai + tes |
| Play Integrity: kebijakan vonis + mode `off/shadow/lenient/strict` | Selesai + tes |
| Play Integrity: **pendekode token ke Google** (butuh akun layanan) | **Belum**; `shadow` hanya mencatat `unavailable` |

**Yang perlu Anda lakukan sebelum menyalakan:** `wrangler secret put TRIAL_HASH_SECRET`, memastikan `REVENUECAT_SECRET_KEY` Worker
berizin menulis (butir 5), mengubah `TRIAL_ENABLED = "1"`, lalu deploy. Aplikasi belum memanggil endpoint ini (Fase 2), jadi
menyalakan lebih awal tidak berdampak bagi pengguna.

**Deploy aman bagi pengguna yang ada:** tanpa hibah promosional, perilaku `/extract` dan `/report-insight` identik dengan
sebelumnya (diuji). Format cache `ent:` berubah tetapi nilai lama `1`/`0` tetap terbaca.

### Status Fase 2 (aplikasi)

Cabang `trial-ultimate-app`.

| # | Butir | Status |
|---|---|---|
| 1 | Pisahkan **tier akses** dari **tier berbayar** (5.2: cegah penagihan ganda) | **Selesai** (710 tes lulus) |
| 2 | `TrialService` dan `ANDROID_ID` | **Selesai** (720 tes Flutter, 140 tes Worker); endpoint baca-saja `/trial/status` ditambahkan |
| 3 | Kartu ajakan opt-in kontekstual dan titik penawaran | Belum |
| 4 | Hitung mundur, peringatan per tonggak, dialog akhir (10.4) | Belum |
| 5 | Tes widget fase dan tonggak | Belum |

**Butir 2, yang dilakukan:**
- Worker: `POST /trial/status` (baca saja, tanpa efek samping) mengembalikan `disabled | ultimate | active | resumable | used |
  paused | available`. Tujuannya: **tidak menjanjikan "coba gratis" kepada perangkat yang akan ditolak** (mis. pasang ulang
  setelah trial habis). Klaim tetap lewat `/trial/claim`.
- Aplikasi: `TrialService` (`HttpTrialService`) dengan `status()` dan `claim()` yang tidak pernah melempar; tidak pasti =
  `TrialOffer.hidden`. Setelah klaim berhasil memanggil `SubscriptionStatus.refresh()` agar hibah langsung terlihat.
- Pengenal perangkat lewat paket `android_id` (tanpa izin baru; manifest gabungan diperiksa). `deviceIdSourceProvider`,
  `trialServiceProvider`, `trialStatusProvider`.
- URL diturunkan dari `AI_EXTRACTION_URL` (`/extract` → `/trial/claim`, `/trial/status`); kosong = penawaran tidak tampil.
- Harness tes: `FakeTrialService` terpasang bawaan di `appTest`, `FakeSubscriptionStatus.startTrial()` dan `refreshCount`.

**Butir 1, yang dilakukan:**
- `SubscriptionDetail` (tier berbayar, ID produk berbayar, `trialEndsAt`) diturunkan murni oleh `subscriptionDetailOf` dari
  entitlement **dan** daftar langganan aktif (RevenueCat memetakan entitlement ke produk berkedaluwarsa terpanjang, sehingga hibah
  yang lebih lama menyamarkan langganan berbayar pada objek entitlement).
- `SubscriptionStatus.watchDetail()` baru. `watchIsPremium/Ultimate` tetap = hak akses (membuka fitur, termasuk uji coba).
- `subscriptionTierProvider` kini = tier **berbayar**; `accessTierProvider` = hak akses; `trialEndsAtProvider` baru.
- Penggantian produk Play (`productToReplace`), penantian pembelian (`paidTierSatisfies`), dan "dipulihkan" (`restorePurchases`)
  hanya memandang langganan berbayar. Pembeli Ultimate saat uji coba tidak lagi salah dianggap sudah Ultimate.
- Upsell AI di form transaksi tidak menawarkan Ultimate kepada pelanggan Premium yang sedang uji coba.

## 10. Keputusan

### Sudah diputuskan pemilik (2026-10-14)
| # | Keputusan |
|---|---|
| 1 | Kuota trial **60 scan dan 6 ringkasan** per trial (batas harian 10 dan 2) |
| 3 | Durasi tetap **30 hari**, agar pengguna merasakan satu siklus pembukuan penuh |
| 4 | Plafon anggaran AI promo global **Rp1.500.000 per bulan** (rincian dan angka turunan di 10.1) |
| 5 | Play Integrity **opsi B**: aplikasi mengirim token, Worker hanya mencatat vonis, penegakan lewat bendera `INTEGRITY_ENFORCE` (rincian di 10.2) |
| 2a | Pengguna memulai trial lewat **opt-in kontekstual** (tombol di titik relevan, bukan klaim otomatis); rincian di 10.3 |
| 2b | Pengguna Gratis lama (sebelum rilis ini) **ikut ditawari, sekali** |
| 2c | Pelanggan Premium **ditawari trial Ultimate sebagai upsell**, setelah interaksi dengan langganan Play diuji (lihat 5.2: risiko penagihan ganda) |
| 2d | Pengingat hari ke-23 dan ke-28 **aktif**, hanya bila izin notifikasi sudah ada; ditambah **peringatan di dalam aplikasi** yang tidak bergantung izin (lihat 10.4) |

### Masih terbuka
Tidak ada keputusan produk yang terbuka. Yang tersisa adalah verifikasi teknis di Fase 0 (bagian 9).

### 10.1 Anggaran AI promo global (butir 4)

**Masalahnya.** Kuota per pengguna membatasi biaya *satu* trial (≈ Rp456), tetapi tidak membatasi *jumlah* trial. Biaya total =
jumlah trial × pemakaian. Bila promosi berhasil (atau ada yang menyerang), biaya ikut naik tanpa batas. Anggaran global adalah
atap total yang tidak bisa dilewati, apa pun yang terjadi.

**Cara kerja.**
- Worker menghitung perkiraan biaya setiap panggilan AI trial yang berhasil dalam satu penghitung bulanan di KV
  (`promo_cost:{yyyy-mm}`): scan dihitung Rp5, ringkasan Rp30 (dibulatkan ke atas dari angka terukur/perkiraan).
- Hanya pengguna dengan sumber entitlement *promosional* yang masuk hitungan; pelanggan berbayar tidak terpengaruh.
- Penghitung kedaluwarsa sendiri pada akhir bulan.

**Cara menentukan angkanya.** Biaya terburuk per trial Rp456 (60 × Rp4,6 + 6 × Rp30). Pemakaian nyata biasanya sebagian kecil
dari kuota; **angka rata-rata nyata belum ada**, jadi tabel di bawah memakai asumsi 20% dari kuota (≈ Rp91/trial) hanya
sebagai ilustrasi dan harus diganti data log `ai_usage` setelah beberapa minggu.

| Anggaran AI promo/bulan | Trial bila semua memakai KUOTA PENUH | Trial bila rata-rata 20% kuota (asumsi) |
|---|---|---|
| Rp500.000 | ≈ 1.100 | ≈ 5.500 |
| Rp1.000.000 | ≈ 2.200 | ≈ 11.000 |
| Rp2.000.000 | ≈ 4.400 | ≈ 22.000 |

**Saat anggaran habis (usulan):**
1. **70%**: peringatan (catat di log; periksa lewat `wrangler tail` atau dasbor; pemberi peringatan otomatis bisa menyusul).
2. **100%**: panggilan AI untuk pengguna trial dijawab `promo_budget_exhausted`; aplikasi menampilkan "Kuota AI uji coba bulan
   ini sudah habis, fitur lain tetap aktif sampai trial berakhir".
3. **Klaim baru juga dijeda** pada 100% dan **tidak menghabiskan hak trial perangkat itu**: pengguna dapat mencoba lagi bulan
   depan. Memberi trial tanpa AI menyia-nyiakan kesempatan satu-satunya dan memberi kesan pertama yang buruk.
4. Pelanggan berbayar tidak pernah terdampak.

**Sabuk pengaman kedua (di luar Worker).** Penghitung KV adalah *perkiraan*, bukan tagihan sebenarnya. Pasang juga
**anggaran dan peringatan tagihan di Google Cloud / kunci Gemini** sebagai batas independen ⚠️ (periksa cara akun Gemini Anda
ditagih). Dua lapis: Worker mencegah, tagihan Google memberi tahu.

**Keterbatasan jujur.** KV tidak atomik; pada lalu lintas bersamaan penghitung bisa kurang menghitung sedikit. Untuk anggaran
promosi ini wajar. Beri jarak aman: tetapkan batas di ±90% dari plafon yang benar-benar Anda relakan.

**Yang perlu Anda putuskan:** (a) nominal anggaran per bulan, (b) setuju klaim baru dijeda saat habis (butir 3), (c) ambang
peringatan 70% atau lain.

**Ditetapkan 2026-10-14:** plafon **Rp1.500.000 per bulan**. Turunannya:

| Parameter | Nilai | Keterangan |
|---|---|---|
| Plafon yang direlakan | Rp1.500.000 | Keputusan pemilik |
| Batas penegakan di Worker (`PROMO_AI_MONTHLY_BUDGET_RP`) | Rp1.350.000 (90%) | Ruang untuk penghitung KV yang tidak atomik |
| Peringatan (70% dari batas) | Rp945.000 | Catat di log, periksa dasbor |
| Kapasitas bila semua trial memakai kuota penuh (Rp456) | ≈ 2.960 trial | Perkiraan terburuk |
| Kapasitas bila rata-rata 20% kuota (≈ Rp91; asumsi, belum terukur) | ≈ 14.800 trial | Ganti dengan data log setelah 4-6 minggu |
| Batas klaim baru per hari (`TRIAL_DAILY_CLAIM_CAP`) | usulan 300 | Meratakan lonjakan; sesuaikan setelah ada data |

Saat batas Rp1.350.000 tercapai: AI trial dimatikan dan klaim baru dijeda tanpa menghabiskan hak trial perangkat (perilaku di atas).


### 10.2 Play Integrity (butir 5)

**Apa itu.** API Google yang membuat aplikasi dapat meminta *token integritas*. Worker mengirim token itu ke Google dan
menerima vonis:

| Vonis | Artinya | Contoh nilai |
|---|---|---|
| Aplikasi | APK yang berjalan dikenali dan tidak dimodifikasi | `PLAY_RECOGNIZED` |
| Perangkat | HP asli, bukan emulator/ROM yang dimanipulasi | `MEETS_BASIC_INTEGRITY` → `MEETS_DEVICE_INTEGRITY` → `MEETS_STRONG_INTEGRITY` |
| Lisensi | Akun Google di perangkat memasang aplikasi dari Play | `LICENSED` / `UNLICENSED` |

**Apa yang TIDAK dilakukannya (penting).** Ia **tidak memberi ID unik perangkat** dan tidak menghentikan pasang ulang. Untuk
pelaku "pasang ulang + pulihkan backup" di HP asli yang sama, Play Integrity **tidak menambah apa pun**: yang menghentikan
mereka tetap L1 (kunci `ANDROID_ID`). Nilai Play Integrity adalah menjaga agar L1 **tidak bisa dipalsukan**:
- skrip dan emulator berlapis yang membuat banyak "perangkat" palsu,
- perangkat root yang mengubah `ANDROID_ID` setiap klaim,
- APK klon atau modifikasi yang memanggil `/trial/claim` langsung.

Dengan kata lain: L1 melawan pengguna kasual, Play Integrity melawan pelaku yang mulai mengotomatiskan.

**Biaya dan kompleksitas.**
- Menautkan proyek Google Cloud ke aplikasi di Play Console, mengaktifkan API, dan menyimpan kredensial akun layanan di
  Worker untuk memverifikasi token (penandatanganan JWT bisa dilakukan di Cloudflare Workers) ⚠️.
- Sisi aplikasi: pemanggilan `IntegrityManager` lewat channel Kotlin atau paket pihak ketiga; butuh Google Play Services.
- Dipanggil **sekali per klaim** saja, jadi kuota harian standar Google jauh dari terpakai ⚠️.
- Build debug dan pemasangan non-Play (seperti uji di Fold tadi) akan **gagal vonis**; perlu jalur bypass untuk pengujian
  (bendera di Worker, atau uji lewat jalur pengujian internal Play).

**Risiko ke pengguna sah.** Pengguna dengan bootloader terbuka, ROM kustom, atau root bisa gagal `MEETS_DEVICE_INTEGRITY`
dan ditolak, meski jujur. Tingkat ketegasan menentukan seberapa banyak:

| Mode | Syarat | Menolak | Cocok untuk |
|---|---|---|---|
| Ketat | `PLAY_RECOGNIZED` + `MEETS_DEVICE_INTEGRITY` + `LICENSED` | Emulator, root, ROM kustom, APK klon, non-Play | Bila penyalahgunaan sudah terbukti |
| Longgar | `PLAY_RECOGNIZED` + `LICENSED` + minimal `MEETS_BASIC_INTEGRITY` | APK klon dan non-Play; emulator sederhana | Titik tengah yang masuk akal |
| Bayangan | Hanya **mencatat** vonis, tidak menolak | Tidak ada | Mengumpulkan data sebelum memutuskan |

**Kendala waktu rilis (alasan memilih sekarang).** Agar Worker bisa menegakkan vonis di kemudian hari, **aplikasi harus sudah
mengirim token**. Menambahkannya nanti berarti menunggu satu siklus rilis + peninjauan Play + pengguna memperbarui aplikasi.

**Tiga opsi:**
| Opsi | Isi | Plus | Minus |
|---|---|---|---|
| A. Wajib sejak awal | Mode ketat/longgar langsung di rilis pertama | Perlindungan penuh sejak hari pertama | Penolakan pengguna sah belum terukur; pengujian lebih rumit |
| **B. Bayangan dulu (usulan)** | Aplikasi mengirim token (gagal ambil token = tetap lanjut), Worker hanya mencatat vonis, bendera `INTEGRITY_ENFORCE` di `wrangler.toml` untuk menyalakan penegakan tanpa rilis baru | Tuas tersedia kapan saja; data nyata sebelum menolak siapa pun | Pekerjaan awal lebih banyak (Cloud + token + logging) |
| C. Tidak sama sekali | Hanya L1-L4 + anggaran global | Paling sederhana dan cepat | Bila penyalahgunaan otomatis muncul, melawan butuh rilis baru |

**Ditetapkan 2026-10-14: opsi B (mode bayangan).** Pendapat saya waktu itu: opsi **B**. Opsi **C** dapat diterima bila kapasitas terbatas, karena kerugian terburuk sudah dibatasi oleh
kuota trial (Rp456) dan anggaran global (10.1); yang dipertaruhkan hanyalah kecepatan bereaksi. Opsi A tidak disarankan sebelum
ada data tingkat penolakan pengguna sah.

**Pemicu untuk mulai menegakkan (bila memilih B):** klaim sukses harian naik tajam tanpa kenaikan pemasangan baru; biaya promo
habis jauh lebih cepat dari perkiraan; banyak klaim dari satu IP dengan perangkat berbeda; atau vonis bayangan menunjukkan
persentase emulator/klon yang berarti.

**Privasi:** token integritas dikirim ke Google dan vonisnya diproses Worker; tambahkan satu kalimat di kebijakan privasi dan
periksa bagian Data Safety (diagnostik/integritas perangkat).

### 10.3 Opt-in: penjelasan rinci (butir 2)

**Tiga model yang mungkin.**

| Model | Cara kerja | Kelebihan | Kekurangan |
|---|---|---|---|
| Otomatis | Trial dimulai sendiri saat aplikasi pertama dibuka | Jangkauan 100% pemasangan baru | Trial "terbakar" saat pengguna belum punya data; pengenal perangkat dikirim tanpa persetujuan; pengguna yang tidak sadar tiba-tiba kehilangan fitur di hari ke-30 |
| **Opt-in kontekstual (usulan)** | Pengguna sendiri menekan "Coba gratis 30 hari", ditawarkan di titik yang relevan | Jam trial dimulai saat pengguna siap dan punya data; persetujuan jelas; yang memulai biasanya yang berminat | Sebagian pengguna tidak pernah menekan |
| Opt-in tunggal | Hanya satu kartu di Dashboard | Paling sederhana | Dilewatkan oleh banyak orang |

**Mengapa opt-in kontekstual.**
1. **Jam trial harus mulai saat pengguna siap.** Tujuan Anda adalah pengguna merasakan satu siklus pembukuan penuh. Bila jam mulai
   saat aplikasi dibuka pertama kali, banyak pengguna baru mengisi data di hari ke-5 sampai ke-10, sehingga siklus yang mereka
   rasakan jauh lebih pendek dari 30 hari.
2. **Persetujuan bersih untuk pengenal perangkat.** Trial mengirim `ANDROID_ID` (ber-hash di server) ke Worker. Dengan tombol
   yang diketuk sendiri dan keterangan di layar, ada tindakan sadar yang bisa dijadikan dasar persetujuan. Ini menyederhanakan
   penjelasan di kebijakan privasi (UU PDP) dan Data Safety; bukan nasihat hukum, periksa ulang saat menyusun teksnya.
3. **Biaya mengikuti minat.** Hanya yang tertarik memakai AI yang menghabiskan anggaran Rp1,5 juta.
4. **Tidak melemahkan anti-penyalahgunaan.** Kunci kelayakan tetap perangkat, jadi menunggu menekan tombol tidak membuka celah.

**Titik penawaran (di mana tombol muncul).**

| Titik | Isi | Alasan |
|---|---|---|
| Kartu di Dashboard (setelah ada ≥ 5 transaksi tercatat) | "Coba semua fitur Ultimate gratis 30 hari. Tanpa kartu." | Sudah ada data; pengguna melihat nilai |
| Saat menyentuh fitur terkunci: Tabungan, Buku Kas, Scan AI, Laporan Bulanan, Excel | "Fitur ini ada di Ultimate. Coba gratis 30 hari?" | Niat tertinggi: pengguna sedang menginginkannya |
| Pengaturan > Langganan | Baris "Uji coba gratis" | Selalu bisa ditemukan |
| Slide onboarding terakhir | Informasi saja (tanpa tombol klaim) | Memberi tahu tanpa memulai jam |

Hanya ditawarkan bila **layak** (perangkat belum pernah klaim dan tidak sedang berlangganan berbayar); bila tidak layak,
tombol tidak ditampilkan dan tidak ada janji trial.

**Layar konfirmasi (satu langkah, bukan formulir).**
- Judul: "Coba semua fitur Ultimate gratis 30 hari".
- Isi singkat: apa yang terbuka (buku kas tambahan, Tabungan, scan dan ringkasan AI, Excel, backup cloud, tanpa iklan), dan
  kuota AI uji coba (60 scan, 6 ringkasan).
- Jujur soal akhir: "Tanpa kartu dan tidak ditagih. Setelah 30 hari kembali ke paket Gratis kecuali Anda berlangganan; data
  Anda tetap ada, buku kas tambahan terkunci."
- Satu kalimat privasi: "Untuk mencegah uji coba berulang, pengenal perangkat Anda dikirim dalam bentuk ber-hash."
- Tombol "Mulai uji coba" dan "Nanti saja". Menolak tidak menghabiskan apa pun dan bisa diulang kapan saja.

**Setelah dimulai.**
- Hitung mundur di Pengaturan dan kartu Dashboard ("Uji coba: 24 hari lagi").
- Pengingat opsional (memakai `NotificationSender` yang sudah ada) pada hari ke-23 dan ke-28, hanya bila izin notifikasi sudah
  ada; tidak meminta izin baru hanya untuk ini.
- Hari ke-30: dialog sekali (lihat 3.3) dengan daftar yang berubah dan tawaran Premium sebagai pijakan murah, Ultimate sebagai
  lanjutan.
- Pengguna yang membeli sebelum akhir trial tidak perlu melakukan apa-apa; entitlement berbayar berjalan sejak itu.

**Aturan kelayakan yang perlu Anda putuskan (menjawab "siapa yang ditawari").**

| Kelompok | Usulan | Alasan |
|---|---|---|
| Pengguna baru | Ya | Tujuan utama |
| Pengguna Gratis lama yang memperbarui aplikasi | **Ya, sekali** | Paling berpeluang: sudah punya data dan kebiasaan; tidak ada yang rugi (belum berbayar) |
| Pelanggan Premium aktif | **Ya, sebagai upsell Ultimate** (atau tidak) | Setelah 30 hari kembali ke Premium yang mereka bayar; trial tidak mengubah tagihan. Perlu uji interaksi dengan langganan Play (5.2) |
| Pelanggan Ultimate aktif | Tidak | Sudah punya |
| Perangkat yang sudah pernah klaim | Tidak (sisa hari bila masih berjalan) | Inti anti-ulang |

**Dampak pada angka.** Jumlah trial dimulai akan lebih kecil daripada model otomatis, tetapi kualitasnya lebih tinggi
(sudah punya data, dan lebih berminat), sehingga konversi per trial lebih baik dan biaya per pelanggan berbayar lebih rendah.
Ukur dua hal sejak awal: **persentase penawaran yang diterima** (per titik penawaran) dan **konversi trial → berbayar**, agar
titik penawaran yang buruk bisa dibuang.

**Yang perlu Anda putuskan:**
1. Setuju opt-in kontekstual (bukan otomatis)?
2. Pengguna Gratis lama (sebelum rilis ini) ikut ditawari, ya atau tidak?
3. Pelanggan Premium ditawari trial Ultimate sebagai upsell, ya atau tidak?
4. Pengingat hari ke-23 dan ke-28 diaktifkan?

### 10.4 Peringatan di dalam aplikasi (keputusan 2d)

Pengingat notifikasi hanya sampai ke pengguna yang mengizinkan notifikasi (dan ada yang mematikannya). Karena itu peringatan
utama ada **di dalam aplikasi**, tidak bergantung izin; notifikasi hanya penguat.

**Tahapan.** `sisa` = hari tersisa dari `trialEndsAt` (dibaca dari entitlement RevenueCat, bukan dari jam klaim di HP).

| Fase | Sisa hari | Kartu Dashboard | Banner | Dialog (sekali per tonggak) |
|---|---|---|---|---|
| Normal | 30 sampai 8 | Netral: "Uji coba Ultimate: N hari lagi" | - | - |
| Mendekati | 7 sampai 4 (hari ke-23 dst.) | Berwarna aksen: "Uji coba berakhir N hari lagi" + tombol "Lihat paket" | - | **Hari ke-23:** ringkasan "Yang akan berubah" |
| Mendesak | 3 sampai 1 (hari ke-27 dst.) | Warna peringatan, tombol utama "Lanjutkan berlangganan" | Banner tipis di atas tab utama, bisa ditutup per hari | **Hari ke-28:** pengingat kedua |
| Hari terakhir | < 24 jam | Merah: "Berakhir hari ini pukul HH:mm" | Banner tidak bisa ditutup hari itu | Dialog sekali saat dibuka |
| Berakhir | - | "Uji coba berakhir. Data Anda aman." + tawaran | - | Dialog akhir (3.3), lalu kartu menetap 7 hari |

**Isi dialog "Yang akan berubah"** (dihitung dari database lokal, bukan teks generik, supaya terasa nyata dan jujur):
- jumlah buku kas tambahan yang akan terkunci dan transaksi berulang di dalamnya yang akan dijeda;
- jumlah tabungan dan total saldonya (tetap bisa ditarik);
- fitur yang berhenti: scan dan ringkasan AI, Excel, backup cloud; iklan kembali;
- yang **tetap**: seluruh data, pencatatan di Buku Utama, ekspor CSV.
- Tombol: "Lihat paket" (Premium sebagai pijakan, Ultimate bila memakai buku/tabungan), "Ingatkan nanti" (menunda sampai tonggak
  berikutnya). Tidak ada tombol yang memblokir pemakaian.

**Aturan agar tidak mengganggu.**
1. Maksimal **satu** dialog per sesi aplikasi dan satu per tonggak (kunci di `KeyValueStore`: `trial_prompt_d23`, `_d28`, `_d30`, `_end`).
2. Tidak ditampilkan saat formulir transaksi terbuka atau saat kunci aplikasi (PIN) aktif; tunggu layar utama.
3. Berhenti total begitu entitlement berbayar aktif; kartu berubah menjadi ucapan terima kasih.
4. Teks bersifat informatif, tanpa hitung mundur agresif atau nada menakut-nakuti.

**Notifikasi (penguat, hanya bila izin sudah ada).** Dijadwalkan saat klaim berhasil lewat `NotificationSender` (pola sama
`agenda_reminder_service.dart`): hari ke-23 dan ke-28 pukul 10.00 waktu lokal; dibatalkan bila pengguna membeli. Tidak
meminta izin notifikasi hanya untuk ini; bila izin belum ada, peringatan dalam aplikasi sudah cukup.

**Tambahan untuk Fase 2 (aplikasi).** Widget `TrialStatusCard`, `TrialBanner`, dan `TrialMilestoneDialog` di
`lib/features/subscription/`; `TrialPromptPolicy` (murni, mudah diuji: input sisa hari, tonggak yang sudah dilihat, status
sesi → keputusan apa yang ditampilkan). Tes: setiap fase dan tonggak, tidak muncul dua kali, hilang setelah membeli, tidak
muncul di atas formulir.
