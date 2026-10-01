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
