# Rencana Implementasi — Pencatatan Utang/Piutang

> Dibuat 2026-09-29. Fitur Fase 2 dari [RANCANGAN-AWAL.md](RANCANGAN-AWAL.md) ("target tabungan (goals) dan
> pelacakan utang/piutang" — goals sudah selesai lama, utang/piutang belum). Dipasarkan sebagai satu paket
> dengan fitur di [RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md](RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md), tapi
> **tidak berhubungan secara teknis** — skema, UI, dan alur kerja sepenuhnya independen, sengaja didokumentasikan
> terpisah supaya progres masing-masing gampang dilacak.

## 1. Ringkasan

Fitur premium baru: mencatat **utang** (uang yang pengguna pinjam dari orang lain, perlu dibayar) dan
**piutang** (uang yang dipinjamkan pengguna ke orang lain, perlu ditagih). Desainnya meniru pola yang sudah
terbukti di fitur Agenda (`lib/features/agenda/`) — estimasi awal yang bisa disesuaikan saat "dieksekusi",
transaksi nyata tercatat otomatis, bukan cuma catatan pengingat pasif.

**Premium penuh, tanpa versi gratis** — konsisten dengan pivot strategi yang sama seperti fitur OCR (paket
profesional terjangkau, bukan freemium bertingkat untuk fitur ini).

## 2. Desain skema (Drift)

Tabel baru `Debts` (nama tabel final ditentukan saat implementasi, cek tidak bentrok dengan penamaan yang
sudah ada):

```
Debts
  id                TextColumn (uuid)
  type              IntColumn (enum DebtType { debt, receivable }) — utang vs piutang
  counterpartyName  TextColumn — nama orang/pihak terkait
  amount            IntColumn (pokok, integer Rupiah, > 0)
  paidAmount        IntColumn (default 0) — total sudah dibayar/diterima berjalan
  note              TextColumn nullable
  dueDate           DateTimeColumn nullable — tanggal jatuh tempo opsional
  accountId         TextColumn nullable, references Accounts — dompet default saat pelunasan (opsional,
                    boleh dipilih ulang saat "Catat pembayaran" kalau kosong)
  createdAt         DateTimeColumn
  updatedAt         DateTimeColumn
```

Catatan desain:
- **Status lunas diturunkan dari data** (`paidAmount >= amount`), bukan kolom boolean terpisah — menghindari dua
  sumber kebenaran yang bisa tidak sinkron (pola sama `AgendaView.finished` yang dihitung, bukan disimpan).
- **Hard delete** (tanpa `deleted_at`) — konsisten dengan pola tabel premium yang lebih baru (`AgendaReminders`,
  `RecurringRules`), bukan pola lama `Transactions`/`goal_contributions` yang soft-delete.
- **Tanpa foreign key ke Transactions** — sama seperti `recurringId`/`agendaId`, transaksi pelunasan menyimpan
  `debtId` nullable sebagai tautan balik satu arah (lihat §3), bukan Debts yang menyimpan daftar transaksi.
- `Transactions` butuh kolom baru: `debtId` (TextColumn nullable, tanpa FK — pola identik `agendaId`).

**Nomor versi skema**: cek versi Drift terkini di `lib/data/database.dart` saat implementasi mulai — jangan
asumsikan nomor versi tertentu di sini, tergantung urutan pengerjaan relatif terhadap fitur OCR/foto (dokumen
sebelah) yang juga butuh migrasi skema.

## 3. Alur "Catat pembayaran" — atomic, pola sama `executeAgenda()`

Method baru `AppDatabase.recordDebtPayment(...)` (nama final ditentukan saat implementasi), satu transaksi DB:
1. Insert baris `Transactions` baru — **pengeluaran** kalau melunasi utang (uang keluar dari dompet), **pemasukan**
   kalau menerima pembayaran piutang (uang masuk ke dompet). Nominal bebas disesuaikan saat input, tidak terkunci
   ke `amount - paidAmount` sisa (mengikuti prinsip yang sama seperti eksekusi Agenda: estimasi/sisa cuma
   prefill, bukan pengunci) — mendukung pembayaran sebagian (cicilan).
2. `Transactions.debtId` diisi id baris `Debts` terkait.
3. `Debts.paidAmount` bertambah sebesar nominal transaksi yang baru dicatat.

Dipicu dari aksi baru "Catat pembayaran" di halaman detail/list utang-piutang, membuka `TransactionFormPage`
dalam mode baru (tambah parameter `fromDebtPayment`, pola identik `fromAgenda` — prefill nominal sisa
`amount - paidAmount`, catatan dari `counterpartyName`, tipe transaksi terkunci sesuai `DebtType`, tetap bisa
diedit sebelum simpan).

## 4. UI

- `lib/features/debts/debts_page.dart` (baru) — daftar, kemungkinan dengan filter/tab Utang vs Piutang, tiap
  baris menampilkan sisa (`amount - paidAmount`), status lunas kalau sisa 0.
- `lib/features/debts/debt_form_page.dart` (baru) — tambah/edit (nama pihak, tipe, pokok, jatuh tempo opsional,
  catatan).
- Tile baru "Utang & Piutang" di Pengaturan → Kelola, pola sama tile Agenda — discovery surface.
- Gating premium: entry point tetap tampil untuk pengguna gratis (label "Fitur Premium"), tap → `SubscriptionPage`
  — pola sama semua titik premium lain, cek lewat `isPremiumProvider` yang sudah ada.

### Opsional, bukan cakupan MVP (dicatat supaya tidak lupa, bukan janji dikerjakan)

- Kartu ringkasan di Dashboard (total utang vs piutang outstanding) — pola sama kartu Agenda/Proyeksi. Baru
  masuk akal setelah fitur inti (CRUD + pelunasan) terverifikasi, mengikuti urutan yang sama seperti Agenda dulu
  (pengingat dulu, kartu Dashboard menyusul).
- Integrasi ke `monthlyProjectionProvider`/`simulateDailyBalance` (utang jatuh tempo sebagai proyeksi arus kas
  keluar) — secara konsep masuk akal (mirip Agenda/RecurringRules yang sudah terintegrasi), tapi sengaja
  DILUAR cakupan rencana ini supaya MVP tetap fokus: catat, lunas sebagian/penuh, selesai.

## 5. Testing

- Unit test fungsi murni penghitung sisa/status (kalau ada logika non-trivial di luar `amount - paidAmount`
  langsung — kemungkinan besar cukup sederhana, tidak butuh file terpisah).
- DB test untuk `recordDebtPayment()` — atomicity (transaksi + update `paidAmount` sekaligus, mirip pola
  `test/agenda_execute_test.dart`), termasuk kasus pembayaran sebagian berkali-kali sampai lunas.
- Widget test `debts_page.dart` (list, filter, status lunas) dan `debt_form_page.dart` (create/edit) — pola sama
  `test/agenda_page_test.dart`.
- Widget test `TransactionFormPage` dengan `fromDebtPayment` terisi.
- Test migrasi skema untuk `Debts` + `Transactions.debtId` baru (pola sama `test/migration_test.dart` yang sudah
  ada, termasuk guard `addColumn` kalau tabel `Transactions` bisa dibuat fresh dengan kolom ini sudah ada di step
  migrasi versi rendah — pola sama gotcha yang berulang di migrasi-migrasi sebelumnya).

## 6. Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| Pembayaran sebagian (cicilan) bisa bikin `paidAmount` tidak sinkron kalau ada bug di `recordDebtPayment()` | Satu method atomic (§3), diuji DB test khusus, bukan dua operasi terpisah yang bisa gagal di tengah |
| Scope creep ke arah reminder/notifikasi jatuh tempo (mirip Agenda) sebelum CRUD inti selesai | MVP ini sengaja TIDAK termasuk notifikasi jatuh tempo — kalau dibutuhkan, itu fitur susulan terpisah setelah CRUD+pelunasan terverifikasi, sama seperti urutan Agenda dulu |
| Backup lama (`formatVersion` sebelumnya) tidak punya tabel `Debts` | `formatVersion` naik lagi, field baru opsional saat parse — pola identik tiap kenaikan versi backup sebelumnya |

## 7. Checklist implementasi (centang lintas sesi)

- [x] Skema: tabel `Debts` baru + `Transactions.debtId` — [database.dart](../lib/data/database.dart), schema v7 → v8
      (`Debts` disisipkan setelah `AgendaReminders`; `enum DebtType { debt, receivable }`; `DebtView.settled`
      diturunkan dari `paidAmount >= amount`, bukan kolom terpisah, sesuai §2)
- [x] Migrasi + test migrasi — `if (from < 8) { createTable(debts); addColumn(transactions, debtId); }`;
      kasus baru di [migration_test.dart](../test/migration_test.dart) (v7 → v8, transaksi lama tetap
      `debtId == null`, tabel `debts` baru berfungsi lewat `addDebt`+`recordDebtPayment`)
- [x] `AppDatabase.recordDebtPayment(...)` — atomic (`transaction()`, insert Transaksi + update `paidAmount`
      sekaligus, pola sama `executeAgenda()`), 8 DB test di [debt_execute_test.dart](../test/debt_execute_test.dart)
      (CRUD, validasi nama/nominal, arah pengeluaran/pemasukan sesuai `DebtType`, akumulasi cicilan sampai lunas,
      overpay tetap `settled == true`)
- [x] [debts_page.dart](../lib/features/debts/debts_page.dart) — list + popup menu Ubah/Catat pembayaran/Hapus
      (bukan filter tab terpisah — diurutkan `paidAmount` asc lalu `createdAt` asc, yang belum lunas/cicilan
      tertua tampil duluan; keputusan implementasi, bukan penyimpangan dari rencana karena §4 hanya bilang
      "kemungkinan" filter/tab)
- [x] [debt_form_page.dart](../lib/features/debts/debt_form_page.dart) — tambah/edit (tipe terkunci saat edit,
      sesuai §3 "tipe transaksi terkunci"; `updateDebt` sengaja tanpa parameter `type`)
- [x] Param `fromDebtPayment` di [transaction_form_page.dart](../lib/features/transactions/transaction_form_page.dart)
      (`_Mode.payDebt`, prefill sisa `amount - paidAmount`, catatan dari `counterpartyName`, tipe transaksi
      terkunci sesuai `DebtType` — persis pola `fromAgenda`)
- [x] Tile "Utang & Piutang" di Pengaturan → Kelola ([settings_page.dart](../lib/features/settings/settings_page.dart),
      `_DebtsTile`) — gating premium penuh (tanpa versi gratis, sesuai §1), pola identik `_CloudBackupTile`
- [x] Widget test — 6 test di [debts_page_test.dart](../test/debts_page_test.dart) (gating premium, empty state,
      tambah utang, tambah piutang + pembayaran sebagian via popup menu, pelunasan penuh menyembunyikan aksi
      "Catat pembayaran", hapus)
- [x] Backup: `Debts` disertakan di [backup.dart](../lib/data/backup.dart), `formatVersion` 5 → 6 (export/parse/
      integrity check/restore, pola identik penambahan `agendaReminders` sebelumnya)
- [x] `flutter analyze` + `flutter test` penuh — 391/391 test lulus, hanya 1 info-level lint pra-eksisting
      tidak terkait (`database.dart:2115`, curly braces) yang sudah tercatat di luar cakupan sejak awal sesi
- [x] Verifikasi manual di HP (2026-09-29): tambah utang (Budi, Rp500rb) dan piutang (Sari, Rp300rb) —
      keduanya tampil benar di daftar dengan warna/ikon sesuai tipe; pembayaran sebagian piutang (Rp100rb via
      popup menu "Catat pembayaran") mengurangi sisa jadi Rp200rb dan mencatat transaksi PEMASUKAN nyata
      ("Gaji · Bale · Sari · +Rp 100.000") di daftar Transaksi; pelunasan penuh utang (Rp500rb) menandai
      "Lunas", memindahkan baris ke urutan akhir daftar (sort `paidAmount` asc terbukti benar), menyembunyikan
      aksi "Catat pembayaran" dari popup menu (hanya Ubah/Hapus tersisa), dan mencatat transaksi PENGELUARAN
      nyata ("Cicilan · Bale · Budi · -Rp 500.000"). Prefill form pembayaran (nominal = sisa, catatan =
      counterpartyName, kategori terkunci ke arah income/expense sesuai `DebtType`) terverifikasi sesuai
      desain §3. Tidak ada regresi pada data transaksi lain. **Belum sempat**: uji siklus backup/restore ke
      Drive dengan tabel `debts` (fitur inti sudah terverifikasi penuh; backup/restore Drive untuk fitur ini
      dianggap risiko rendah karena pola `export`/`restore`-nya identik dengan tabel premium lain yang sudah
      teruji, seperti `agendaReminders`)
- [x] Update `docs/GAP-ANALISA-2026-09-24.md` — utang/piutang pindah dari ❌ ke ✅ (2026-09-29)

## 8. Susulan — kategori khusus "Utang"/"Piutang" untuk pelacakan (2026-09-29)

Setelah verifikasi manual di atas, pemilik menemukan pembayaran piutang tercatat di kategori pemasukan biasa
(mis. "Gaji") karena §3 memang tidak menspesifikasikan kategori — pengguna bebas pilih kategori pemasukan/
pengeluaran apa saja seperti transaksi biasa. Pemilik memutuskan (via `AskUserQuestion`) ini kurang mudah
dilacak, dan meminta kategori khusus. Keputusan final: kategori baru **"Utang"** (pengeluaran) dan
**"Piutang"** (pemasukan) ditambahkan ke seed kategori bawaan, **diprapilih otomatis** saat form "Catat
pembayaran"/"Catat penerimaan" dibuka tapi **tetap bisa diganti** pengguna ke kategori lain (mis. atribusi ke
Kesehatan/Belanja) — bukan dikunci, supaya fleksibilitas atribusi kategori asli tidak hilang sepenuhnya, hanya
defaultnya yang berubah.

Implementasi:
- Schema v8 → **v9**: dua baris kategori baru (`cat-exp-utang` "Utang", `cat-inc-piutang` "Piutang", ikon
  `debt` baru → `Icons.handshake_rounded`) ditambahkan lewat migrasi `if (from < 9)` dengan `insertOrIgnore`
  (aman diulang), BUKAN cuma lewat `_seed()` — supaya pengguna yang sudah lama pakai app (seperti HP pemilik)
  juga dapat kategori baru ini, bukan hanya instalasi baru. Ini contoh pertama migrasi Drift di app ini yang
  isinya murni penyisipan data seed, bukan perubahan struktur tabel.
- `TransactionFormPage`'s `_Mode.payDebt` `initState()`: `_categoryId` diprapilih ke id kategori baru sesuai
  `DebtType` (tidak mengubah §3 "tetap bisa diedit sebelum simpan").
- Test baru: 1 DB test kategori seed tersedia, 1 DB test `recordDebtPayment` menerima categoryId baru, 1 test
  migrasi v8→v9 (kategori lama utuh + kategori baru otomatis muncul), 2 widget test (ChoiceChip terpilih
  otomatis tanpa tap manual, transaksi hasil simpan benar tertaut kategori baru). Total test: 391 → **397**.
- **Diverifikasi ulang di HP nyata (2026-09-29)**: migrasi v8→v9 berjalan mulus di HP dengan data nyata,
  kategori "Piutang" (ikon jabat tangan, warna teal) tampil terpilih otomatis di form tanpa tap manual,
  transaksi hasil simpan benar tercatat di bawah kategori "Piutang" (bukan lagi "Gaji").
