# Ganti nama aplikasi: DompetKu -> LaciQ

> Keputusan 2026-10-03. Alasan: sedikitnya 4 aplikasi di Play Store berjudul persis "DompetKu" dengan unduhan besar,
> sehingga aplikasi ini tenggelam di pencarian merek dan sulit dilindungi. Judul resmi baru di Play:
> **"LaciQ: Catatan Keuangan"** (dibaca "laci kyu"). Pengerjaan ada di cabang `rename-laciq`.

## Hasil pemeriksaan nama (oleh pemilik, 2026-10-03)
| Pemeriksaan | Hasil |
|---|---|
| Play Store, nama persis "LaciQ" | Kosong |
| Google, kata kunci "laciq" | Tidak ada layanan sejenis |
| laciq.id | Tersedia, tetapi pemilik memilih domain lain |
| **laciq.solusimandiri.id** | **Domain terpilih (2026-10-03): subdomain milik sendiri; DNS sedang propagasi, akan dipindah ke Cloudflare** |
| laciq.com | Diparkir untuk dijual (Afternic), tidak aktif; jangan dihubungi |
| PDKI (merek terdaftar) | **BELUM diperiksa: situs PDKI sedang mati. WAJIB dicek (kelas 9, 36, 42; kata "LaciQ" dan "Laci") sebelum nama dipasang di Play.** |

## Sudah dikerjakan di cabang `rename-laciq`
- [x] Aplikasi: `android:label`, judul MaterialApp, layar kunci, Pengaturan, halaman langganan, pesan backup, subjek dan nama
      berkas ekspor (`laciq-backup-...json`, `laciq-transaksi-...csv`), tombol "Beri nilai LaciQ". 538 tes lulus.
- [x] Situs `docs/situs-beranda/` (teks, canonical, OG, JSON-LD memakai `https://laciq.solusimandiri.id/`), dan `docs/kebijakan-privasi/`
      (menyebut nama lama).
- [x] Feature graphic baru: `store-assets/feature-graphic-laciq-1024x500.png`; `og.jpg` dibangun ulang darinya.

## SENGAJA tidak diubah (jangan diubah)
- ID paket `com.hardanti.lacipintar`, nama paket Dart `dompet_pintar`, nama database `dompet_pintar`.
- Penanda format backup `dompet_pintar_backup` (agar backup lama tetap bisa dipulihkan).
- ID kanal notifikasi, ID produk langganan (`dompetku_premium`, `dompetku_ultimate`), entitlement RevenueCat.
- Alamat Worker `dompetku-api.hardan-ti.com` (bisa ditambah alias `api-laciq.solusimandiri.id` nanti; ubah `ai_config.dart` hanya setelah alias hidup).

## Menunggu tindakan pemilik / keputusan
1. [ ] **Cek PDKI** saat situs pulih. Bila ada merek bentrok: berhenti, JANGAN pasang nama di Play.
2. [ ] Domain `laciq.solusimandiri.id`: tunggu propagasi, pindahkan ke Cloudflare, arahkan ke server nginx yang sama (`10.9.0.208`), lalu minta saya memasang vhost + sertifikat.
3. [ ] Ambil akun media sosial dengan nama yang sama.
4. [ ] Play Console (setelah PDKI bersih dan domain hidup):
   - Judul listing: **LaciQ: Catatan Keuangan** (maks. 30 karakter; tepat 23).
   - Deskripsi singkat dan lengkap: ganti "DompetKu" -> "LaciQ" (lihat `LISTING-PLAY-STORE.md`).
   - Feature graphic: unggah `feature-graphic-laciq-1024x500.png`.
   - URL kebijakan privasi: `https://laciq.solusimandiri.id/privacy` (pertahankan URL lama aktif sampai peninjauan selesai).
   - Detail kontak: situs web `https://laciq.solusimandiri.id`.
   - Catatan rilis build 10 menyebut perubahan nama.
5. [ ] Google Cloud > layar persetujuan OAuth: nama aplikasi -> LaciQ; beranda dan kebijakan privasi -> laciq.solusimandiri.id; domain
      terotorisasi tambah **`solusimandiri.id`** (domain induk, bukan subdomain). (Tanpa logo, scope non-sensitif: tidak memicu verifikasi; periksa lagi setelah diubah.)
6. [ ] RevenueCat: ganti nama project/app (opsional, hanya tampilan di dashboard); ID produk TIDAK diubah.
7. [ ] Ubah deskripsi Data Safety bila menyebut nama lama (`DATA-SAFETY-PLAY.md`).
8. [ ] Pasang ulang situs: `docs/situs-beranda/` -> `/var/www/<laciq.solusimandiri.id>/` dan tambah `server_name laciq.solusimandiri.id`; buat pengalihan 301 dari
      `dompetku.hardan-ti.com` bila domain lama tidak dipakai lagi.
9. [ ] Naikkan versi ke 1.0.0+10, bangun AAB, uji, lalu unggah (uji internal dulu).
10. [ ] Merek: setelah PDKI bersih, pertimbangkan mendaftarkan "LaciQ" (kelas 9 dan 42) ke DJKI.
