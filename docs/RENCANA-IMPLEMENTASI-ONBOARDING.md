# Rencana build 1.2.0+20: bantu pengguna baru mulai memakai LaciQ

Disusun 2026-10-29. Status: **rencana, belum dikerjakan**. Build +19 (sapaan "kamu", persetujuan iklan UMP) sudah di jalur internal dan tidak diubah.

## 1. Masalah

Keluhan pengguna: butuh waktu untuk memahami seluruh fitur dan cara memakainya. Setelah ditanyakan, inti keluhannya adalah **bingung untuk memulai**, bukan bingung memakai fitur tertentu.

Kondisi sekarang (dibaca dari kode):

- **Onboarding** ([onboarding_page.dart](../lib/features/onboarding/onboarding_page.dart)) = 6 slide daftar fitur dan paket, sekali di instalasi baru (kunci `onboarding_seen`), bisa dibuka lagi dari Pengaturan > "Lihat panduan lagi". Isinya menjelaskan *apa saja fiturnya*, tidak mengarahkan *apa yang dilakukan pertama*.
- **Instalasi baru** sudah punya Buku Utama dengan kategori pribadi dan dompet "Tunai" (`LedgerTemplate.personal`). Jadi pengguna *bisa* langsung mencatat; yang kurang adalah dorongan dan arahan.
- **Keadaan kosong** (`EmptyState` di [widgets.dart](../lib/core/widgets.dart)) sudah punya kalimat penjelasan di banyak halaman (Target, Utang/Piutang, Berulang, Agenda, Tabungan, Transaksi), tetapi **hanya ikon + teks, tanpa tombol aksi**. Pengguna harus mencari sendiri tombol "Baru" atau "Catat".
- **Mode usaha** hanya ada sebagai saklar di Lainnya; pengguna usaha kecil tidak tahu ia ada, apalagi Laba Rugi.
- Beranda tidak punya petunjuk "langkah berikutnya".

## 2. Sasaran

Pengguna baru mencatat **transaksi pertamanya dalam satu sesi pertama**, dan tahu ke mana harus pergi untuk hal berikutnya (anggaran, target, cadangan, Laba Rugi). Tanpa mengubah skema, format backup, atau aturan paket.

Ukuran keberhasilan (dibaca dari data yang sudah ada, tanpa menambah pelacakan baru): rasio pemasangan baru yang punya minimal 1 transaksi di hari ke-1 (Play Console tidak menyediakan ini; cukup diamati dari ulasan dan keluhan, lihat §8).

## 3. Cakupan +20

| # | Butir | Ukuran | Risiko |
|---|---|---|---|
| A | Onboarding ringkas yang mengarah ke aksi | sedang | rendah |
| B | Kartu "Mulai cepat" di Beranda | sedang | rendah |
| C | Tombol aksi di keadaan kosong | kecil | sangat rendah |

**Di luar cakupan** (sengaja ditunda; menjawab "bingung memakai", bukan "bingung mulai"): ikon "?" per halaman, halaman Panduan & Tanya Jawab, video. Dikerjakan hanya bila keluhan berikutnya bergeser ke sana.

## 4. Butir A: onboarding yang mengarah ke aksi

Ganti 6 slide fitur dengan alur pendek:

1. **Sapaan** (1 layar): satu kalimat nilai jual, tombol "Mulai".
2. **"Untuk apa kamu memakai LaciQ?"** dua pilihan besar: *Keuangan pribadi* atau *Usaha kecil*. Memilih *Usaha kecil* memanggil `setLedgerKind(kMainLedgerId, LedgerKind.business)` (Mode usaha menyala; hanya mengubah istilah dan laporan, tanpa menyentuh data). Pilihan bisa diubah kapan saja di Lainnya, dan kalimat itu disebutkan di layar.
3. **"Catat transaksi pertamamu"**: tombol membuka formulir Catat yang sama dengan sekarang; bisa dilewati. Setelah menyimpan, kembali ke Beranda.

Detail penting:

- Daftar fitur dan paket yang sekarang **tidak dibuang**: dipindah ke "Lihat panduan lagi" (tetap `OnboardingPage(standalone: true)` dengan slide lama) supaya `docs/MATRIKS-FITUR-PAKET.md` tetap punya satu rujukan di aplikasi. Alur baru dipakai hanya untuk instalasi baru.
- Kunci penyimpanan: pakai `onboarding_seen` yang ada. Pengguna lama sudah bernilai `1`, jadi **tidak melihat alur baru** (benar: mereka bukan pengguna baru).
- Pilihan tujuan disimpan sebagai efek `setLedgerKind`, bukan kunci baru. Tidak ada skema atau backup yang berubah.
- Tombol "Lewati" tetap ada di setiap layar. Gagal membaca penyimpanan tetap dianggap "sudah dilihat" (aturan yang sudah ada di `OnboardingController`).
- Sapaan "kamu", nada santai, tanpa istilah akuntansi.

## 5. Butir B: kartu "Mulai cepat" di Beranda

Kartu di atas `TrialStatusCard` di [dashboard_page.dart](../lib/features/dashboard/dashboard_page.dart), berisi daftar langkah yang dicentang otomatis dari data:

| Langkah | Tercentang bila | Ketuk membuka |
|---|---|---|
| Catat transaksi pertama | ada ≥ 1 transaksi di buku mana pun | formulir Catat |
| Atur anggaran | ada ≥ 1 anggaran | Anggaran |
| Buat target tabungan | ada ≥ 1 target | Target |
| Aktifkan pengingat | ada ≥ 1 transaksi berulang atau agenda | Berulang/Agenda |
| Cadangkan datamu | pernah backup (cek penanda yang sudah ada di layanan backup; bila tidak ada, tambah satu kunci non-sensitif) | Backup |
| *(hanya Mode usaha)* Lihat Laba Rugi | selalu tampil sebagai tautan, tidak dicentang | Laba Rugi |

Aturan:

- **Tercentang dihitung dari data, bukan dari "pernah diketuk"**, sehingga pengguna lama otomatis melihat langkah yang sudah mereka lakukan sebagai selesai.
- Pengguna lama dengan banyak langkah selesai: kartu hanya menampilkan sisa langkah. Bila **semua selesai**, kartu hilang selamanya (kunci `quickstart_done`).
- Ada tombol "Sembunyikan" (kunci `quickstart_hidden`); pengaturan bisa memunculkannya lagi lewat "Lihat panduan lagi".
- Maksimal 5 baris. Tidak menambah jalur navigasi baru: semua tujuan sudah ada.
- Provider baru `quickStartProvider` (turunan dari provider yang sudah ada: transaksi, anggaran, target, berulang, agenda). Tidak ada tabel baru.
- Perhatian Riverpod 3: provider yang tidak didengar bisa `AsyncLoading`; kartu harus menangani loading tanpa berkedip (tampil kosong sampai semua data siap).

## 6. Butir C: tombol aksi di keadaan kosong

Tambah parameter opsional `action` (label + `onPressed`) ke `EmptyState`. Parameter bersifat tambahan, sehingga pemakai yang ada tidak berubah. Tambahkan tombol di:

| Halaman | Teks tombol |
|---|---|
| Transaksi | Catat transaksi |
| Target ([goals_page.dart](../lib/features/goals/goals_page.dart)) | Target baru |
| Utang/Piutang | Catat utang atau piutang |
| Berulang | Tambah transaksi berulang |
| Agenda | Tambah agenda |
| Tabungan | Buat tabungan |
| Laba Rugi / Laporan bulanan (kosong) | Catat transaksi |

Anggaran tidak memakai `EmptyState` (daftar kategori dengan baris ringkas), jadi tidak berubah.

## 7. Pengujian

Otomatis (tambah ke suite; sekarang 886 tes):

- Alur onboarding: memilih Usaha menyalakan Mode usaha; memilih Pribadi tidak; "Lewati" tetap menandai selesai; pengguna dengan `onboarding_seen = 1` tidak melihat alur baru.
- `quickStartProvider`: tiap langkah tercentang dari data yang sesuai; semua selesai ⇒ kartu hilang; sembunyikan ⇒ kartu hilang; langkah usaha hanya di Mode usaha.
- Widget Beranda: kartu muncul di instalasi baru, tidak muncul bila disembunyikan.
- `EmptyState` dengan dan tanpa `action`; tombol di tiap halaman memanggil tujuan yang benar.
- Tes migrasi tetap hijau (skema tidak berubah, `latest = 12`).

Di HP:

- **Emulator**: instalasi baru (bersih) menjalani alur dari awal sampai transaksi pertama; Mode usaha menyala bila memilih usaha.
- **Redmi**: pembaruan dari +19 ke +20 dengan data dummy yang ada; pastikan alur onboarding **tidak** muncul lagi dan "Mulai cepat" menampilkan langkah yang sudah selesai sebagai tercentang.
- Mode gelap dan teks besar (ukuran font sistem 1,3×) untuk kartu dan tombol baru.

## 8. Rilis

1. Versi `1.2.0+20`, bangun AAB seperti +19 (`flutter build appbundle --release`, tanpa `--dart-define` tambahan).
2. Jalur internal → uji Redmi → Produksi bertahap 50% (urutan sama seperti +18/+19).
3. Catatan rilis: satu kalimat ("Panduan mulai yang lebih mudah dan tombol langsung di halaman yang masih kosong").
4. Dokumentasi: perbarui `docs/RILIS-1.2.0+16.md` atau buat `RILIS-1.2.0+20.md`, `docs/MATRIKS-FITUR-PAKET.md` hanya bila ada perubahan paket (tidak ada).
5. **Data Safety Play**: tidak berubah (tidak ada pengumpulan data baru).
6. Pantau: ulasan Play dan pesan pengguna selama 1–2 minggu. Tanyakan langsung ke pengguna yang mengeluh apakah arahan baru membantu.

## 9. Keputusan yang masih terbuka

| # | Pertanyaan | Saran |
|---|---|---|
| O1 | Apakah pengguna lama (±46 perangkat aktif) ikut melihat "Mulai cepat"? | Ya, dengan langkah selesai otomatis tercentang; bisa disembunyikan. |
| O2 | Slide fitur/paket lama: dibuang atau dipindah ke "Lihat panduan lagi"? | Dipindah (§4), agar rujukan paket tetap ada. |
| O3 | Pilihan "Usaha kecil" di onboarding: tampilkan penjelasan Laba Rugi (Premium)? | Sebut singkat bahwa Laba Rugi ada, tanpa menjual paket di layar awal. |
| O4 | Perlu tombol "Lewati semua" di kartu Mulai cepat? | Cukup "Sembunyikan". |

## 10. Urutan kerja

1. Butir C (`EmptyState.action` + 7 halaman + tes), paling kecil dan berdiri sendiri.
2. Butir B (provider + kartu + tes).
3. Butir A (alur onboarding + tes).
4. `flutter analyze`, seluruh tes, uji emulator dan Redmi.
5. Naikkan versi, AAB, rilis internal.

Perkiraan: satu hari kerja, termasuk uji di HP.
