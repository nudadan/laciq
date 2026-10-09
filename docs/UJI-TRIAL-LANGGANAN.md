# Daftar uji: uji coba gratis 15 hari dan perilaku langganan

> Dibuat 2026-10-09. Menutup sisa Fase 0 di `docs/rencana_implementasi_laciq.md`: membuktikan bahwa penawaran `trial-15d-tahunan`
> (Premium dan Ultimate tahunan), RevenueCat, RTDN, dan aplikasi build 14 bekerja bersama. Semua uji memakai **akun license tester**,
> jadi tidak ada uang sungguhan yang ditagih.

## 0. Cara kerja pembelian uji (penting dibaca dulu)
Untuk akun license tester, Google mempercepat waktu langganan:

| Hal asli | Waktu saat uji |
|---|---|
| Uji coba gratis 15 hari | **3 menit** |
| Langganan bulanan | 5 menit per periode |
| Langganan tahunan | 30 menit per periode |
| Masa tenggang pembayaran | 5 menit |
| Penangguhan akun | 10 menit |
| Pembaruan otomatis | Maksimal 6 kali, lalu berhenti sendiri |

Pembelian uji ditandai "pembelian uji" di lembar pembayaran dan di RevenueCat tampil sebagai data **sandbox** (nyalakan sakelar
*Sandbox data* di RevenueCat untuk melihatnya).

**Kelayakan trial.** Penawaran hanya muncul bila akun *belum pernah berlangganan produk itu* (`dompetku_premium` atau
`dompetku_ultimate`). Bila lembar pembayaran **tidak** menampilkan "Uji coba gratis 15 hari", akun itu tidak layak. Gunakan akun
Google lain yang baru didaftarkan sebagai tester, atau produk yang berbeda. Itu perilaku benar, bukan bug.

**Aplikasi build 14 belum menampilkan teks trial di paywall.** Tombol hanya menampilkan harga biasa. Syarat trial tampil di
**lembar pembayaran Google Play** setelah tombol ditekan. Itu sesuai harapan sampai rilis v1.1.

## 1. Persiapan (sekali)
- [ ] Play Console > Setelan (Pengaturan) > **Pengujian lisensi**: akun Google yang dipakai di HP sudah terdaftar. Respons lisensi: normal.
- [ ] Di HP, akun Google yang aktif di Play Store adalah akun tester itu. Pada Xiaomi/Redmi, pakai profil utama (pengguna 0), bukan XSpace.
- [ ] LaciQ terpasang dari Google Play (build 14 produksi), bukan build debug.
- [ ] Metode pembayaran uji tersedia di Play Store: **"Kartu uji, selalu disetujui"**.
- [ ] RevenueCat: sakelar *Sandbox data* menyala. RTDN berstatus *Connected to Google* (sudah, 2026-10-09).
- [ ] Catat **ID pengguna anonim RevenueCat** dari halaman Langganan di aplikasi (6 digit awal) untuk mencarinya di dasbor.
- [ ] Kondisi awal: aplikasi menunjukkan paket **Gratis**.

## 2. Skenario uji
Isi kolom *Hasil* dengan Lulus/Gagal dan catatan.

### U1. Mulai trial Premium tahunan
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Buka Lainnya > Langganan, pilih **Premium tahunan**, tekan tombol beli | Lembar Play menampilkan **uji coba gratis 15 hari**, lalu harga tahunan Rp75.000, dan label pembelian uji | |
| Pilih kartu uji "selalu disetujui", konfirmasi | Pembelian sukses tanpa tagihan | |
| Kembali ke aplikasi | Status menunjukkan **Premium aktif**; iklan banner hilang; fitur Premium terbuka (suara, Laporan Bulanan, Excel, utang piutang) | |
| RevenueCat > Customers (cari ID) | Entitlement `premium` aktif, periode **trial**; kartu *Active Trials* di Overview bertambah | |
| Play Console > Pesanan (Order management) | Muncul pesanan uji `dompetku_premium` | |
| RevenueCat > Apps > DompetKu (Play Store) | *Last received* diperbarui (notifikasi RTDN masuk **tanpa** membuka aplikasi) | |

### U2. Trial berakhir, menjadi berbayar
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Tunggu ±3 menit setelah U1 (jangan batalkan) | Play menagih pembelian uji pertama | |
| Buka aplikasi atau tarik penyegaran status | Tetap **Premium aktif** tanpa jeda | |
| RevenueCat | Event konversi/pembaruan; periode berikutnya aktif; berlaku ±30 menit | |

### U3. Batalkan saat trial
Ulangi U1 dengan akun/produk yang masih layak trial, lalu:
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Play Store > Pembayaran & langganan > Langganan > LaciQ > **Batalkan** | Play menyatakan akses sampai akhir periode trial | |
| Aplikasi, sebelum trial berakhir | **Masih Premium** | |
| RevenueCat | Status "akan dibatalkan"; event pembatalan tiba dalam hitungan menit (bukti RTDN) | |
| Setelah trial berakhir (±3 menit) | Aplikasi kembali ke **Gratis**; iklan muncul lagi (mengingat masa tenggang iklan 30 hari bisa menunda iklan, lihat catatan 4) | |

### U4. Trial Ultimate dan fitur AI
Dengan akun yang layak trial Ultimate:
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Beli **Ultimate tahunan** (trial 15 hari) | Lembar Play menampilkan trial; aplikasi menunjukkan **Ultimate aktif** | |
| Scan struk dengan AI | Berhasil, nama toko/kategori/total/tanggal terisi | |
| Buat **Ringkasan AI** di Laporan Bulanan (setelah persetujuan) | Ringkasan muncul; tombol Laporkan ada | |
| Multi buku kas | Bisa menambah buku kas (sampai 5) | |
| Catat **jumlah scan dan ringkasan** yang dipakai | Untuk menghitung biaya per trial (bahan keputusan di rencana) | |

### U5. Tidak layak trial lagi
Setelah U1 selesai atau dibatalkan, langganan ulang produk yang sama:
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Beli lagi **Premium tahunan** dengan akun yang sama | Lembar Play **tidak** menampilkan trial (langsung harga Rp75.000) | |

### U6. Pulihkan pembelian
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Hapus data aplikasi atau pasang ulang, buka Langganan, tekan **Pulihkan pembelian** | Status kembali ke paket yang masih aktif | |
| Pada HP kedua dengan akun Google sama | Status paket muncul setelah pemulihan | |

### U7. Masa tenggang pembayaran (opsional, lanjutan)
Menguji bahwa pembayaran gagal tidak langsung memutus akses.
| Langkah | Yang harus terlihat | Hasil |
|---|---|---|
| Beli Premium bulanan dengan kartu uji "selalu disetujui" | Premium aktif | |
| Sebelum perpanjangan (5 menit), ubah metode bayar di Play ke **"Kartu uji, selalu ditolak"** | | |
| Saat perpanjangan gagal | Play masuk **masa tenggang** (5 menit uji). **Aplikasi tetap Premium** | |
| Setelah masa tenggang habis | Penangguhan akun (10 menit uji): **akses hilang** | |
| Ubah kartu ke "selalu disetujui" | Langganan pulih, Premium kembali | |

## 3. Titik periksa di tiap tempat
| Tempat | Yang dicek |
|---|---|
| Lembar bayar Google Play | Teks uji coba, harga setelah trial, label pembelian uji |
| Aplikasi (Langganan) | Paket aktif, ID RevenueCat, tombol Pulihkan |
| RevenueCat > Customers | Entitlement, periode trial, kedaluwarsa, riwayat event |
| RevenueCat > Overview | *Active Trials*, *Active Subscriptions* (dengan sandbox menyala) |
| RevenueCat > Apps > DompetKu (Play Store) | *Last received* (RTDN) |
| Play Console > Pesanan | Pesanan uji dan status |
| Worker (AI) | Panggilan scan/ringkasan diterima (Ultimate), ditolak `403 not_ultimate` untuk non-Ultimate |

## 4. Catatan dan hal yang bukan bug
1. Pembelian uji kedaluwarsa jauh lebih cepat dari 15 hari (lihat tabel). Jangan menafsirkan sebagai kesalahan.
2. Paywall belum menyebut "uji coba 15 hari" (baru di v1.1). Lembar Play sudah memuat syaratnya.
3. Trial hanya untuk pelanggan baru per produk. Premium dan Ultimate adalah dua produk, jadi satu akun bisa memperoleh dua trial.
4. Pengguna baru mendapat **masa tenggang iklan 30 hari** sejak pemakaian pertama, jadi iklan tidak langsung muncul meski paket Gratis.
   Untuk menguji iklan, pakai instalasi lama atau perpendek masa tenggang di build debug.
5. Bila pembelian ditolak "item tidak ditemukan": produk belum aktif di Play atau akun bukan tester atau aplikasi bukan dari Play.
6. Bila RevenueCat tidak menampilkan pelanggan: ID salah, sandbox mati, atau aplikasi belum membuka halaman Langganan sehingga
   belum menyinkronkan.

## 5. Hasil akhir
- [ ] U1 sampai U6 lulus (U7 opsional)
- [ ] Biaya AI per trial Ultimate dicatat (scan: __, ringkasan: __, perkiraan Rp __)
- [ ] Catatan masalah dimasukkan ke `docs/rencana_implementasi_laciq.md` (Bagian 5 dan 7)
- [ ] Tanggal uji: ________  Perangkat: ________  Akun tester: ________
