# Catatan Sesi — DompetKu (23–24 September 2026)

Rekaman informasi kunci dari sesi ini: keputusan beserta alasannya, status, bug & pelajaran, dan hal yang masih
terbuka. Sesi ini fokus ke **3 fitur premium tambahan** (Analisa Tren, Pengingat Transaksi Berulang, Pengingat
Agenda) dan diakhiri dengan **verifikasi nyata di HP** memakai data pengguna asli — bukan cuma widget test.
Lanjutan dari `docs/CATATAN-SESI-2026-09-23.md` (fokus sesi itu: monetisasi iklan/langganan/backup cloud). Sesi
ini dimulai dari PC lama dan **dilanjutkan dari PC Ubuntu baru lewat Remote Control** — satu sesi Claude Code
yang sama, bukan sesi terpisah.

---

## 1. Ringkasan

Rencana lengkap 4 bagian (tersimpan di `~/.claude/plans/streamed-wiggling-mountain.md`) dikerjakan tuntas sesuai
urutan yang disepakati: **Analisa Tren** dulu (paling murah, tanpa kapabilitas native baru) → **infrastruktur
notifikasi terjadwal** bersama → **pengingat transaksi berulang** → **pengingat agenda**. Skema database naik
dari v4 ke v5. Semuanya lalu diuji **sungguhan di HP** (bukan cuma widget test): AlarmManager Android
benar-benar mendaftarkan alarm dengan waktu yang tepat, terkonfirmasi lewat `adb shell dumpsys alarm`. Dua bug
nyata ketahuan dan diperbaiki dari sesi uji coba ini (lihat bagian 4). 268 tes di awal sesi → **291 tes** di
akhir, analyzer bersih (kecuali satu info lint lama yang tidak terkait, `database.dart:1826`, dibiarkan karena di
luar cakupan sesi).

## 2. Keputusan arsitektur & desain (beserta alasan)

| Keputusan | Alasan |
|---|---|
| Urutan pengerjaan: Tren → infra notifikasi → pengingat recurring → pengingat agenda | Tren tidak butuh kapabilitas native baru (cepat kelihatan hasilnya); infra notifikasi dibangun sekali lalu dipakai bersama oleh 2 fitur pengingat, bukan dua kali |
| Notifikasi terjadwal pakai `AndroidScheduleMode.inexactAllowWhileIdle`, BUKAN mode exact | Tidak butuh izin `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` sama sekali — cukup akurat untuk pengingat H-1/H-3/H-7 (boleh meleset beberapa menit-jam), konsisten dengan filosofi app ini yang sejauh ini menghindari izin/servis latar belakang baru |
| `NotificationSender` dipindah dari `lib/features/budget/` ke `lib/core/notification_sender.dart` | Sudah dipakai 3 fitur (anggaran, pengingat recurring, pengingat agenda) — bukan lagi spesifik-anggaran |
| Analisa Tren dibuat **per kategori** (bukan income-vs-expense seperti grafik gratis di Dashboard) | Harus jadi pembeda nyata dari fitur gratis yang sudah ada, bukan cuma versi premium dari hal yang sama |
| Skema v5: 2 kolom baru di `RecurringRules` + tabel baru `AgendaReminders` (bukan 2 migrasi terpisah) | Satu bump versi untuk 2 perubahan yang berdekatan, hindari pengguna riil harus migrasi dua kali |
| `AgendaReminders` sengaja **tidak punya kolom finansial** (type/amount/account/category) | Agenda murni pengingat (servis kendaraan, servis AC, dll), tidak terkait transaksi — beda dari `RecurringRules` yang memang menghasilkan transaksi |
| Toggle "Ingatkan saya" di form transaksi berulang: kalau belum premium, baris tetap TAMPIL (bukan disembunyikan) dengan subtitle "Fitur Premium" | Pola sama semua titik premium lain di app ini — pengguna gratis tahu fiturnya ada, bukan disembunyikan total |

## 3. Status fitur baru (semua terverifikasi di HP dengan data nyata)

- **Analisa Tren** (`lib/features/trends/`): `trend_page.dart` (grafik garis per kategori top-5, `fl_chart`,
  jendela 3/6/12 bulan lewat `SegmentedButton`), `trend_settings.dart` (`trendWindowMonthsProvider`, tersimpan di
  `KeyValueStore`). Insight teks otomatis: kategori dengan kenaikan % terbesar bulan terakhir vs rata-rata bulan
  sebelumnya — dihitung murni di Dart dari data yang sudah diambil, bukan query tambahan. Diverifikasi di HP: data
  nyata pengguna cuma 1 bulan → `EmptyState` "Butuh minimal 2 bulan data" tampil benar (bukan bug, memang belum
  cukup data).
- **Infra notifikasi terjadwal** (`lib/core/notification_sender.dart`): `NotificationSender` diperluas dengan
  `schedule()`/`cancel()` (sebelumnya cuma `show()` untuk notifikasi anggaran). Diverifikasi: `adb shell dumpsys
  alarm` menunjukkan alarm `RTC_WAKEUP` sungguhan terdaftar dengan tag
  `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` pada waktu yang persis sesuai
  perhitungan (mis. jatuh tempo 23 Okt, H-1, jam 08:00 → alarm terdaftar tepat `2026-10-22 08:00:00.000`).
- **Pengingat transaksi berulang** (`lib/features/recurring/recurring_reminder_service.dart`): toggle "Ingatkan
  saya" + pilihan H-1/H-3/H-7 di `transaction_form_page.dart`, dijadwalkan ulang tiap app dibuka/resume lewat
  `_rescheduleReminders()` di `lib/app.dart`.
- **Pengingat agenda** (`lib/features/agenda/`): halaman CRUD baru (`agenda_page.dart`, `agenda_form_page.dart`),
  cocok untuk servis kendaraan/AC/biaya pendidikan — tidak terkait transaksi. Tile baru "Agenda" di Pengaturan →
  Kelola.

Total tes: 268 (awal sesi) → 271 (tren) → 288 (infra + kedua fitur pengingat) → **291** (setelah perbaikan bug
`cancelFor`/SnackBar di bagian 4).

## 4. Bug & pelajaran hari ini

| Kejadian | Akar masalah | Pelajaran |
|---|---|---|
| Menghapus aturan berulang/agenda **tidak membatalkan** alarm yang sudah terjadwal untuknya — alarm "yatim" tetap ada di AlarmManager, ketahuan lewat `dumpsys alarm` setelah data uji coba dihapus | `reschedule()` cuma bisa membatalkan pengingat untuk baris yang MASIH ada di database (mis. yang dijeda). Begitu baris dihapus total, baris itu tidak lagi muncul di daftar yang diberikan ke `reschedule()`, jadi tidak pernah tersentuh lagi | Tambahkan method eksplisit `cancelFor(id)` di `RecurringReminderService`/`AgendaReminderService`, dipanggil LANGSUNG dari handler hapus di halaman (`recurring_page.dart`/`agenda_page.dart`), bukan mengandalkan siklus reschedule berikutnya |
| **Ditemukan pengguna sendiri** (bukan dari uji coba terencana): toast "Transaksi dihapus" (dengan tombol Batal) tidak pernah hilang sendiri — nongkrong bermenit-menit, menutupi tampilan di belakangnya | `ScaffoldMessenger.clearSnackBars()` memicu `hideCurrentSnackBar()` yang menjalankan animasi keluar lewat **ticker** (`AnimationController.reverse()`) — ticker itu sendiri bisa ikut membeku saat app masuk `AppLifecycleState.paused` (layar mati/app di latar belakang), jadi animasi "keluar"-nya juga ikut macet, bukan cuma timer 4 detiknya | `removeCurrentSnackBar()` dipakai sebagai gantinya (bukan `clearSnackBars()`) — men-set `value` controller LANGSUNG tanpa animasi berjalan, jadi tidak bergantung ticker sama sekali. Diverifikasi lewat widget test yang men-simulasikan `AppLifecycleState.paused` (pola `_background()`/`_foreground()` dari `test/app_lock_flow_test.dart`) DAN diverifikasi ulang di HP sungguhan: hapus transaksi → app ke background → buka lagi → toast sudah hilang |
| Sempat lupa mengembalikan hack sementara `isPremiumProvider` (di-hardcode `Stream.value(true)` untuk verifikasi manual fitur premium di HP) — menyebabkan 7 test "belum premium" gagal saat full-suite dijalankan lagi | Pola "ubah sementara untuk verifikasi manual, lalu lupa kembalikan" — sama persis kelas kesalahan yang sudah pernah dicatat di sesi-sesi sebelumnya | Selalu jalankan `flutter test` PENUH (bukan cuma file yang baru diubah) segera setelah revert hack manual, sebelum melanjutkan ke langkah lain — jangan andalkan ingatan bahwa "sudah dikembalikan" |
| Swipe-hapus transaksi di HP sempat **salah sasaran** — menghapus transaksi asli pengguna ("Transfer Livin→Bale") padahal yang dimaksud transaksi uji coba lain | Koordinat swipe diambil dari `uiautomator dump` yang **sudah tidak sinkron** dengan posisi scroll layar saat ini (list bisa bergeser antara waktu dump diambil dan swipe dieksekusi) | Untung ada tombol "Batal" di toast — langsung dipulihkan, tidak ada data hilang. Pelajaran: untuk aksi destruktif di HP (hapus/swipe), SELALU `uiautomator dump` ULANG tepat sebelum aksi, jangan pakai bounds dari dump beberapa langkah sebelumnya |
| Popup **Avast One** menandai DompetKu sebagai "aplikasi mencurigakan" dan menyarankan uninstall, muncul begitu APK debug baru dipasang | False positive umum untuk APK debug hasil sideload (`adb install`, sertifikat debug, bukan dari Play Store) — bukan indikasi masalah nyata pada aplikasi | Dialognya dibatalkan (tombol "Batal"), TIDAK menekan "Hapus instal" — akan hilang sendiri begitu rilis resmi ditandatangani dan didistribusikan lewat Play Store |

## 5. Migrasi skema v4 → v5

`RecurringRules` dapat 2 kolom baru (`reminderEnabled` default `false`, `reminderDaysBefore` default `1`), tabel
baru `AgendaReminders`. Diuji dengan `SchemaVerifier` (pola sama migrasi v1-v4 sebelumnya): data pengguna v4 asli
(aturan berulang tanpa kolom reminder) tetap utuh setelah migrasi, kolom baru terisi nilai default yang aman,
tabel agenda baru kosong tapi CRUD-nya langsung berfungsi. Satu jebakan ketemu saat menulis migrasinya: kalau
`RecurringRules` baru dibuat di step migrasi `from < 2` (pengguna dari v1), `createTable()` di situ sudah otomatis
memakai definisi kolom TERKINI (termasuk kolom reminder yang baru) — `addColumn` untuk kolom yang sama di step
`from < 5` jadi **duplicate column error**. Diperbaiki dengan guard `if (from >= 2)` sebelum `addColumn` supaya
tidak dobel untuk pengguna yang tabelnya baru saja dibuat di step sebelumnya.

## 6. Keputusan yang masih TERBUKA (belum berubah dari sesi sebelumnya, + 1 baru)

1. **Publikasikan kebijakan privasi** ke URL publik — dibutuhkan Play Console.
2. **Isi Data Safety form** di Play Console.
3. **Setup akun RevenueCat** sungguhan — `kRevenueCatApiKey` masih placeholder, pembelian sungguhan belum diuji.
4. **Mulai uji tertutup** Play Store (12 tester × 14 hari).
5. P1/P2 lama: enkripsi database (SQLCipher), `FLAG_SECURE` recent-apps, `deleted_at` belum di semua tabel,
   lapisan repository/domain.
6. **Baru**: sesi ini hanya memverifikasi alarm **terdaftar dengan benar** di AlarmManager (lewat `dumpsys
   alarm`) — belum menunggu sampai notifikasi sungguhan **muncul/berbunyi** pada waktunya (butuh menunggu
   berhari-hari, atau memajukan jam sistem HP untuk uji cepat kalau ingin dipastikan lebih jauh).

## 7. Lingkungan pengembangan — tambahan dari sesi ini

Semua praktik aman dari catatan sesi sebelumnya masih berlaku. Tambahan:
- Untuk iterasi cepat saat verifikasi manual di HP, `flutter run --pid-file flutter.pid
  --host-vmservice-port=8181` di latar belakang lebih efisien daripada build+install manual berulang — hot
  restart (`kill -USR2 $(cat flutter.pid)`) cukup untuk perubahan provider/logic (bukan schema/pubspec).
- Setelah selesai, `flutter build apk --debug` + `adb install -r` (dengan `force-stop` dulu) tetap dilakukan
  sekali di akhir supaya HP menjalankan APK berdiri sendiri, bukan bergantung pada koneksi `flutter run` yang
  bisa terputus.
- Koordinat tap dari `uiautomator dump` HANYA valid untuk state layar persis saat dump diambil — untuk aksi
  ber-konsekuensi (hapus/swipe), dump ulang tepat sebelum aksi, jangan reuse bounds lama.

## 8. Lokasi berkas baru/berubah sesi ini

- `lib/features/trends/` — `trend_page.dart`, `trend_settings.dart` (baru)
- `lib/core/notification_sender.dart` (baru, pindahan dari `lib/features/budget/budget_notification_service.dart`)
- `lib/features/recurring/recurring_reminder_service.dart` (baru)
- `lib/features/agenda/` — `agenda_page.dart`, `agenda_form_page.dart`, `agenda_reminder_service.dart` (baru)
- Diubah: `lib/data/database.dart` (skema v5), `lib/data/providers.dart`, `lib/app.dart`
  (`_rescheduleReminders()` + fix SnackBar), `lib/features/transactions/transaction_form_page.dart` (toggle
  pengingat), `lib/features/settings/settings_page.dart` (tile Analisa Tren + Agenda), `pubspec.yaml`
  (`flutter_timezone` baru, `timezone` dipromosikan jadi dependency langsung)
- Skema Drift: `drift_schemas/drift_schema_v5.json`, `test/generated_migrations/schema_v5.dart` (+ `schema.dart`
  ter-generate ulang)
- Tes baru: `test/trend_page_test.dart`, `test/recurring_reminder_service_test.dart`,
  `test/agenda_reminder_service_test.dart`, `test/agenda_page_test.dart`; diperluas:
  `test/edit_recurring_flow_test.dart`, `test/migration_test.dart`, `test/app_flow_test.dart`,
  `test/cloud_backup_page_test.dart`, `test/support/harness.dart`
- Rencana lengkap (sudah selesai dieksekusi): `~/.claude/plans/streamed-wiggling-mountain.md`
- Dokumen: `docs/CATATAN-SESI-2026-09-24.md` (berkas ini)

---

## 11. Bagian kedua sesi ini — model freemium "cicip terbatas" (Agenda, Analisa Tren)

Setelah Bagian 1-4 di atas selesai, diskusi produk berlanjut: Agenda dan Analisa Tren terkunci premium sejak hari
1 tanpa jalur coba, berisiko jarang ditemukan pengguna padahal jadi fitur unggulan. Keputusan (detail lengkap +
alasan di [[dompet-pintar-monetization-plan]]):

- **Masa tenggang iklan 15 → 30 hari** — biar pengguna baru sempat lihat satu siklus keuangan bulanan utuh
  sebelum iklan muncul, bukan cuma separuh siklus.
- **Agenda gratis sampai 3 item aktif** (`kFreeAgendaLimit`), item ke-4+ perlu premium untuk DIBUAT. Turun dari
  premium dengan >3 item: data tidak pernah dihapus paksa, cuma pengingat untuk item DI LUAR kuota yang berhenti
  — 3 item **tertua** (`createdAt`) yang tetap dapat pengingat, logika sama untuk pengguna yang selalu gratis
  maupun yang baru turun tingkat (tanpa flag "pernah premium" terpisah).
- **Analisa Tren gratis untuk jendela 3 bulan**, 6/12 bulan perlu premium (tap segmen itu saat belum premium
  mengarahkan ke `SubscriptionPage`, bukan mengubah data yang tampil).
- **Backup Cloud dan pengingat transaksi berulang SENGAJA TIDAK diubah** — tetap murni premium. Backup Cloud
  ditolak dapat versi "cicip" karena satu-satunya opsi yang natural (backup gratis, restore bayar) berarti
  menyandera data pengguna — bertentangan dengan prinsip recoverability-first fitur ini.
- `SubscriptionPage` yang sebelumnya cuma bilang "Hilangkan iklan..." sekarang punya daftar 4 manfaat eksplisit
  (`_BenefitList`) — ditemukan sebagai gap terpisah: titik jual utama app selama ini tidak pernah menyebut
  Analisa Tren/Backup Cloud/Agenda sama sekali.

**Perbaikan tes penting**: satu tes lama (`ad_eligibility_service_test.dart`) menghardkode total 15 hari secara
implisit (`10 + 5`) alih-alih memakai `AdEligibilityService.gracePeriod` secara simbolik seperti tes lain di
file yang sama — baru ketahuan gagal setelah masa tenggang dinaikkan ke 30 hari, diperbaiki jadi simbolik penuh.
Pelajaran: kalau ada beberapa tes untuk satu konstanta, pastikan SEMUA memakai nama konstanta, bukan cuma
sebagian — satu tes yang menghardkode angka langsung lolos review sekilas tapi baru meledak saat konstantanya
berubah.

Status: implementasi selesai, **298 tes lolos** (291 sebelumnya + 7 baru), `flutter analyze` bersih. Belum
diverifikasi manual di HP (perubahan ini murni logika Dart/UI, tidak menyentuh skema database atau plugin
native, jadi risiko regresi yang cuma kelihatan di device asli relatif rendah — tapi tetap catatan terbuka kalau
ingin dipastikan langsung).

### Berkas yang diubah di bagian ini
`lib/features/ads/ad_eligibility_service.dart` (+ komentar di `app.dart`/`banner_ad_widget.dart`/
`providers.dart`), `lib/data/providers.dart` (`categoryTrendProvider`), `lib/features/trends/trend_page.dart`,
`lib/features/agenda/agenda_reminder_service.dart` (`kFreeAgendaLimit`, `reschedule` param baru), `lib/app.dart`
(`_rescheduleReminders` dipecah), `lib/features/agenda/agenda_page.dart` (gerbang FAB + penanda terkunci),
`lib/features/settings/settings_page.dart` (`_TrendAnalysisTile`/`_AgendaTile` disederhanakan),
`lib/features/subscription/subscription_page.dart` (`_BenefitList`); tes: `test/trend_page_test.dart`,
`test/agenda_reminder_service_test.dart`, `test/agenda_page_test.dart`, `test/subscription_page_test.dart`,
`test/ad_eligibility_service_test.dart`.

(Susulan tak terdokumentasikan di sini: kartu ringkasan Agenda di Dashboard — `upcomingAgendaProvider`,
`_AgendaCard`/`_AgendaRow` di `dashboard_page.dart`, `test/dashboard_agenda_card_test.dart` — sudah
diimplementasikan, diuji, dan diverifikasi di HP sebelum bagian di bawah ini dikerjakan.)

---

## 12. Bagian ketiga sesi ini — dimensi finansial Agenda (estimasi biaya & eksekusi)

Diskusi produk lanjutan: Agenda sampai titik ini murni pengingat kegiatan, nol kolom finansial — padahal
DompetKu adalah app manajemen keuangan. Pemilik produk ingin Agenda merepresentasikan **rencana pengeluaran**
(rutin/insidental) supaya kelak bisa jadi dasar proyeksi/forecast anggaran bulanan (fitur terpisah, menyusul).
Keputusan kunci pemilik produk yang membentuk desainnya: saat agenda **dieksekusi**, nominal transaksi
nyatanya **boleh disesuaikan**, tidak terkunci pada estimasi — bukan estimasi murni yang tak pernah jadi
transaksi, dan bukan auto-generate diam-diam ala `RecurringRules.generateDueRecurring()`.

Perubahan (skema Drift v5 → v6):
- **`AgendaReminders.estimatedAmount`** (nullable, opsional) — nilai AWAL nominal transaksi saat dieksekusi,
  bukan pengunci.
- **`Frequency.once`** ("Sekali") — frekuensi baru untuk rencana insidental (bukan berulang), ditambah di AKHIR
  enum (index disimpan mentah di SQLite, aman ditambah di akhir, bahaya disisipkan di tengah). `occurrenceAt`
  untuk `once` selalu mengembalikan tanggal mulai konstan; `AgendaView.finished` untuk `once` dites lewat
  `nextIndex > 0` (bukan `endDate`, yang tidak relevan untuk kejadian tunggal). Dikecualikan dari dropdown
  pembuatan `RecurringRules` — "tidak berulang" di form itu sudah diwakili `_frequency == null`.
  **Gotcha 2 kali ditemukan** (mirror gotcha `recurringRules` v1→v2 yang sudah ada): (1) `occurrenceAt`/
  `firstIndexOnOrAfter` untuk `once` mengembalikan nilai KONSTAN — loop `while` yang ada di
  `advancePastAgenda`/`firstIndexOnOrAfter` akan hang tanpa jalur khusus; (2) migrasi `addColumn` untuk
  `estimatedAmount` gagal "duplicate column" saat migrasi dari v4 ke bawah, karena `agendaReminders` baru
  dibuat di step `from<5` dengan definisi TERKINI (sudah termasuk `estimatedAmount`) — diperbaiki dengan guard
  `if (from >= 5)` sebelum `addColumn`, identik pola guard `recurringRules`.
- **`Transactions.agendaId`** (nullable, tanpa foreign key — pola sama `recurringId`) — menautkan transaksi ke
  agenda asalnya.
- **`AppDatabase.executeAgenda(...)`** (baru) — satu transaksi DB: mencatat transaksi pengeluaran nyata
  (nominal bebas beda dari estimasi) + memajukan `nextIndex` satu langkah (seragam untuk `once` maupun
  berulang). Dipicu dari aksi baru "Catat transaksi" di menu `_AgendaTile`, membuka `TransactionFormPage` mode
  `executeAgenda` baru (nominal/catatan prefill dari estimasi/judul, keduanya tetap bisa diketik ulang).

Status: implementasi selesai, **320 tes lolos** (303 sebelumnya + 17 baru: `recurrence_test.dart` kasus
`once`, `agenda_execute_test.dart` baru DB+widget, `migration_test.dart` kasus v5→v6), `flutter analyze` bersih.
Gap terpisah ditemukan sambil jalan (di luar cakupan bagian ini, ditandai lewat `spawn_task`): backup cloud
(`lib/data/backup.dart`) tidak pernah menyertakan `AgendaReminders` sama sekali — sudah ada sejak Agenda
pertama dibuat, makin berisiko sekarang datanya lebih berharga (ada estimasi biaya).

### Berkas yang diubah di bagian ini
`lib/data/database.dart` (skema v6: `Frequency.once`, `AgendaReminders.estimatedAmount`,
`Transactions.agendaId`, `AgendaView.finished`, `advancePastAgenda`, `addAgenda`/`updateAgenda`,
`executeAgenda` baru), `lib/data/recurrence.dart` (`Frequency.once` di 4 fungsi),
`lib/features/agenda/agenda_form_page.dart` (field estimasi, opsi Sekali, field Berakhir disembunyikan untuk
Sekali), `lib/features/agenda/agenda_page.dart` (aksi "Catat transaksi"),
`lib/features/transactions/transaction_form_page.dart` (mode `executeAgenda` baru); skema Drift:
`drift_schemas/drift_schema_v6.json`, `test/generated_migrations/schema_v6.dart` (+ regenerasi file lain);
tes: `test/recurrence_test.dart`, `test/agenda_execute_test.dart` (baru), `test/migration_test.dart`.

---

## 13. Bagian keempat sesi ini — gap backup cloud (Agenda) + pengingat berkala

Dua perbaikan kecil terkait Backup Cloud, sama-sama tidak menyentuh skema Drift (backup format JSON internal,
bukan tabel database).

**Gap backup Agenda diperbaiki**: `lib/data/backup.dart` (export/restore JSON ke Google Drive) ternyata TIDAK
PERNAH menyertakan tabel `AgendaReminders` sejak Agenda pertama dibuat (schema v5) — ditemukan sambil
membicarakan fitur finansial Agenda di atas. `formatVersion` 4 → 5: `BackupData` dapat field `agendaReminders`
(default `const []`, opsional saat parse supaya backup lama tetap valid), `_checkIntegrity()` cuma cek ID tidak
ganda + estimasi positif (tidak ada foreign key ke akun/kategori, beda dari `recurringRules`), `restore()` ikut
menghapus+insert tabel ini dalam transaksi yang sudah ada. Klarifikasi penting dari pemilik produk: uji coba
backup cloud manual terakhir (dengan hack sementara `isPremiumProvider`) dilakukan SEBELUM fitur Agenda
diimplementasikan — jadi gap ini memang belum pernah teruji sama sekali sebelumnya, bukan regresi baru.

**Pengingat berkala backup cloud (baru)**: `lib/features/cloud_backup/cloud_backup_reminder_service.dart` —
pola sama `BudgetNotificationService` (dicek di `initState`/`resumed`, bukan alarm terjadwal), TAPI dengan
throttle tambahan karena `CloudBackupService.lastBackupAt()` memanggil Drive API lewat jaringan (beda dari
budget yang murni baca DB lokal): maksimal 1x panggilan jaringan per hari kalender, dan notifikasi sendiri
tidak diulang sebelum interval (mingguan/bulanan, pengguna pilih) berlalu lagi sejak terakhir ditampilkan.
Setelan (aktif/tidak, interval) disimpan lewat `KeyValueStore` yang sudah ada, muncul di `CloudBackupPage`
sebagai `SwitchListTile` + `DropdownButtonFormField` setelah baris "Terakhir backup", pola visual sama
`_ReminderPicker` di `transaction_form_page.dart`.

**Gotcha Riverpod (bukan bug produk, tapi mengubah cara baca status masuk)**: rencana awal memakai
`ref.read(cloudSignedInProvider.future)` (pola sama `isPremiumProvider.future` yang sudah dipakai
`_rescheduleReminders()`) untuk deteksi status masuk di `_checkBackupReminder()`. Ini bikin tes flaky:
`cloudSignedInProvider` TIDAK PERNAH di-watch widget lain manapun kecuali `CloudBackupPage` (jarang dibuka),
jadi resolusinya selalu "dingin" (pertama kali) — beda dari `isPremiumProvider` yang selalu sudah "hangat"
karena terus di-watch banner iklan di hampir semua layar. Kombinasi resolusi dingin + `ProviderScope` yang bisa
dibuang tak lama setelah `initState` (skenario tes, `tester.pumpWidget(const SizedBox())` di `finally` harness)
membuat `StreamProvider`-nya di-dispose sebelum sempat emit — `Bad state: ... was disposed during loading
state, yet no value could be emitted`, dibungkus try/catch jadi tidak sampai gagalkan tes, tapi jadi noise di
HAMPIR SEMUA tes lain (dan satu tes baru yang sengaja membuktikan pemasangan tetap gagal walau delay ditambah —
bukan soal kecepatan, murni siklus hidup provider). Diperbaiki dengan baca `ref.read(cloudBackupServiceProvider).watchSignedIn().first`
langsung dari layanannya, BUKAN lewat provider — tidak terikat siklus hidup `StreamProvider` sama sekali.
**Pelajaran**: `ref.read(xProvider.future)` sekali-pakai aman kalau provider itu SUDAH biasa di-watch tempat
lain (selalu "hangat"); untuk provider yang jarang/tidak pernah di-watch di luar satu pemanggilan sekali-pakai,
baca langsung dari sumbernya (stream/service), jangan lewat provider — hindari beban siklus-hidup yang tidak
perlu.

**Bug kedua ditemukan LANGSUNG di HP saat verifikasi manual (bukan lewat test)**: begitu di-install, aplikasi
langsung memicu dialog sistem "Login dengan Google" di HALAMAN RINGKASAN (bukan di halaman Backup Cloud) —
pemilik produk melaporkan "aplikasi terus mengulang proses login ke google drive". Penyebab: `_checkBackupReminder()`
awalnya membaca status masuk lewat `watchSignedIn()` (langsung atau lewat `cloudSignedInProvider`), yang pada
implementasi nyata (`GoogleDriveCloudBackupService`) memanggil `attemptLightweightAuthentication()` — TERNYATA
tidak selalu diam-diam walau namanya "lightweight", bisa menampilkan dialog akun yang TERLIHAT. Karena
pengecekan ini jalan di SETIAP buka app (bukan cuma saat membuka halaman Backup Cloud), efeknya dialog itu
muncul mengganggu di halaman mana pun. Diperbaiki dengan pola baru: `CloudBackupService` dapat method
`cachedSignedIn()` — baca status masuk TERAKHIR DIKETAHUI dari `KeyValueStore` LOKAL, tanpa panggilan
jaringan/akun sama sekali; ditulis oleh `signIn()`/`signOut()` (dan oleh `watchSignedIn()` sendiri saat berhasil
lightweight-auth, untuk kasus akun Google yang masih tersimpan di OS setelah pasang ulang). `_checkBackupReminder()`
sekarang HANYA baca `cachedSignedIn()`. Diverifikasi hasilnya langsung di HP: Ringkasan terbuka bersih tanpa
dialog apa pun setelah perbaikan.

Status: implementasi selesai (termasuk perbaikan bug dialog di atas), **332 tes lolos** (321 sebelumnya + 11
baru), `flutter analyze` bersih, **diverifikasi lengkap di HP nyata**: bug dialog ditemukan-diperbaiki-
diverifikasi hilang, toggle+dropdown pengingat dicoba langsung (lewat hack premium sementara, direvert +
`flutter test` penuh setelahnya — pola sama sesi ini), dan "Backup sekarang" dicoba dengan akun+data nyata
(termasuk Agenda) berhasil ter-upload dengan format v5.

### Berkas yang diubah di bagian ini
`lib/data/backup.dart` (`agendaReminders`, `formatVersion` 5),
`lib/features/cloud_backup/cloud_backup_reminder_service.dart` (baru),
`lib/features/cloud_backup/cloud_backup_service.dart` (`cachedSignedIn()` baru + `_kSignedInFlag`),
`lib/data/providers.dart` (`cloudBackupReminderServiceProvider`), `lib/app.dart` (`_checkBackupReminder`),
`lib/features/cloud_backup/cloud_backup_page.dart` (toggle+dropdown pengingat); tes:
`test/export_backup_test.dart` (perluas), `test/cloud_backup_reminder_service_test.dart` (baru),
`test/cloud_backup_page_test.dart` (perluas), `test/support/harness.dart` (`FakeCloudBackupService` constructor
params baru + `cachedSignedIn()`).

---

## 14. Bagian kelima sesi ini — proyeksi/forecast keuangan bulanan

Kelanjutan langsung fitur estimasi biaya Agenda: sejak awal tujuannya supaya data itu bisa dipakai bikin
proyeksi kebutuhan anggaran bulanan, bukan cuma tercatat. Keputusan produk (dikonfirmasi lewat `AskUserQuestion`):
kartu baru di Dashboard, **premium penuh** (beda dari Agenda/Analisa Tren yang "cicip" — konsisten Backup
Cloud), total + rincian per sumber (Agenda vs transaksi berulang).

Proyeksi = jumlah **pengeluaran** (bukan pemasukan/transfer) dari kejadian Agenda (estimasi biaya) + transaksi
berulang yang jatuh dalam BULAN KALENDER BERJALAN (bukan bulan yang sedang dilihat di halaman lain) — murni dari
komitmen yang sudah terjadwal, bukan prediksi statistik dari histori. Fungsi murni baru
`occurrencesTotalInRange()` (`lib/data/recurrence.dart`) menghitung total nominal kejadian sebuah aturan
berulang/agenda dalam rentang tanggal, dipakai provider baru `monthlyProjectionProvider` (`lib/data/providers.dart`,
turunan dari `agendaRemindersProvider`/`recurringRulesProvider` yang sudah ada — TIDAK ada query DB baru).
`Frequency.once` ditangani jalur terpisah (bukan lewat loop) — gotcha yang sama seperti sebelumnya
(`occurrenceAt` konstan untuknya) diterapkan lagi secara sengaja di sini supaya tidak dobel-hitung.

Kartu Dashboard baru (`_ProjectionCard`) SELALU tampil (bukan disembunyikan untuk yang belum premium) — yang
premium lihat angka sungguhan, yang belum premium lihat ajakan upgrade ringkas yang membuka `SubscriptionPage`
saat diketuk. `SubscriptionPage`'s `_BenefitList` dapat item ke-5.

**Bug test ditemukan & diperbaiki sendiri (bukan oleh pengguna)**: draft awal test kartu proyeksi men-seed
`RecurringRule` dengan `startDate: DateTime.now()` — ternyata kejadian HARI INI langsung dikonsumsi jadi
transaksi nyata oleh `generateDueRecurring()` (dipanggil tiap buka app) SEBELUM providernya sempat menghitung,
beda dari Agenda yang murni pengingat (`advancePastAgenda` tidak memajukan kejadian hari ini, cuma yang benar-
benar sudah lewat). Diperbaiki dengan `DateTime.now().add(Duration(days: 1))` untuk seed `RecurringRule`
transaksi berulang di test.

Status: implementasi selesai, **343 tes lolos** (332 sebelumnya + 11 baru), `flutter analyze` bersih. Belum
diverifikasi manual di HP (murni provider turunan, tidak ada skema/kolom baru — risiko regresi yang cuma
kelihatan di device asli rendah, tapi kartu baru + perhitungan proyeksi belum dilihat langsung di HP dengan
data nyata).

### Berkas yang diubah di bagian ini
`lib/data/recurrence.dart` (`occurrencesTotalInRange`, baru), `lib/data/providers.dart`
(`MonthlyProjection`, `monthlyProjectionProvider`, baru), `lib/features/dashboard/dashboard_page.dart`
(`_ProjectionCard`, `_ProjectionRow`, baru), `lib/features/subscription/subscription_page.dart`
(`_BenefitList._items` +1); tes: `test/recurrence_test.dart` (perluas),
`test/dashboard_projection_card_test.dart` (baru).

---

## 15. Bagian keenam sesi ini — simulasi kecukupan dana (arus kas harian)

Setelah melihat kartu "Proyeksi Bulan Ini" langsung di HP (build eksplorasi premium yang dipasang khusus untuk
pemilik produk — lihat bawah), beliau menilai kartu itu baru ringkasan RENCANA, belum menjawab "apakah dana
akan cukup SAAT pengeluaran dieksekusi". Ditawarkan dua opsi lewat `AskUserQuestion`: bandingkan Total Saldo
statis vs total proyeksi, ATAU simulasi arus kas HARIAN yang menggabungkan proyeksi pengeluaran dengan
pemasukan berulang sesuai tanggal jatuh tempo masing-masing. **Dipilih simulasi harian** — meniru cara orang
sungguhan mengecek "cukup gak duitnya sampai gajian", bukan cuma bandingkan dua angka statis.

`lib/data/recurrence.dart`'s `occurrencesTotalInRange()` (dari bagian sebelumnya) di-refactor: primitif baru
`occurrenceDatesInRange()` mengembalikan `List<DateTime>` (bukan cuma total), `occurrencesTotalInRange()` jadi
pembungkus tipis di atasnya — satu tempat saja untuk logika `Frequency.once` yang konstan, tidak dobel. File
baru `lib/data/cash_flow.dart` (`CashFlowProjection`, `simulateDailyBalance()`) mensimulasikan saldo hari demi
hari dari Total Saldo saat ini (sumber sama `accountBalancesProvider` yang dipakai `_HeroCard`) + kejadian
Agenda (selalu pengeluaran) DAN transaksi berulang (pengeluaran **maupun pemasukan** — beda sengaja dari
`monthlyProjectionProvider` yang cuma pengeluaran, dua provider ini menjawab pertanyaan berbeda dan
sama-sama tetap ada). Kartu Dashboard dapat blok status baru: "Dana diproyeksikan cukup sepanjang bulan ini"
(centang hijau) atau "Berpotensi kurang RpX pada [tanggal]" (peringatan merah, tanggal PERSIS titik saldo
terendah dalam simulasi).

Status: implementasi selesai, **357 tes lolos** (343 sebelumnya + 14 baru), `flutter analyze` bersih. Belum
diverifikasi manual di HP saat dokumen ini ditulis — akan dibangun ulang ke build eksplorasi premium yang
sudah terpasang di HP pemilik produk (lihat catatan build eksplorasi di bawah).

### Berkas yang diubah di bagian ini
`lib/data/recurrence.dart` (`occurrenceDatesInRange` baru, `occurrencesTotalInRange` jadi pembungkus),
`lib/data/cash_flow.dart` (`CashFlowProjection`, `simulateDailyBalance`, baru), `lib/data/providers.dart`
(`cashFlowProjectionProvider`, baru), `lib/features/dashboard/dashboard_page.dart` (`_ProjectionCard` +blok
status); tes: `test/recurrence_test.dart` (tambahan), `test/cash_flow_test.dart` (baru),
`test/dashboard_projection_card_test.dart` (perluas).

### Catatan proses: build eksplorasi premium (bukan hack sekali-verifikasi seperti biasanya)
Beda dari pola "hack premium → verifikasi cepat → langsung revert" yang dipakai berkali-kali sesi ini, kali ini
pemilik produk secara eksplisit minta build TERPISAH untuk eksplorasi jangka panjang: `isPremiumProvider`
di-hack jadi `Stream.value(true)` HANYA untuk sekali proses build+install ke HP, lalu kode sumber LANGSUNG
direvert dan dikonfirmasi bersih lewat `flutter test` penuh sebelum lanjut kerja lain — build APK yang sudah
ter-install di HP tetap premium permanen (APK yang sudah dikompilasi tidak berubah walau sumbernya direvert),
tapi repo kerja tetap bersih untuk pekerjaan berikutnya. Pola ini diulang lagi setelah fitur simulasi arus kas
selesai supaya build di HP mengikuti kode terbaru.
