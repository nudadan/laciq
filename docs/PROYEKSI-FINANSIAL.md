# Proyeksi finansial LaciQ (disusun 2026-10-05)

> Ini PERKIRAAN dari asumsi di bawah, bukan ramalan dan bukan nasihat pajak. Jumlah pengguna dan angka konversi adalah
> tebakan yang wajar untuk aplikasi keuangan pribadi di Indonesia; ganti dengan data nyata setelah rilis. Hitungan ada di
> skrip `proyeksi` (lihat riwayat sesi) dan semua angka dibulatkan ke Rupiah terdekat. Kurs: Rp17.930/USD.

## 1. Harga dan alur potongan per pelanggan
Harga: Premium Rp7.500/bln atau Rp75.000/thn; Ultimate Rp12.500/bln atau Rp125.000/thn. Asumsi bauran pelanggan: 60% bulanan,
40% tahunan, sehingga harga efektif per bulan = **Premium Rp7.000** dan **Ultimate Rp11.667**.

Urutan potongan (per pelanggan per bulan):

| Langkah | Premium | Ultimate (AI tipikal) | Ultimate (AI kuota penuh) |
|---|---|---|---|
| Dibayar pelanggan | 7.000 | 11.667 | 11.667 |
| PPN 11% (dipungut Google, bukan beban Anda)* | -694 | -1.156 | -1.156 |
| Dasar sebelum biaya Google | 6.306 | 10.511 | 10.511 |
| Biaya layanan Google 15% (langganan) | -946 | -1.577 | -1.577 |
| Biaya AI (Gemini) | 0 | -258 | -2.280 |
| **Net sebelum PPh** | **5.360** | **8.676** | **6.654** |
| Persen dari harga yang dibayar | 77% | 74% | 57% |
| PPh final 0,5% (skema PT/CV, lihat bagian 3) | -32 | -53 | -53 |

\* Asumsi: harga yang tampil di Play Indonesia SUDAH termasuk PPN. **Verifikasi di Play Console > Monetisasi > Produk > harga**.
Bila ternyata harga dimasukkan sebelum pajak, net naik sekitar 10%: Premium 5.950, Ultimate 9.659.

Biaya AI: Scan struk ≈ Rp4,6/scan (terukur 1 Okt 2026); ringkasan Laporan Bulanan ≈ Rp30/ringkasan (perkiraan, BELUM terukur).
Tipikal = 30 scan + 4 ringkasan per bulan. Kuota penuh = 300 scan + 30 ringkasan (batas Worker). Fitur suara dan Excel TIDAK
berbiaya (diproses di HP dan layanan suara Android). Catatan: angka "Ultimate net ≈ Rp10.625" di dokumen lama mengabaikan PPN.

## 2. Tiga skenario (bulan ke-12, kondisi stabil)
| | Konservatif | Moderat | Optimis |
|---|---|---|---|
| Pengguna aktif bulanan | 1.000 | 5.000 | 20.000 |
| Konversi ke berbayar | 1,5% | 2,5% | 3% |
| Pelanggan berbayar | 15 (12 P + 3 U) | 125 (94 P + 31 U) | 600 (420 P + 180 U) |
| Uang masuk dari pengguna / bln | 119.000 | 1.019.667 | 5.040.000 |
| PPN (Google) | -11.793 | -101.048 | -499.459 |
| Biaya Google 15% | -16.081 | -137.793 | -681.081 |
| Biaya AI tipikal | -774 | -7.998 | -46.440 |
| **Net sebelum PPh / bln** | **90.352** | **772.828** | **3.813.019** |
| PPh final 0,5% (skema PT/CV) | -536 | -4.593 | -22.703 |
| **Net bersih / bln** | **89.816** | **768.235** | **3.790.317** |
| Net per tahun (kecepatan penuh) | 1,08 jt | 9,27 jt | 45,8 jt |
| Tahun pertama (pelanggan naik bertahap) | ≈ 0,54 jt | ≈ 4,6 jt | ≈ 22,9 jt |
| Net / uang masuk | 76% | 76% | 76% |
| Bila semua Ultimate memakai kuota AI penuh, net / bln | 84.286 | 710.146 | 3.449.059 |

Sensitivitas (5.000 pengguna aktif): konversi 1% → net Rp3,7 jt/thn; 2% → Rp7,4 jt; 2,5% → Rp9,3 jt; 4% → Rp14,9 jt.

## 3. Pajak (perkiraan, KONFIRMASIKAN dengan konsultan pajak)
- **PPN**: untuk jasa digital lewat Google Play, PPN dipungut dan disetor Google (pemungut PMSE). Anda tidak memungut atau
  melaporkannya selama belum PKP (batas omzet Rp4,8 miliar/tahun). Tarif efektif dihitung 11% (12% dengan DPP nilai lain 11/12).
- **PPh final UMKM 0,5% dari omzet** (PP 55/2022), jangka waktu: orang pribadi 7 tahun, CV/koperasi 4 tahun, PT 3 tahun.
  - **Orang pribadi**: omzet sampai Rp500 juta/tahun BEBAS PPh. Ketiga skenario di atas jauh di bawah itu, jadi **PPh = 0**.
  - **PT/CV**: tidak ada batas bebas pajak; 0,5% dari omzet bruto (angka di tabel memakai dasar sebelum biaya Google).
  - Di luar skema final (mis. pembukuan, tarif progresif) hitungannya berbeda; skema final biasanya paling ringan untuk omzet kecil.
- Dasar pengenaan yang tepat (omzet bruto sebelum atau sesudah biaya Google) perlu dipastikan oleh konsultan pajak. Selisihnya kecil.
- Pendapatan iklan AdMob juga termasuk omzet; potongan pajak di sumber untuk pembayaran dari Google ke Indonesia biasanya tidak ada,
  tetapi isi formulir pajak AdMob dengan benar.
- Pajak tidak mengubah kesimpulan: yang paling besar memakan hasil adalah PPN (≈9%) dan biaya Google (15%), bukan PPh.

## 4. Pendapatan iklan AdMob (kepercayaan RENDAH)
Iklan banner hanya di paket gratis setelah masa bebas iklan 30 hari, dan akun AdMob belum disetujui (Rp0 sekarang). Perkiraan kasar:
eCPM banner Indonesia $0,10-0,30, sekitar 200 tayangan per pengguna gratis aktif per bulan → **≈ Rp540 per pengguna gratis per
bulan**: konservatif ≈ Rp0,5 jt/bln, moderat ≈ Rp2,6 jt/bln, optimis ≈ Rp10,4 jt/bln (sebelum PPh). Bagi hasil AdMob sudah masuk di eCPM.
Angka ini sangat bergantung pada eCPM nyata; jangan dijadikan dasar keputusan sebelum akun disetujui dan ada data 1-2 bulan.

## 5. Biaya lain
- **RevenueCat**: gratis sampai pendapatan terlacak sekitar $2.500/bln (≈ Rp44,8 jt); di atasnya 1%. Tidak berlaku di ketiga skenario.
- **Cloudflare Workers/KV**: paket gratis cukup untuk volume ini; paket berbayar $5/bln (≈ Rp90 rb) bila melewati batas.
- **Domain/hosting situs**: memakai server dan domain yang sudah ada (biaya tambahan kecil).
- **Gemini**: sudah dihitung per pemakaian di atas; pasang anggaran dan peringatan biaya di Cloud Billing.
- **Tidak dihitung**: biaya mendapatkan pengguna (iklan/promosi), waktu pengembangan, refund dan chargeback Play (umumnya beberapa persen),
  selisih kurs, dan biaya pengelolaan akun bank.

## 6. Kesimpulan dan risiko
1. Dari setiap Rp1 yang dibayar pelanggan, sekitar **Rp0,76 sampai Rp0,77** sampai ke Anda (Premium 77%, Ultimate 74% pada pemakaian
   tipikal, 57% bila memakai kuota AI penuh). AI bukan beban besar: bahkan pengguna Ultimate yang menghabiskan semua kuota tetap menyisakan Rp6.654/bln.
2. Pendapatan sangat ditentukan jumlah pengguna dan konversi, bukan biaya. Pada skala 1.000-5.000 pengguna aktif hasilnya Rp1-9 juta/tahun;
   baru berarti di atas 20.000 pengguna aktif. Pemasaran dan retensi lebih menentukan daripada penghematan biaya AI.
3. Harga rendah (Rp7.500) dibanding potongan tetap persentase berarti margin sehat, tetapi nominalnya kecil per pelanggan. Pertimbangkan uji
   harga dan paket tahunan sebagai pendorong utama (pelanggan tahunan = kas di muka, churn lebih rendah).
4. Risiko: ringkasan AI belum terukur biayanya; kuota 300 scan per pengguna Ultimate bisa disalahgunakan bila ID bocor (sudah ada batas
   harian 15); perubahan kebijakan Play (biaya, pajak); akun AdMob belum disetujui.
5. Ukur dulu, lalu revisi: pantau konversi, retensi, token Gemini (log `ai_usage`), dan pendapatan AdMob setelah 1-2 bulan produksi.
