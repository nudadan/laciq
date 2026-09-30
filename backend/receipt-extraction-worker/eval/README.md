# Evaluasi model ekstraksi struk

Membandingkan model Gemini pada struk berlabel. Dipakai di fase B3 rencana Ultimate untuk memilih
model **termurah yang lolos**: benar pada `total` di ≥ 8 dari 10 struk dan tidak lebih buruk dari heuristik
pada struk yang heuristiknya sudah benar.

```bash
cd backend/receipt-extraction-worker
GEMINI_API_KEY=... \
  node eval/run.ts gemini:gemini-3.1-flash-lite gemini:gemini-3.5-flash-lite gemini:gemini-3.8-flash
```

Keluaran: tabel per struk (total, tanggal, toko, kategori) dan jumlah token, lalu ringkasan per kandidat.
Salin ringkasannya ke `docs/RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md` §8.

- `receipts.json` berisi 10 struk **sintetis** (tidak berasal dari pengguna), termasuk kasus yang gagal di
  heuristik on-device (SPBU dua kolom). Aman dikirim ke free tier.
- Struk nyata: tambahkan ke berkas terpisah (`EVAL_FILE=...`) setelah **menyamarkan** nama, nomor kartu, dan
  alamat, dan hanya kirim lewat **paid tier**. Jangan commit struk nyata.
- Skor dihitung SETELAH validasi seperti di produksi (`sanitizeTotal`/`sanitizeDate`), jadi mencerminkan yang
  dilihat pengguna. Nama toko benar bila salah satu memuat yang lain (tanpa huruf besar/kecil dan tanda baca).
- Kolom "Token in/out" berasal dari log `ai_usage`; pakai untuk menghitung biaya per scan dari harga resmi.
- Tanpa kunci untuk suatu penyedia, kandidatnya tampil sebagai galat (tidak menghentikan seluruh evaluasi).
