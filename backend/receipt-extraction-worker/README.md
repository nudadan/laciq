# Worker ekstraksi struk (fitur Ultimate)

Cloudflare Worker: menerima teks OCR struk + daftar kategori pengguna, memastikan pemanggil punya
entitlement `ultimate` aktif (server-ke-server ke RevenueCat), membatasi pemakaian (300 scan/bulan dan
15/hari per pengguna), lalu meminta model AI mengembalikan `merchant`, `categoryId`, `total`, dan `date`.
Penyedia: **Google Gemini** (paid tier); Claude dipertimbangkan lalu tidak dipakai. Desain dan alasan pemilihan:
`docs/RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md` (B0, B3) dan `docs/RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md` §3.

`POST /extract` — body `{appUserId, rawText, categories:[{id,name}]}` →
`200 {merchant, categoryId, total, date, remaining}` · `403 not_ultimate` ·
`429 quota_exceeded` (bulanan) / `daily_limit_exceeded` / `rate_limited` (per IP) · `502` gagal hulu.
`total` (Rupiah bulat, 1–1.000.000.000) dan `date` (`YYYY-MM-DD`, maks 5 tahun ke belakang dan 1 hari ke
depan) divalidasi di server; nilai yang tidak wajar dikirim sebagai `null`.

`POST /report-insight` (2026-10-04) — body `{appUserId, report:{month, daysElapsed, daysInMonth, income, expense,
previousExpense, projectedExpense, categories:[{name,total,previousTotal}] (maks 8), budgets:[{name,percent}] (maks 6)}}`
→ `200 {summary, remaining}` · `403 not_ultimate` · `429 quota_exceeded` / `daily_limit_exceeded` / `rate_limited` ·
`502 narration_failed`. Hanya ANGKA agregat yang diterima (tanpa catatan/toko/tanggal/foto). Kuota terpisah dari scan
(`REPORT_MONTHLY_LIMIT` 30, `REPORT_DAILY_LIMIT` 5; kunci KV `report-usage:`/`report-usage-day:`) dan hanya dihitung
bila berhasil. Keluaran model dibersihkan dan DITOLAK bila memuat tautan atau nominal Rupiah yang tidak ada di data
(`validateNarrative` di `report_prompt.ts`); model cadangan dicoba lalu 502. Log hanya `ai_usage kind=report ...`
(jumlah token) dan `ai_report_result chars=... categories=...`, tanpa isi. **Sudah di-deploy 2026-10-04** (versi `cdbd022b`; uji asap: 400/403/405 sesuai, `/extract` tetap hidup; belum dicoba dengan Gemini sungguhan).

## Deploy (sekali, oleh pemilik)

Prasyarat untuk Gemini: kunci API dari **project Google Cloud terpisah** (bukan project OAuth aplikasi)
dengan **billing aktif (paid tier)**. Free tier dipakai Google untuk memperbaiki produk dan melarang data
pribadi, jadi tidak boleh dipakai untuk data pengguna. Pasang anggaran + peringatan biaya di Cloud Billing.

```bash
cd backend/receipt-extraction-worker
npm install
npx wrangler login
npx wrangler kv namespace create RATE_LIMIT      # tempel id ke wrangler.toml
npx wrangler secret put GEMINI_API_KEY           # kunci paid tier
npx wrangler secret put REVENUECAT_SECRET_KEY    # RevenueCat > API keys > Secret key (sk_...)
npx wrangler deploy                              # memasang ke https://dompetku-api.hardan-ti.com
```

Produksi dipasang di domain sendiri (`routes` + `workers_dev = false` di `wrangler.toml`; zona harus ada di
Cloudflare, hostname satu tingkat di bawah domain). Alamat: `https://dompetku-api.hardan-ti.com/extract`.

Model dan penyedia diatur di `wrangler.toml` (`AI_PROVIDER`, `AI_MODEL`, `AI_MODEL_FALLBACK`, `DAILY_LIMIT`,
opsional `AI_THINKING_CONFIG`), bukan di kode.

**Model cadangan.** Bila model utama gagal (HTTP 404 karena dihentikan Google, 5xx, keluaran rusak), Worker mencoba
model di `AI_MODEL_FALLBACK` berurutan (maks. 3 model termasuk utama). Kunci ditolak (401/403) langsung gagal tanpa
mencoba cadangan. Model yang 404 dilewati 10 menit per isolate agar tidak dicoba tiap permintaan; galat sementara
tidak membuat model dilewati. Setiap kegagalan dicatat sebagai `ai_model_failed model=... reason=...` (tanpa isi
struk) dan **log inilah yang sebaiknya dipasangi peringatan**: model utama bermasalah walau pengguna tidak merasakan.
Kosongkan `AI_THINKING_CONFIG` bila cadangan berasal dari seri berbeda (format `thinkingConfig` berbeda antarseri). Log Worker mencatat `ai_usage model=… in=… out=… thoughts=…`
(jumlah token saja, tanpa isi struk) untuk mengukur biaya nyata.

**Sebelum dibuka untuk pengguna:** kirim satu permintaan nyata (`curl`) untuk memastikan bentuk keluaran
terstruktur dan `thinkingConfig` Gemini diterima. Detail HTTP terkumpul di `src/gemini.ts`
(`buildRequest`/`parseResponse`).

Build app dengan URL itu (tanpa ini fitur AI mati diam-diam, scan struk tetap jalan):

```bash
flutter build appbundle --dart-define=AI_EXTRACTION_URL=https://<worker>.workers.dev/extract
```

## Uji

`npm test` (handler, Gemini, pemilih penyedia, cache entitlement; tanpa jaringan) dan `npm run typecheck`.

## Evaluasi model (memilih model)

`eval/` membandingkan kandidat model pada kumpulan struk berlabel (total, tanggal, toko, kategori) dan
mencetak tabel benar/salah serta token terpakai. Tidak ikut di-deploy. Lihat `eval/README.md`.

## Catatan

- Kuota di KV bersifat eventually consistent: permintaan paralel bisa melewati batas sedikit. Cukup untuk
  batas biaya; bukan penagihan.
- Hasil cek entitlement di-cache di KV (5 menit untuk `true`, 1 menit untuk `false`) agar RevenueCat tidak
  dipanggil di setiap permintaan. Pelanggan baru terbuka paling lama 1 menit setelah membeli.
- Endpoint RevenueCat v1 membuat record pelanggan kosong untuk ID yang belum dikenal. ID divalidasi ketat.
  Verifikasi memakai ID anonim RevenueCat tanpa bukti kepemilikan: risiko diterima (ID sulit ditebak, ada batas
  harian/bulanan, ada pembatas per IP bila diaktifkan).
- Teks struk tidak disimpan di server dan tidak dicatat di log.

## Uji coba Ultimate tanpa kartu (`POST /trial/claim`)

Rencana lengkap: [docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md](../../docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md).
**Bawaan mati** (`TRIAL_ENABLED = "0"`); menyalakannya butuh rahasia `TRIAL_HASH_SECRET`.

Permintaan: `{ "appUserId": "<ID RevenueCat>", "deviceId": "<ANDROID_ID>", "integrityToken": "<opsional>" }`.

| Jawaban | Arti |
|---|---|
| `201 {status:"granted", endsAt}` | Trial baru diberikan (hibah `ultimate` + `premium` sampai `endsAt`) |
| `200 {status:"active"}` | Idempoten: hibah sudah aktif pada ID ini |
| `200 {status:"resumed", endsAt}` | Pasang ulang di masa trial: ID baru mendapat SISA hari |
| `409 already_used` | Perangkat ini sudah memakai trial dan sudah habis |
| `409 already_ultimate` | Pelanggan Ultimate berbayar |
| `429 trial_paused` / `promo_budget_exhausted` | Pagar global; hak trial perangkat TIDAK terpakai |
| `403 integrity_*`, `503 integrity_unavailable` | Hanya di mode penegakan Play Integrity |
| `502 grant_ignored` / `grant_failed` | Hibah tidak berlaku / gagal; hak perangkat TIDAK terpakai |
| `503 trial_disabled` | Saklar mati atau rahasia belum dipasang |

`POST /trial/status` (baca saja, tanpa efek samping; badan sama) menjawab `{state, endsAt?}` dengan `state` salah satu
`disabled | ultimate | active | resumable | used | paused | available`. Dipakai aplikasi agar tidak menawarkan trial yang
akan ditolak.

Sifat penting:
- Kunci kelayakan = `HMAC-SHA256(TRIAL_HASH_SECRET, deviceId)` di KV (`trial:<hash>`); `deviceId` mentah tidak disimpan.
  Catatan **terhapus otomatis `TRIAL_RECORD_RETENTION_DAYS` (365) hari setelah uji coba berakhir**; setelah itu perangkat boleh
  mencoba lagi. Terapkan SEBELUM `TRIAL_ENABLED = "1"` pertama kali: catatan yang sudah ditulis tanpa TTL tidak akan kedaluwarsa.
  **Jangan mengubah `TRIAL_HASH_SECRET` setelah dipakai**: semua perangkat tampak baru.
- Worker **tidak mempercayai HTTP 201** dari RevenueCat: setelah menghibahkan, ia membaca ulang entitlement dan memeriksa
  `expires_date` (hibah dalam 2 jam dari hibah promosional sebelumnya pada ID yang sama diabaikan diam-diam).
- Pengguna uji coba (entitlement `rc_promo_*` tanpa langganan berbayar aktif) memakai kuota uji coba
  (`TRIAL_*`) dan anggaran AI promo global `PROMO_AI_MONTHLY_BUDGET_RP` (perkiraan biaya: scan Rp5, ringkasan Rp30).
  Pelanggan berbayar tidak terpengaruh.
- `INTEGRITY_MODE`: pendekode token Play Integrity BELUM dipasang (butuh kredensial akun layanan Google). Hanya
  `off`/`shadow` yang aman dipakai sekarang; `lenient`/`strict` akan menolak semua klaim (`integrity_unavailable`).

Menyalakan (urutan):
```bash
npx wrangler secret put TRIAL_HASH_SECRET     # acak panjang, simpan di pengelola kata sandi
# ubah TRIAL_ENABLED = "1" di wrangler.toml, lalu:
npx wrangler deploy
```
