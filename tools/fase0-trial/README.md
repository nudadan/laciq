# Fase 0: uji asumsi trial Ultimate

Menutup butir ⚠️ di [`docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md`](../../docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md) (bagian 9)
**sebelum** ada kode produksi. Tidak mengubah aplikasi LaciQ, Worker, maupun dasbor RevenueCat selain hibah uji pada ID uji yang
dicabut di akhir.

| Butir | Pertanyaan | Alat |
|---|---|---|
| 1 | API menerima hibah promosional per entitlement dengan `end_time_ms` | `rc_promo_check.mjs` |
| 2 | Hibah terlihat di `CustomerInfo` aplikasi dengan `store = promotional` | probe + `rc_promo_check.mjs --hold` |
| 3 | `product_identifier` promosional berawalan `rc_promo_` | `rc_promo_check.mjs` |
| 4 | `ANDROID_ID` sama setelah copot dan pasang ulang | `run-probe.sh reinstall` |
| 5 | Kunci secret punya izin menulis (hibah) | `rc_promo_check.mjs` |
| W | Keputusan Worker (`hasUltimate`) benar untuk hibah aktif, kedaluwarsa, dan dicabut | `rc_promo_check.mjs --wait-expiry` |

Butir 6 (Play Integrity) dan 7 (perilaku buku terkunci di UI) bukan bagian skrip ini.

## Keamanan (baca dulu)

- **Kunci secret RevenueCat hanya lewat variabel lingkungan** di sesi shell Anda. Jangan menempelkannya di chat, berkas, atau commit.
  Cara aman memasukkannya: `read -rs REVENUECAT_SECRET_KEY; export REVENUECAT_SECRET_KEY` (ketik lalu Enter; tidak terlihat).
- Skrip hanya menyentuh **satu ID uji** (milik probe). Jangan memakai ID pengguna sungguhan.
- Hibah uji dicabut otomatis di akhir (kecuali `--keep`). Bila skrip terhenti di tengah jalan, cabut dengan
  `node rc_promo_check.mjs '<id>' --revoke-only`.
- Probe memakai paket dan kunci tanda tangan sendiri; **data LaciQ di perangkat tidak tersentuh**, termasuk saat `reinstall`.
- Probe memakai kunci SDK **publik** yang sudah ada di repo (`revenuecat_config.dart`).

## Prasyarat

```bash
source /e/Developments/tools/dev-env.sh        # Flutter 3.47.5, Node, JDK 17, truststore Avast
export ADB_SERIAL=192.168.1.104:PORT           # port adb nirkabel TERBARU (berubah tiap sesi)
adb connect "$ADB_SERIAL"
```

Kunci secret RevenueCat: dasbor RevenueCat → Project settings → API keys → **Secret API keys** (V1, awalan `sk_`). Idealnya kunci
**yang sama** dengan `REVENUECAT_SECRET_KEY` Worker, agar butir 5 membuktikan izin yang sesungguhnya dipakai Worker. Bila kunci
itu tidak lagi Anda pegang, buat kunci V1 baru dengan izin tulis lalu ganti rahasia Worker memakai kunci tersebut.

## Langkah

### A. Siapkan probe (sekali, ±2 menit)
```bash
bash tools/fase0-trial/run-probe.sh setup
bash tools/fase0-trial/run-probe.sh build
bash tools/fase0-trial/run-probe.sh install
```

### B. Butir 4: ANDROID_ID setelah pasang ulang
```bash
bash tools/fase0-trial/run-probe.sh show        # catat ANDROID_ID dan ID RevenueCat
bash tools/fase0-trial/run-probe.sh reinstall   # copot + pasang + bandingkan otomatis
```
Harapan: **LULUS, ANDROID_ID sama**, dan ID RevenueCat **berubah** (itu bukti ID RevenueCat tidak boleh jadi kunci).
Ulangi `reinstall` sekali lagi untuk memastikan konsisten.

> Mengapa kunci tanda tangan khusus? `ANDROID_ID` dibatasi per kunci tanda tangan. Bila probe memakai kunci debug bersama,
> LaciQ debug yang masih terpasang bisa membuat nilainya tampak "bertahan" padahal untuk pengguna sungguhan (satu-satunya aplikasi
> dengan kunci Play) mungkin tidak. Kunci khusus meniru kondisi itu.
> Batas uji: yang terbukti adalah mekanisme pasang-ulang pada perangkat ini dengan kunci uji. Nilai pada build Play (kunci
> Play) sebaiknya dikonfirmasi sekali lagi lewat jalur pengujian internal sebelum rilis (Fase 2).

### C. Butir 1, 2, 3, 5, W: hibah promosional
Ambil ID RevenueCat probe dari `show` (baris `ID RevenueCat`), lalu:

```bash
export REVENUECAT_SECRET_KEY=...   # lihat catatan keamanan; jangan tempel ke chat
node tools/fase0-trial/rc_promo_check.mjs '<ID RevenueCat probe>' --minutes 10 --hold
```

Saat skrip berhenti di "JEDA":
1. Di probe/HP tekan **Muat ulang** (atau jalankan `bash tools/fase0-trial/run-probe.sh show`).
2. Harapan butir 2: `ultimate` dan `premium` **aktif=true**, **store=PROMOTIONAL**, `berakhir` sesuai batas yang dicetak skrip.
3. Catat nilai `produk=` (untuk butir 3) lalu tekan Enter di terminal; skrip mencabut hibah.

Uji kedaluwarsa (sekitar 3 menit) untuk memastikan keputusan Worker kembali **false** tanpa dicabut:
```bash
node tools/fase0-trial/rc_promo_check.mjs '<ID RevenueCat probe>' --minutes 3 --wait-expiry
```

## Cara membaca hasil

| Hasil skrip / probe | Artinya | Tindakan |
|---|---|---|
| `[5] LULUS` | Kunci boleh menulis | Lanjut |
| `[5] GAGAL … HTTP 401/403` | Kunci tidak berizin | Buat kunci V1 dengan izin tulis, ganti rahasia Worker |
| `[1] GAGAL` pada end_time_ms (HTTP 400) | Parameter ditolak | Rancangan memakai `duration: "monthly"` sebagai cadangan; kabari saya |
| `[3] GAGAL` (`product_identifier` bukan `rc_promo_`) | Awalan lain | Sesuaikan penentu "sumber promosional" di Worker (cukup ubah satu konstanta) |
| `[W]`/`[E]`/`[C]` GAGAL | Keputusan Worker salah untuk kasus itu | Berhenti dan kabari saya; rancangan kuota trial bergantung padanya |
| Butir 2 `store` bukan PROMOTIONAL / entitlement tidak muncul | Aplikasi tidak melihat hibah | Periksa apakah probe diterima SDK (lihat di bawah) |
| Butir 4 GAGAL | `ANDROID_ID` berubah saat pasang ulang | Kunci perangkat utama tidak berlaku; pakai alternatif L7 |

## Catatan dan batas

- **Probe memakai paket berbeda dari LaciQ** (`com.hardanti.fase0.fase0_probe`) tetapi kunci SDK yang sama. Bila RevenueCat
  menolak konfigurasi dari paket lain (probe menampilkan galat "RevenueCat: …"), butir 2 tidak bisa dibuktikan lewat probe. Risikonya
  rendah karena ini mekanisme standar RevenueCat; buktikan di build LaciQ pada Fase 2.
- **Hibah ulang dalam 2 jam**: dokumentasi RevenueCat menyatakan `end_time_ms` dalam 2 jam dari hibah aktif dianggap duplikat dan
  tidak memperpanjang. Skrip mencetak perilakunya sebagai informasi. Untuk rancangan trial ini tidak masalah (hibah ke ID baru),
  tetapi jangan berharap bisa "memperpanjang" hibah yang sama dalam waktu dekat.
- Parameter `duration` pada API v1 ditandai **deprecated**; rancangan memakai `end_time_ms`.
- Memanggil `GET /subscribers/{id}` membuat catatan pelanggan kosong untuk ID yang belum dikenal (catatan di `revenuecat.ts`).
  Tidak berbahaya untuk ID uji.
- Folder `probe/android`, `probe/work` (APK, keystore uji, nilai terakhir) dan `build` diabaikan git.
