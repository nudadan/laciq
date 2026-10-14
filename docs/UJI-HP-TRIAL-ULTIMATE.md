# Daftar uji HP: uji coba Ultimate 30 hari tanpa kartu

> Dibuat 2026-10-14. Menutup dua langkah operasional terakhir sebelum rilis
> ([RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md](RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md), Fase 2):
>
> - **Langkah 2:** membuktikan di HP dengan build **bertanda tangan Play** bahwa trial bekerja ujung ke ujung, terutama bahwa
>   `ANDROID_ID` bertahan pasang ulang dengan kunci Play (di Fase 0 baru terbukti dengan kunci uji).
> - **Langkah 3:** membuktikan interaksi dengan **pembelian sungguhan** (license tester): pelanggan Premium yang sedang trial lalu membeli
>   Ultimate harus **menggantikan** langganan Premium, bukan menagih dua langganan.
>
> Melengkapi, bukan mengganti, [UJI-TRIAL-LANGGANAN.md](UJI-TRIAL-LANGGANAN.md) (U1-U8: trial Play 15 hari dan perilaku langganan).

## 0. Aturan berhenti
Hentikan pengujian dan JANGAN rilis bila salah satu terjadi:

| Temuan | Artinya | Tindakan |
|---|---|---|
| **A4** gagal: `ANDROID_ID` berubah setelah pasang ulang dari Play | Pagar anti-ulang tidak berlaku pada kunci Play | Rancangan L7 (Block Store/device recall) dibutuhkan; trial tidak boleh dinyalakan |
| **B2** gagal: Play > Langganan menunjukkan **dua langganan aktif** (Premium dan Ultimate) | Penagihan ganda | Perbaiki penggantian produk sebelum rilis |
| Pasang ulang + restore setelah trial habis (**A6**) memberi trial baru | Anti-ulang bocor | Periksa kunci `trial:` di KV dan rahasia HMAC |
| Pelanggan berbayar terkena kuota trial (**B1-B3**: AI berhenti di 60 scan padahal berbayar) | Pengenal sumber salah | Periksa `entitlementStateOf` di Worker |

## 1. Persiapan (sekali)

### 1.1 Build dan pemasangan
- [ ] Naikkan versi di `pubspec.yaml` (harus **lebih besar dari 1.0.0+14**, mis. `1.0.0+15`). Build AAB rilis seperti rilis sebelumnya
      (lihat [RILIS-1.0.0+12.md](RILIS-1.0.0+12.md); jangan mencetak isi `android/key.properties`).
- [ ] Unggah ke **Pengujian internal** di Play Console, tambahkan akun tester ke daftar penguji, dan pasang dari tautan opt-in.
- [ ] Ekspor **backup berkas** dari build 14 sebelum memperbarui (Pengaturan > Data > **Backup data**). Build baru memigrasi skema v10 → v11;
      pemulihan lewat backup adalah jaring pengaman.
- [ ] Pasang pembaruan **dari Play** (bukan `adb install`/debug). Memasang dari Play inilah yang membuat kunci tanda tangan = kunci Play.
- [ ] HP: akun Google aktif di Play = akun license tester. Pada Xiaomi/Redmi pakai profil utama (bukan XSpace).

### 1.2 Worker
- [ ] `wrangler secret put TRIAL_HASH_SECRET` (acak panjang, simpan di pengelola kata sandi; **jangan diubah** setelah dipakai).
- [ ] `REVENUECAT_SECRET_KEY` Worker berizin **menulis** (sudah terbukti pada kunci uji Fase 0; pastikan kunci Worker sama).
- [ ] Ubah `TRIAL_ENABLED = "1"` di `wrangler.toml`, `npx wrangler deploy`.
- [ ] Cek: `TRIAL_DAILY_CLAIM_CAP`, `PROMO_AI_MONTHLY_BUDGET_RP` (Rp1.350.000), `INTEGRITY_MODE = "shadow"`.
- Aman dinyalakan sekarang: hanya build internal yang memuat UI trial. Pengguna produksi (build 14) tidak memanggil `/trial/*`.
- Tombol darurat: `TRIAL_ENABLED = "0"` lalu deploy. Trial yang sudah berjalan tidak terpengaruh; klaim baru ditolak.

### 1.3 Alat di PC
Git Bash, dari `E:\Developments\DompetKu`:
```bash
source /e/Developments/tools/dev-env.sh
read -rs REVENUECAT_SECRET_KEY      # ketik/tempel kunci, Enter (tidak terlihat); jangan tempel ke chat
export REVENUECAT_SECRET_KEY
```
- [ ] `ID` lengkap RevenueCat perangkat uji: aplikasi hanya menampilkan **6 karakter terakhir** (Pengaturan > Langganan, "ID pengguna: …xxxxxx").
      Ambil ID lengkap di RevenueCat > Customers dengan mencari 6 karakter itu. (Halaman Langganan dibuka dari Pengaturan > Langganan > ketuk tile Upgrade.) Catat: `ID = $RCAnonymousID:…`
- [ ] Tempat melihat server (lihat 1.4).

### 1.4 Perintah bantu
Ganti `<ID>` (kutip tunggal karena mengandung `$`):

| Keperluan | Perintah |
|---|---|
| Keadaan entitlement, sumber (uji coba/berbayar), keputusan Worker, langganan berbayar aktif | `node tools/fase0-trial/rc_promo_check.mjs '<ID>' --show` |
| Cabut hibah uji coba (mensimulasikan trial berakhir) | `node tools/fase0-trial/rc_promo_check.mjs '<ID>' --revoke-only` |
| Beri hibah selama N menit tanpa dicabut (untuk C-series) | `node tools/fase0-trial/rc_promo_check.mjs '<ID>' --minutes N --keep` |
| Catatan perangkat di Worker | `cd backend/receipt-extraction-worker && npx wrangler kv key list --binding RATE_LIMIT --prefix "trial:" --remote` |
| Isi satu catatan | `npx wrangler kv key get "trial:<hash>" --binding RATE_LIMIT --remote` |
| Log klaim (tanpa data pribadi) | `npx wrangler tail` lalu cari `trial_claim result=` |
| Anggaran promo bulan ini | `npx wrangler kv key get "promo-cost:2026-10" --binding RATE_LIMIT --remote` |

Catatan: `--remote` bisa tidak perlu pada versi wrangler tertentu; hapus bila ditolak. KV eventually consistent (hingga ±60 dtk).
Cache entitlement di Worker 60 detik untuk hibah uji coba. Setelah mengubah sesuatu di server, **matikan paksa aplikasi lalu buka lagi**
(status trial dimuat sekali per sesi).

## 2. Seri A: trial ujung ke ujung dengan kunci Play (langkah 2)

Mulai dari kondisi: paket **Gratis**, perangkat belum pernah klaim, ≥ 5 transaksi tercatat.

### A1. Penawaran muncul di tempat yang tepat
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Buka Ringkasan | **Kartu "Coba semua fitur Ultimate gratis 30 hari"** (hanya karena ≥ 5 transaksi) | |
| Cek Pengaturan > Langganan | Baris "Coba Ultimate gratis 30 hari" | |
| Lainnya > Tabungan | Lembar konfirmasi trial (bukan halaman langganan) | |
| Tutup kartu Ringkasan (X) | Kartu hilang; muncul lagi hanya setelah 3 hari | |

### A2. Lembar konfirmasi jujur dan lengkap
| Yang harus terlihat | Hasil |
|---|---|
| Manfaat: buku kas tambahan, Tabungan, scan dan ringkasan AI (60 scan, 6 ringkasan), Excel/Laporan/backup cloud, tanpa iklan | |
| "Tanpa kartu dan tanpa ditagih" | |
| "Setelah 30 hari kembali ke paket Gratis… buku kas tambahan hanya terkunci" | |
| Kalimat privasi: pengenal perangkat dikirim ber-hash, tidak ada data keuangan | |
| Tombol: **Mulai uji coba**, **Nanti saja**, **Lihat paket** | |
| Ketuk **Nanti saja**: tidak ada klaim (cek `wrangler kv key list` kosong / tidak bertambah) | |

### A3. Memulai trial
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Ketuk **Mulai uji coba** | Pesan "Uji coba Ultimate aktif sampai <tanggal ±30 hari>" | |
| Ringkasan | Kartu hitung mundur "Uji coba Ultimate: 30 hari lagi" (kartu ajakan hilang) | |
| Lainnya | Tabungan dan Buku Kas terbuka (tidak berlabel "Fitur Ultimate") | |
| Banner iklan | Hilang (selama trial) | |
| Scan struk dengan AI | Berjalan; toko, kategori, total terisi | |
| `--show` | Ultimate aktif, **sumber: uji coba (promo)**, langganan berbayar aktif: 0 | |
| KV | Satu catatan `trial:<hash>` baru; `trial-day:<tanggal>` = 1 | |
| `wrangler tail` | `trial_claim result=granted` | |

### A4. ANDROID_ID bertahan setelah pasang ulang (kunci Play) ⭐
Inti langkah 2. Catat 6 karakter terakhir ID sebelum dan sesudah.
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Catat ID RevenueCat (6 karakter) di Pengaturan > Langganan: `…______` | | |
| **Copot** LaciQ (bukan hapus data), lalu **pasang ulang dari Play** (build internal yang sama) | Aplikasi mulai bersih (onboarding) | |
| Setelah onboarding, catat ID RevenueCat: `…______` | **ID berbeda** dari sebelumnya (terbukti tidak bisa dipakai sebagai kunci) | |
| Catat 5 transaksi lagi, buka Ringkasan | Kartu **"Lanjutkan uji coba Ultimate"** (bukan "Coba … 30 hari") | |
| Ketuk, lembar menyebut "Lanjutkan uji coba … (N hari lagi)" | N ≈ sisa hari asli (bukan 30) | |
| **Lanjutkan uji coba** | Fitur Ultimate terbuka; hitung mundur menunjukkan **sisa hari lama** | |
| `wrangler tail` | `trial_claim result=resumed` (BUKAN `granted`) | |
| KV | **Tetap satu** catatan `trial:`; `appUserId` di dalamnya kini ID baru; `endsAt` tidak berubah | |

**Lulus** hanya bila hasilnya `resumed`. Bila hasilnya `granted` dan KV memiliki dua catatan `trial:`, `ANDROID_ID` berubah:
HENTIKAN (lihat bagian 0).

### A5. Pasang ulang + pulihkan backup berkas
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Setelah A4, copot dan pasang ulang lagi | Onboarding | |
| Pengaturan > Data > **Pulihkan dari backup** (berkas dari 1.1) | Data kembali (termasuk buku kas tambahan dan Tabungan) | |
| Ringkasan | Kartu **"Lanjutkan uji coba"**, bukan trial baru | |
| Lanjutkan | Sisa hari lama; buku kas tambahan dan Tabungan terbuka | |

### A6. Setelah trial habis: tidak ada trial baru ⭐
Menunggu 30 hari tidak praktis; simulasikan di server.
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Cabut hibah: `--revoke-only` | `cabut ultimate/premium: HTTP 200` | |
| Ubah catatan KV agar `endsAt` ada di masa lalu (ms epoch), mis. 1 hari lalu: `npx wrangler kv key put "trial:<hash>" '{"grantedAt":"2026-10-14T00:00:00.000Z","endsAt":<ms lalu>,"appUserId":"<ID>"}' --binding RATE_LIMIT --remote` | | |
| Tunggu ±70 dtk, matikan paksa app, buka | Tidak ada hitung mundur; **tidak ada dialog akhir** (hibah dicabut paksa, bukan berakhir pada tanggalnya; dialog akhir diuji di C6) | |
| Lainnya > Tabungan | Tabungan hanya-tarik (saldo masih terlihat dan bisa ditarik); Buku Kas tambahan terkunci | |
| Dashboard, Pengaturan, fitur terkunci | **Tidak ada** tawaran trial (status `used`) | |
| **Copot, pasang ulang, pulihkan backup** | Tetap **tidak ada** tawaran trial; fitur terkunci langsung ke halaman paket | |
| `wrangler tail` (bila klaim dicoba lewat apa pun) | `already_used` | |

### A7. Pagar global (opsional, butuh akses admin)
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Set `TRIAL_DAILY_CLAIM_CAP = "0"`, deploy, uji dari perangkat/ID baru yang belum klaim | Tidak ada tawaran (status `paused`); bila ditekan: pesan "dijeda" | |
| Kembalikan nilai | Tawaran muncul lagi | |
| Anggaran: set `PROMO_AI_MONTHLY_BUDGET_RP = "1"` lalu pakai satu scan AI saat trial | Scan berikutnya menjawab anggaran penuh; **pelanggan berbayar tidak terdampak** | |

## 3. Seri B: pembelian dan trial (langkah 3)
Gunakan paket **bulanan** (hindari trial Play 15 hari agar yang diuji hanya interaksi dengan hibah).
Kartu pembayaran: "Kartu uji, selalu disetujui". RevenueCat: *Sandbox data* menyala. Setelah tiap skenario, **cabut hibah**
dan batalkan langganan uji agar skenario berikutnya bersih; gunakan akun/produk yang masih bersih bila perlu.

### B1. Gratis + trial aktif, lalu membeli Premium
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Mulai trial (A3). Buka Pengaturan > Langganan | Tile masih menawarkan **Upgrade ke Premium** (tier berbayar = Gratis); baris sisa hari trial ada | |
| Beli **Premium bulanan** | Pembelian **biasa**, tanpa teks penggantian; sukses | |
| Aplikasi | Tile: **Premium aktif**; trial tetap berjalan (fitur Ultimate masih terbuka) | |
| `--show` | Sumber: **berbayar**; langganan berbayar aktif: 1 | |
| Scan AI lebih dari 60 kali (atau perhatikan kuota di respons) | Kuota **penuh pelanggan berbayar** (bukan batas 60 trial) | |

### B2. Premium berbayar + trial, lalu membeli Ultimate ⭐
Inti langkah 3 dan risiko penagihan ganda.
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Kondisi awal: Premium berbayar (B1) dan trial Ultimate aktif | Tile "Premium aktif"; ada tawaran upgrade | |
| Buka Upgrade ke Ultimate; halaman hanya menawarkan Ultimate | Tidak ada kartu Premium | |
| Beli **Ultimate bulanan** | Lembar Play menyatakan **penggantian** (prorata/ganti langganan), bukan langganan tambahan | |
| Selesai | Tile: **Ultimate aktif** | |
| **Play Store > Pembayaran & langganan > Langganan** | **Hanya SATU** langganan LaciQ aktif (Ultimate); Premium tidak ada lagi | |
| RevenueCat > Customers | Satu produk berbayar aktif (Ultimate); `premium` dan `ultimate` aktif | |
| `--show` | Sumber: berbayar; langganan berbayar aktif: **1** | |

**Gagal** bila Play menunjukkan dua langganan: HENTIKAN (lihat bagian 0).

### B3. Trial berakhir saat masih Premium berbayar
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Kondisi: ID **bersih** (pasang ulang agar ID baru), beli **Premium bulanan**, lalu beri hibah singkat lewat skrip: `--minutes 3 --keep`. Buka app dalam 3 menit | Hitung mundur muncul; tile **Premium aktif** | |
| Tunggu 3 menit sampai hibah berakhir alami, bawa app ke depan | Dialog akhir muncul sekali; tile tetap **Premium aktif** | |
| Fitur | Premium (suara, Laporan, Excel, backup cloud) terbuka; Ultimate (buku kas tambahan, Tabungan baru, AI) terkunci; **tanpa iklan** | |

### B4. Ultimate berbayar: tidak ada trial
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Dengan Ultimate berbayar (hasil B2), buka Ringkasan dan Pengaturan | **Tidak ada** kartu ajakan, baris trial, maupun hitung mundur | |
| `wrangler tail` saat membuka app | `/trial/status` menjawab `ultimate` (tidak ada klaim) | |

### B5. Pulihkan pembelian saat hanya ada trial
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Kondisi: Gratis + trial aktif, tanpa langganan berbayar | | |
| Langganan > **Pulihkan pembelian** | Pesan "Tidak ada langganan aktif yang ditemukan untuk akun ini" (BUKAN "Pembelian dipulihkan") | |

### B6. Regresi: Premium ke Ultimate tanpa trial (U8 asli)
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Akun bersih (tanpa hibah), beli Premium bulanan lalu Ultimate bulanan | Penggantian; satu langganan; **Ultimate aktif** | |

### B7. Pembatalan dan masa tenggang (ringkas)
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Batalkan Premium berbayar saat trial berjalan | Fitur Ultimate tetap terbuka sampai trial habis; setelah itu Gratis | |

## 4. Seri C: tampilan hitung mundur di HP (opsional)
Menggeser kedaluwarsa lewat hibah server. Aturan RevenueCat: hibah baru yang berakhir dalam 2 jam dari hibah lama dianggap duplikat.
Karena itu **cabut dulu**, lalu hibah dengan batas lebih dari 2 jam dari saat ini. Setelah tiap perubahan: matikan paksa app, buka. Dialog tonggak hanya tampil sekali per tonggak; untuk mengulang dari awal, hapus data aplikasi (atau pasang ulang dan pulihkan backup).

> **Catatan:** mencabut hibah (`--revoke-only`) memajukan kedaluwarsa ke saat itu, sedangkan aplikasi menunggu *tanggal kedaluwarsa yang tercatat* untuk menyatakan trial "berakhir". Karena itu pencabutan paksa **tidak** memicu dialog akhir. Dialog akhir hanya teruji lewat hibah singkat yang berakhir alami (C6).

| Skenario | Perintah | Yang harus terlihat | Hasil |
|---|---|---|---|
| C1 normal | `--revoke-only` lalu `--minutes 28800 --keep` (20 hari) | Kartu "Uji coba Ultimate: 20 hari lagi"; tanpa dialog/banner | |
| C2 mendekati | `--revoke-only` lalu `--minutes 7200 --keep` (5 hari) | **Dialog "berakhir 5 hari lagi"** berisi buku kas/tabungan/transaksi berulang nyata; "Ingatkan nanti" menutup | |
| C3 tidak muncul lagi | Matikan paksa, buka | Dialog **tidak** muncul lagi | |
| C4 mendesak | `--revoke-only` lalu `--minutes 2880 --keep` (2 hari) | Banner di atas, dialog "Tinggal 2 hari lagi"; banner bisa ditutup (X) dan muncul lagi besok | |
| C5 hari terakhir | `--revoke-only` lalu `--minutes 600 --keep` (10 jam) | Banner merah "berakhir hari ini pukul …" **tanpa tombol tutup**; dialog hari terakhir | |
| C6 berakhir alami | Pada ID **bersih** (pasang ulang): `--minutes 3 --keep`; buka app dalam 3 menit lalu tunggu 3 menit dan bawa app ke depan | Dialog "Uji coba Ultimate berakhir" sekali; kartu "Data Anda aman" 7 hari; fitur Ultimate terkunci | |
| C7 notifikasi | Saat C1: pastikan izin notifikasi aktif; periksa jadwal | Notifikasi hari ke-23 dan ke-28 pukul 10.00 terjadwal (tidak diminta izin baru) | |
| C8 terkunci PIN | Aktifkan PIN, ulangi C2 dari awal app | Dialog **tidak** tampil di atas layar kunci; tampil setelah dibuka | |
| C9 formulir terbuka | Buka form Catat, kirim aplikasi ke latar belakang lalu kembali (formulir tetap terbuka) | Dialog **tidak** menimpa formulir | |

## 5. Pembersihan setelah uji
- [ ] Cabut semua hibah uji (`--revoke-only`) untuk ID perangkat uji.
- [ ] Hapus catatan KV uji: `npx wrangler kv key delete "trial:<hash>" --binding RATE_LIMIT --remote` (agar perangkat bisa diuji lagi).
- [ ] Batalkan langganan uji di Play (pembelian uji kedaluwarsa sendiri).
- [ ] Kembalikan `TRIAL_DAILY_CLAIM_CAP`/`PROMO_AI_MONTHLY_BUDGET_RP` bila diubah di A7.
- [ ] Keputusan menyalakan: biarkan `TRIAL_ENABLED = "1"` hanya bila seluruh seri A dan B lulus; selain itu kembalikan ke `"0"`.

## 6. Hasil akhir
- [ ] A1-A6 lulus (A4 dan A6 wajib)
- [ ] B1-B4 lulus (B2 wajib); B5-B7 lulus atau dicatat
- [ ] Seri C dijalankan atau dicatat dilewati
- [ ] Biaya AI nyata per trial dicatat (scan: __, ringkasan: __, `promo-cost` bulan ini: Rp __)
- [ ] Catatan masalah dimasukkan ke [RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md](RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md)
- [ ] Tanggal uji: ________  Perangkat: ________  Akun tester: ________  Versi/kode build: ________
