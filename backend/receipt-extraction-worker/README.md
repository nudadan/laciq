# Worker ekstraksi struk (fitur Ultimate)

Cloudflare Worker: menerima teks OCR struk + daftar kategori pengguna, memastikan pemanggil punya
entitlement `ultimate` aktif (server-ke-server ke RevenueCat), membatasi 60 scan/bulan, lalu meminta
Claude Haiku 4.5 mengembalikan `merchant` + `categoryId`. Desain lengkap:
`docs/RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md` §3.

`POST /extract` — body `{appUserId, rawText, categories:[{id,name}]}` →
`200 {merchant, categoryId, remaining}` · `403 not_ultimate` · `429 quota_exceeded` · `502` gagal hulu.

## Deploy (sekali, oleh pemilik)

```bash
cd backend/receipt-extraction-worker
npm install
npx wrangler login
npx wrangler kv namespace create RATE_LIMIT      # tempel id ke wrangler.toml
npx wrangler secret put ANTHROPIC_API_KEY        # dari console.anthropic.com
npx wrangler secret put REVENUECAT_SECRET_KEY    # RevenueCat > API keys > Secret key (sk_...)
npx wrangler deploy                              # mencetak URL https://....workers.dev
```

Build app dengan URL itu (tanpa ini fitur AI mati diam-diam, scan struk tetap jalan):

```bash
flutter build appbundle --dart-define=AI_EXTRACTION_URL=https://<worker>.workers.dev/extract
```

## Uji

`npm test` (logika handler, tanpa jaringan) dan `npm run typecheck`.

## Catatan

- Kuota di KV bersifat eventually consistent: permintaan paralel bisa melewati batas sedikit. Cukup untuk
  batas biaya; bukan penagihan.
- Endpoint RevenueCat v1 membuat record pelanggan kosong untuk ID yang belum dikenal. ID divalidasi ketat
  dan dibatasi 60/bulan hanya untuk Ultimate; untuk ketahanan ekstra aktifkan Cloudflare Rate Limiting/WAF per IP.
- Teks struk tidak disimpan di server dan tidak dicatat di log.
