# Proyeksi finansial LaciQ (disusun 2026-10-05, asumsi PPN dikoreksi 2026-10-09)

> Ini PERKIRAAN dari asumsi di bawah, bukan ramalan dan bukan nasihat pajak. Jumlah pengguna dan angka konversi adalah
> tebakan yang wajar untuk aplikasi keuangan pribadi di Indonesia; ganti dengan data nyata setelah rilis. Hitungan ada di
> skrip `proyeksi` (lihat riwayat sesi) dan semua angka dibulatkan ke Rupiah terdekat. Kurs: Rp17.930/USD.
>
> **Koreksi 2026-10-09:** pesanan nyata pertama membuktikan bahwa harga di Play adalah harga jual TANPA PPN; PPN 11% ditambahkan
> di atas harga. Versi 2026-10-05 mengasumsikan harga sudah termasuk PPN, sehingga pendapatan per pelanggan dihitung sekitar 11%
> terlalu rendah. Semua tabel di bawah sudah dihitung ulang (Excel: `Asumsi!B12` = 0).

## 1. Harga dan alur potongan per pelanggan
Harga jual di Play (tanpa PPN): Premium Rp7.500/bln atau Rp75.000/thn; Ultimate Rp12.500/bln atau Rp125.000/thn. Asumsi bauran
pelanggan: 60% bulanan, 40% tahunan, sehingga harga jual efektif per bulan = **Premium Rp7.000** dan **Ultimate Rp11.667**.

**Bukti dari pesanan nyata** (Play Console > Pengelolaan pesanan, 8 Okt 2026, Ultimate bulanan, GPA.3304-9982-3764-47106):
harga jual Rp12.500 + pajak Rp1.375 = total Rp13.875; estimasi pendapatan USD 0,59 = Rp12.500 x 85% / Rp17.930. Jadi biaya Google 15%
dihitung dari harga jual, dan PPN dibayar pelanggan di atas harga.

Urutan potongan (per pelanggan per bulan):

| Langkah | Premium | Ultimate (AI tipikal) | Ultimate (AI kuota penuh) |
|---|---|---|---|
| Harga jual (dasar pendapatan Anda) | 7.000 | 11.667 | 11.667 |
| *Info:* PPN 11% ditambahkan di atas harga (dipungut dan disetor Google, bukan pendapatan atau beban Anda) | +770 | +1.283 | +1.283 |
| *Info:* total yang dibayar pelanggan | 7.770 | 12.950 | 12.950 |
| Biaya layanan Google 15% dari harga jual | -1.050 | -1.750 | -1.750 |
| Biaya AI (Gemini) | 0 | -258 | -2.280 |
| **Net sebelum PPh** | **5.950** | **9.659** | **7.637** |
| Persen dari harga jual | 85% | 83% | 65% |
| Persen dari total yang dibayar pelanggan | 77% | 75% | 59% |
| PPh final 0,5% dari harga jual (skema PT/CV, lihat bagian 3) | -35 | -58 | -58 |
| **Net setelah PPh PT/CV** | **5.915** | **9.600** | **7.578** |

Harga yang tampil kepada pelanggan di lembar bayar Play (Rp13.875 untuk Ultimate bulanan) lebih tinggi daripada harga yang kita
tulis (Rp12.500). Lihat `docs/TEKS-PPN.md` untuk teks keterangan "belum termasuk PPN".

Biaya AI: Scan struk ≈ Rp4,6/scan (terukur 1 Okt 2026); ringkasan Laporan Bulanan ≈ Rp30/ringkasan (perkiraan, BELUM terukur).
Tipikal = 30 scan + 4 ringkasan per bulan. Kuota penuh = 300 scan + 30 ringkasan (batas Worker). Fitur suara dan Excel TIDAK
berbiaya (diproses di HP dan layanan suara Android). Catatan: angka "Ultimate net ≈ Rp10.625" di dokumen lama ternyata benar untuk pelanggan bulanan (Rp12.500 x 85%), sesuai estimasi Play USD 0,59.

## 2. Tiga skenario (bulan ke-12, kondisi stabil)
| | Konservatif | Moderat | Optimis |
|---|---|---|---|
| Pengguna aktif bulanan | 1.000 | 5.000 | 20.000 |
| Konversi ke berbayar | 1,5% | 2,5% | 3% |
| Pelanggan berbayar | 15 (12 P + 3 U) | 125 (94 P + 31 U) | 600 (420 P + 180 U) |
| Harga jual dari pelanggan / bln (dasar pendapatan) | 119.000 | 1.019.667 | 5.040.000 |
| *Info:* PPN di atas harga (dipungut Google) | +13.090 | +112.163 | +554.400 |
| *Info:* total dibayar pelanggan / bln | 132.090 | 1.131.830 | 5.594.400 |
| Biaya Google 15% | -17.850 | -152.950 | -756.000 |
| Biaya AI tipikal | -774 | -7.998 | -46.440 |
| **Net sebelum PPh / bln** | **100.376** | **858.719** | **4.237.560** |
| PPh final 0,5% (skema PT/CV) | -595 | -5.098 | -25.200 |
| **Net bersih / bln** | **99.781** | **853.620** | **4.212.360** |
| Net per tahun (kecepatan penuh) | 1,20 jt | 10,24 jt | 50,55 jt |
| Tahun pertama (pelanggan naik bertahap) | ≈ 0,60 jt | ≈ 5,12 jt | ≈ 25,27 jt |
| Net / harga jual | 84% | 84% | 84% |
| Bila semua Ultimate memakai kuota AI penuh, net sebelum PPh / bln | 94.310 | 796.037 | 3.873.600 |

Sensitivitas (5.000 pengguna aktif, 25% Ultimate, net sebelum PPh per tahun): konversi 1% → Rp4,1 jt; 2% → Rp8,3 jt; 3% → Rp12,4 jt;
4% → Rp16,5 jt. Titik impas: untuk net Rp5 jt per bulan dibutuhkan ≈ 728 pelanggan berbayar, atau ≈ 36.400 pengguna aktif pada konversi 2%.

## 3. Pajak (perkiraan, KONFIRMASIKAN dengan konsultan pajak)
- **PPN**: untuk jasa digital lewat Google Play, PPN dipungut dan disetor Google (pemungut PMSE) dan **ditambahkan di atas harga jual**
  (terbukti dari pesanan nyata: Rp12.500 + Rp1.375). Anda tidak memungut atau melaporkannya selama belum PKP (batas omzet
  Rp4,8 miliar/tahun). Tarif efektif 11% (12% dengan DPP nilai lain 11/12).
- **PPh final UMKM 0,5% dari omzet** (PP 55/2022), jangka waktu: orang pribadi 7 tahun, CV/koperasi 4 tahun, PT 3 tahun.
  - **Orang pribadi**: omzet sampai Rp500 juta/tahun BEBAS PPh. Ketiga skenario di atas jauh di bawah itu, jadi **PPh = 0**.
  - **PT/CV**: tidak ada batas bebas pajak; 0,5% dari omzet bruto (angka di tabel memakai harga jual, sebelum biaya Google dan tanpa PPN).
  - Di luar skema final (mis. pembukuan, tarif progresif) hitungannya berbeda; skema final biasanya paling ringan untuk omzet kecil.
- Dasar pengenaan yang tepat (omzet bruto sebelum atau sesudah biaya Google) perlu dipastikan oleh konsultan pajak. Selisihnya kecil.
- Pendapatan iklan AdMob juga termasuk omzet; potongan pajak di sumber untuk pembayaran dari Google ke Indonesia biasanya tidak ada,
  tetapi isi formulir pajak AdMob dengan benar.
- Pajak tidak mengubah kesimpulan: yang paling besar memakan hasil adalah biaya Google (15% dari harga jual). PPN tidak memotong pendapatan
  Anda karena dibayar pelanggan di atas harga; PPh final hanya 0,5%.

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
1. Dari setiap Rp1 **harga jual**, sekitar **Rp0,83 sampai Rp0,85** sampai ke Anda (Premium 85%, Ultimate 83% pada pemakaian tipikal,
   65% bila memakai kuota AI penuh). Dari total yang dibayar pelanggan termasuk PPN, bagiannya Rp0,75 sampai Rp0,77. AI bukan beban
   besar: bahkan pengguna Ultimate yang menghabiskan semua kuota tetap menyisakan Rp7.637/bln.
2. Pendapatan sangat ditentukan jumlah pengguna dan konversi, bukan biaya. Pada skala 1.000-5.000 pengguna aktif hasilnya Rp1-10 juta/tahun;
   baru berarti di atas 20.000 pengguna aktif. Pemasaran dan retensi lebih menentukan daripada penghematan biaya AI.
3. Harga rendah (Rp7.500) dibanding potongan tetap persentase berarti margin sehat, tetapi nominalnya kecil per pelanggan. Pertimbangkan uji
   harga dan paket tahunan sebagai pendorong utama (pelanggan tahunan = kas di muka, churn lebih rendah).
4. Risiko: ringkasan AI belum terukur biayanya; kuota 300 scan per pengguna Ultimate bisa disalahgunakan bila ID bocor (sudah ada batas
   harian 15); perubahan kebijakan Play (biaya, pajak); akun AdMob belum disetujui.
5. Ukur dulu, lalu revisi: pantau konversi, retensi, token Gemini (log `ai_usage`), dan pendapatan AdMob setelah 1-2 bulan produksi.
