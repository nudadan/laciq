import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import 'recurrence.dart';

part 'database.g.dart';

// Urutan enum disimpan sebagai index integer di SQLite: JANGAN diubah urutannya.
enum TxType { income, expense, transfer }

enum AccountKind { cash, bank, ewallet, card }

enum Frequency { weekly, monthly, yearly, once }

enum ContributionKind { deposit, withdrawal }

enum DebtType { debt, receivable }

/// Isi awal sebuah buku kas baru (lihat docs/RENCANA-IMPLEMENTASI-MULTI-BUKU-KAS.md §5).
enum LedgerTemplate { personal, business, blank }

/// Buku kas bawaan. Tidak bisa dihapus atau diarsipkan; semua data yang dibuat
/// sebelum fitur multi buku kas (skema < 10) otomatis masuk ke sini.
///
/// Kolom `ledgerId` memakai literal `'ledger-main'` sebagai default, bukan
/// konstanta ini: berkas skema tergenerasi untuk tes migrasi menyalin
/// ekspresi default apa adanya dan tidak bisa mengimpor konstanta ini. Kalau
/// nilai ini pernah diubah, ubah juga semua default tersebut.
const kMainLedgerId = 'ledger-main';

/// Batas jumlah buku kas aktif (termasuk Buku Utama; yang diarsipkan tidak dihitung).
const kMaxLedgers = 5;

/// Buku kas: wadah pembukuan terpisah (mis. pribadi vs bisnis) untuk pengguna
/// Ultimate. Dompet, kategori, target, agenda, dan utang/piutang menunjuk ke
/// sini lewat `ledgerId`; transaksi, aturan berulang, anggaran, dan setoran
/// target mengikuti induknya (dompet/kategori/target) tanpa kolom sendiri.
class Ledgers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get icon => text().withDefault(const Constant('savings'))();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get kind => intEnum<AccountKind>()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Buku kas pemilik dompet ini. Sengaja tanpa foreign key ke [Ledgers]:
  /// SQLite menolak `ALTER TABLE ADD COLUMN ... REFERENCES` berdefault
  /// non-NULL saat foreign key aktif, jadi kolom ini tidak bisa ditambahkan
  /// lewat migrasi kalau diberi referensi. Integritasnya dijaga di kode
  /// (lihat `AppDatabase._ledgerOfAccounts`) dan `BackupService`.
  TextColumn get ledgerId =>
      text().withDefault(const Constant('ledger-main'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get type => intEnum<TxType>()();
  TextColumn get icon => text().withDefault(const Constant('other'))();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Buku kas pemilik kategori ini (tanpa foreign key, lihat [Accounts.ledgerId]).
  /// Sub-kategori selalu satu buku dengan induknya.
  TextColumn get ledgerId =>
      text().withDefault(const Constant('ledger-main'))();

  /// Kategori induk (satu tingkat saja: sub-kategori tidak boleh punya
  /// sub-kategori lagi). Null = kategori tingkat atas.
  // ignore: recursive_getters
  TextColumn get parentId => text().nullable().references(Categories, #id)();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Label bebas yang bisa ditempelkan ke beberapa transaksi sekaligus.
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabel penghubung banyak-ke-banyak transaksi <-> tag.
class TransactionTags extends Table {
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

@DataClassName('TxEntry')
@TableIndex(name: 'idx_tx_date', columns: {#date})
class Transactions extends Table {
  TextColumn get id => text()();
  IntColumn get type => intEnum<TxType>()();

  /// Nominal dalam Rupiah utuh, selalu positif. Arah ditentukan oleh [type].
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  @ReferenceName('incomingTransfers')
  TextColumn get transferToAccountId =>
      text().nullable().references(Accounts, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete, agar kelak bisa disinkronkan dan dibatalkan.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Aturan berulang asal transaksi ini (null = dicatat manual). Sengaja tanpa
  /// foreign key: aturan boleh dihapus tanpa menyentuh transaksi yang sudah ada.
  TextColumn get recurringId => text().nullable()();

  /// Agenda asal transaksi ini (null = dicatat manual atau dari transaksi
  /// berulang). Sama alasannya dengan [recurringId]: tanpa foreign key, agenda
  /// boleh dihapus tanpa menyentuh transaksi yang sudah tercatat.
  TextColumn get agendaId => text().nullable()();

  /// Path relatif (bukan absolut) ke foto struk tersimpan lokal, fitur
  /// Premium (lihat docs/RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md). Null = tidak
  /// ada foto. Relatif supaya tidak rusak kalau direktori app berubah antar
  /// versi Android/perangkat — path absolut digabung ulang saat dibaca.
  TextColumn get receiptPath => text().nullable()();

  /// Utang/piutang asal transaksi ini (null = tidak terkait), fitur Premium
  /// (lihat docs/RENCANA-IMPLEMENTASI-UTANG-PIUTANG.md). Sama alasannya
  /// dengan [agendaId]: tanpa foreign key, baris utang/piutang boleh dihapus
  /// tanpa menyentuh transaksi pembayaran yang sudah tercatat.
  TextColumn get debtId => text().nullable()();

  /// Tabungan asal/tujuan transaksi ini (null = bukan transaksi tabungan).
  /// Setoran ke tabungan = pengeluaran dari dompet, penarikan = pemasukan ke
  /// dompet; saldo tabungan diturunkan dari baris-baris ini (lihat
  /// [AppDatabase.watchSavings]). Tanpa foreign key, alasannya sama dengan
  /// [debtId].
  TextColumn get savingsId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Aturan transaksi berulang. Transaksi nyata dibuat dari aturan ini oleh
/// [AppDatabase.generateDueRecurring].
class RecurringRules extends Table {
  TextColumn get id => text()();
  IntColumn get type => intEnum<TxType>()();
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  @ReferenceName('incomingRecurringTransfers')
  TextColumn get transferToAccountId =>
      text().nullable().references(Accounts, #id)();
  TextColumn get note => text().nullable()();
  IntColumn get frequency => intEnum<Frequency>()();

  /// Jangkar jadwal (hanya tanggal). Tidak diubah setelah dibuat.
  DateTimeColumn get startDate => dateTime()();

  /// Indeks kejadian berikutnya yang belum dicatat; tanggalnya dihitung dari
  /// [startDate] lewat `occurrenceAt`.
  IntColumn get nextIndex => integer().withDefault(const Constant(0))();

  /// Kejadian setelah tanggal ini tidak dibuat lagi (inklusif). Null = selamanya.
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Pengingat sebelum jatuh tempo (fitur premium). Nonaktif secara bawaan
  /// — reminder itu opt-in per aturan, bukan otomatis untuk semua.
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get reminderDaysBefore =>
      integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pengingat pribadi TIDAK terkait transaksi (servis kendaraan, servis AC,
/// biaya pendidikan, dll — fitur premium). Field jadwal sengaja identik
/// [RecurringRules] agar bisa memakai `occurrenceAt()`/`scheduleDescription()`
/// yang sama, tanpa kolom finansial (type/amount/account/category).
class AgendaReminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 60)();
  TextColumn get note => text().nullable()();
  IntColumn get frequency => intEnum<Frequency>()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get nextIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get reminderDaysBefore =>
      integer().withDefault(const Constant(1))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Estimasi biaya (opsional) — nilai AWAL untuk nominal transaksi saat
  /// dieksekusi ([AppDatabase.executeAgenda]), TIDAK mengunci nominal
  /// sungguhan, cuma prefill yang boleh diubah pengguna.
  IntColumn get estimatedAmount =>
      // ignore: recursive_getters
      integer().nullable().check(estimatedAmount.isBiggerThanValue(0))();

  /// Buku kas pemilik (tanpa foreign key, lihat [Accounts.ledgerId]).
  TextColumn get ledgerId =>
      text().withDefault(const Constant('ledger-main'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Utang (pengguna berutang ke orang lain) atau piutang (orang lain berutang
/// ke pengguna), fitur Premium — lihat docs/RENCANA-IMPLEMENTASI-UTANG-PIUTANG.md.
/// Hard delete (pola sama [AgendaReminders]/[RecurringRules], bukan soft-delete
/// pola lama [Transactions]/[GoalContributions]).
@DataClassName('Debt')
class Debts extends Table {
  TextColumn get id => text()();
  IntColumn get type => intEnum<DebtType>()();
  TextColumn get counterpartyName => text().withLength(min: 1, max: 60)();

  /// Pokok utang/piutang, selalu positif.
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();

  /// Total sudah dibayar/diterima berjalan — naik lewat
  /// [AppDatabase.recordDebtPayment], TIDAK ada kolom "lunas" terpisah
  /// (status diturunkan dari `paidAmount >= amount`, lihat [DebtView],
  /// menghindari dua sumber kebenaran yang bisa tidak sinkron).
  IntColumn get paidAmount => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// Dompet default saat "Catat pembayaran" — opsional, boleh dipilih ulang
  /// saat itu juga. Tanpa foreign key: dompet boleh dihapus/diarsipkan tanpa
  /// menyentuh baris ini (pola sama kolom nullable lain di app ini).
  TextColumn get accountId => text().nullable()();

  /// Buku kas pemilik (tanpa foreign key, lihat [Accounts.ledgerId]).
  TextColumn get ledgerId =>
      text().withDefault(const Constant('ledger-main'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Anggaran bulanan per kategori pengeluaran (satu baris per kategori).
class Budgets extends Table {
  TextColumn get categoryId => text().references(Categories, #id)();
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {categoryId};
}

/// Target tabungan: penanda dana yang disisihkan, TIDAK terhubung ke saldo
/// dompet (lihat [GoalContributions]).
class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get targetAmount =>
      // ignore: recursive_getters
      integer().check(targetAmount.isBiggerThanValue(0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get icon => text().withDefault(const Constant('savings'))();
  IntColumn get color => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Buku kas pemilik (tanpa foreign key, lihat [Accounts.ledgerId]).
  TextColumn get ledgerId =>
      text().withDefault(const Constant('ledger-main'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Setoran/penarikan pada sebuah target. Dana terkumpul = setoran - penarikan
/// (yang belum dihapus). Tidak memengaruhi saldo dompet, laporan, atau anggaran.
class GoalContributions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text().references(SavingsGoals, #id)();
  IntColumn get kind => intEnum<ContributionKind>()();

  /// Selalu positif; arah ditentukan oleh [kind].
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabungan: saldo terpisah dari dompet. Tidak punya kolom saldo — saldonya
/// adalah setoran dikurangi penarikan, yaitu transaksi dompet yang bertanda
/// `savingsId` ini (satu sumber kebenaran, tidak bisa tidak sinkron dengan
/// pembukuan dompet). Beda dengan [SavingsGoals] yang hanya penanda dana.
class SavingsAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get icon => text().withDefault(const Constant('savings'))();
  IntColumn get color => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Buku kas pemilik (tanpa foreign key, lihat [Accounts.ledgerId]).
  TextColumn get ledgerId =>
      text().withDefault(const Constant('ledger-main'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class AccountBalance {
  const AccountBalance({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.initialBalance,
    required this.archived,
  });
  final String id;
  final String name;
  final AccountKind kind;
  final int balance;
  final int initialBalance;
  final bool archived;
}

/// Kesalahan validasi dompet dengan pesan yang siap ditampilkan.
class AccountException implements Exception {
  const AccountException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TxView {
  const TxView({
    required this.tx,
    required this.account,
    this.category,
    this.transferTo,
  });
  final TxEntry tx;
  final Account account;
  final Category? category;
  final Account? transferTo;
}

class RuleView {
  const RuleView({
    required this.rule,
    required this.account,
    this.category,
    this.transferTo,
  });
  final RecurringRule rule;
  final Account account;
  final Category? category;
  final Account? transferTo;

  DateTime get nextDue =>
      occurrenceAt(rule.startDate, rule.frequency, rule.nextIndex);

  /// Sudah melewati tanggal akhir: tidak akan menghasilkan transaksi lagi.
  bool get finished => rule.endDate != null && nextDue.isAfter(rule.endDate!);
}

class AgendaView {
  const AgendaView(this.item);
  final AgendaReminder item;

  DateTime get nextDue =>
      occurrenceAt(item.startDate, item.frequency, item.nextIndex);

  /// Untuk agenda berulang: sudah melewati tanggal akhir. Untuk agenda sekali
  /// ([Frequency.once]): sudah dieksekusi ATAU tanggalnya sudah lewat tanpa
  /// dieksekusi (lihat [AppDatabase.advancePastAgenda]) — ditandai lewat
  /// `nextIndex > 0` karena kejadian tunggalnya cuma index 0.
  bool get finished => item.frequency == Frequency.once
      ? item.nextIndex > 0
      : item.endDate != null && nextDue.isAfter(item.endDate!);
}

class DebtView {
  const DebtView(this.item);
  final Debt item;

  /// Bisa negatif kalau pembayaran melebihi pokok (edge case yang sengaja
  /// tidak diblokir — dianggap lunas, bukan error) — lihat [settled].
  int get remaining => item.amount - item.paidAmount;
  bool get settled => item.paidAmount >= item.amount;
}

class GoalView {
  const GoalView({required this.goal, required this.saved});
  final SavingsGoal goal;

  /// Dana terkumpul: setoran dikurangi penarikan.
  final int saved;

  int get target => goal.targetAmount;
  bool get reached => saved >= target;
  int get remaining => reached ? 0 : target - saved;

  /// 0..1 untuk progress bar (dipotong di 1 walau melebihi target).
  double get fraction => (saved / target).clamp(0.0, 1.0);
}

/// Kesalahan validasi target tabungan dengan pesan yang siap ditampilkan.
class GoalException implements Exception {
  const GoalException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Ringkasan dampak berakhirnya uji coba Ultimate (lihat [AppDatabase.trialImpact]).
class TrialImpact {
  const TrialImpact({
    required this.extraLedgers,
    required this.pausedRules,
    required this.savingsCount,
    required this.savingsTotal,
  });

  static const none = TrialImpact(
    extraLedgers: 0,
    pausedRules: 0,
    savingsCount: 0,
    savingsTotal: 0,
  );

  final int extraLedgers;
  final int pausedRules;
  final int savingsCount;
  final int savingsTotal;
}

class SavingsView {
  const SavingsView({
    required this.savings,
    required this.deposited,
    required this.withdrawn,
  });
  final SavingsAccount savings;
  final int deposited;
  final int withdrawn;

  /// Saldo tabungan: setoran dikurangi penarikan.
  int get balance => deposited - withdrawn;
}

/// Kesalahan validasi tabungan dengan pesan yang siap ditampilkan.
class SavingsException implements Exception {
  const SavingsException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.total,
  });
  final String categoryId;
  final String name;
  final String icon;
  final int color;
  final int total;
}

class BudgetProgress {
  const BudgetProgress({
    required this.category,
    required this.spent,
    this.budget,
  });
  final Category category;
  final int spent;
  final int? budget;
}

/// Pemasukan/pengeluaran satu bulan, untuk grafik tren beberapa bulan.
/// Bulan tanpa transaksi tetap muncul dengan nilai 0 (bukan hilang).
class MonthlyTotal {
  const MonthlyTotal({
    required this.month,
    required this.income,
    required this.expense,
  });

  /// Tanggal 1 bulan itu.
  final DateTime month;
  final int income;
  final int expense;
}

/// Pengeluaran satu kategori pada satu bulan, untuk grafik tren per kategori
/// (fitur premium). Bulan tanpa transaksi kategori itu tidak muncul (beda
/// dari [MonthlyTotal] yang selalu mengisi 0) — pivot per kategori dikerjakan
/// di sisi pemanggil (`lib/features/trends/trend_page.dart`).
class CategoryMonthlyTotal {
  const CategoryMonthlyTotal({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.month,
    required this.total,
  });
  final String categoryId;
  final String categoryName;
  final String icon;
  final int color;

  /// Tanggal 1 bulan itu.
  final DateTime month;
  final int total;
}

typedef MonthTotals = ({int income, int expense});

/// Kesalahan validasi kategori dengan pesan yang siap ditampilkan.
class CategoryException implements Exception {
  const CategoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CategoryUsage {
  const CategoryUsage({
    required this.transactions,
    required this.activeRules,
    required this.hasBudget,
  });
  final int transactions;
  final int activeRules;
  final bool hasBudget;
}

/// Kesalahan validasi tag dengan pesan yang siap ditampilkan.
class TagException implements Exception {
  const TagException(this.message);
  final String message;

  @override
  String toString() => message;
}

const _uuid = Uuid();

const _mainLedgerName = 'Buku Utama';
const _mainLedgerColor = 0xFF1E88E5;

/// Kesalahan validasi buku kas dengan pesan yang siap ditampilkan.
class LedgerException implements Exception {
  const LedgerException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// ID baris seed (kategori/dompet bawaan) di sebuah buku. Buku Utama
/// mempertahankan ID lama (`cat-exp-makan`, `acc-tunai`, ...) supaya data dan
/// kode lama tetap berlaku; buku lain diberi awalan buku agar ID unik global.
String ledgerSeedId(String ledgerId, String base) =>
    ledgerId == kMainLedgerId ? base : '$ledgerId:$base';

/// ID kategori bawaan untuk pembayaran utang/piutang di sebuah buku
/// (dipakai `recordDebtPayment` dan form pembayaran).
String debtCategoryId(String ledgerId, DebtType type) => ledgerSeedId(
  ledgerId,
  type == DebtType.debt ? 'cat-exp-utang' : 'cat-inc-piutang',
);

/// Baris seed kategori: (kunci, nama, ikon, warna).
typedef _SeedCategory = (String, String, String, int);

const _personalExpense = <_SeedCategory>[
  ('makan', 'Makanan & Minuman', 'food', 0xFFEF6C00),
  ('transport', 'Transportasi', 'transport', 0xFF1E88E5),
  ('belanja', 'Belanja', 'shopping', 0xFF8E24AA),
  ('tagihan', 'Tagihan & Utilitas', 'bills', 0xFF00897B),
  ('rumah', 'Tempat Tinggal', 'home', 0xFF6D4C41),
  ('kesehatan', 'Kesehatan', 'health', 0xFFE53935),
  ('pendidikan', 'Pendidikan', 'education', 0xFF3949AB),
  ('hiburan', 'Hiburan', 'fun', 0xFFD81B60),
  ('sedekah', 'Sedekah & Donasi', 'charity', 0xFF43A047),
  ('cicilan', 'Cicilan', 'installment', 0xFF546E7A),
  ('lain-keluar', 'Lainnya', 'other', 0xFF757575),
  ('utang', 'Utang', 'debt', 0xFF795548),
];

const _personalIncome = <_SeedCategory>[
  ('gaji', 'Gaji', 'salary', 0xFF2E7D32),
  ('bonus', 'Bonus / THR', 'bonus', 0xFF00ACC1),
  ('usaha', 'Usaha', 'business', 0xFFF9A825),
  ('hadiah', 'Hadiah', 'gift', 0xFFAD1457),
  ('lain-masuk', 'Lainnya', 'other', 0xFF757575),
  ('piutang', 'Piutang', 'debt', 0xFF26A69A),
];

const _businessExpense = <_SeedCategory>[
  ('stok', 'Pembelian Stok / Bahan Baku', 'shopping', 0xFF8E24AA),
  ('gaji-karyawan', 'Gaji Karyawan', 'salary', 0xFF3949AB),
  ('sewa', 'Sewa Tempat', 'home', 0xFF6D4C41),
  ('utilitas', 'Listrik, Air & Internet', 'bills', 0xFF00897B),
  ('ongkir', 'Ongkir & Transportasi', 'transport', 0xFF1E88E5),
  ('pemasaran', 'Pemasaran & Iklan', 'phone', 0xFFEF6C00),
  ('peralatan', 'Peralatan', 'electronics', 0xFF546E7A),
  ('pajak', 'Pajak & Perizinan', 'tax', 0xFFE53935),
  ('cicilan-usaha', 'Cicilan Usaha', 'installment', 0xFF5D4037),
  ('lain-keluar', 'Lainnya', 'other', 0xFF757575),
  ('utang', 'Utang', 'debt', 0xFF795548),
];

const _businessIncome = <_SeedCategory>[
  ('penjualan', 'Penjualan', 'business', 0xFF2E7D32),
  ('jasa', 'Jasa', 'bonus', 0xFF00ACC1),
  ('modal', 'Modal Masuk', 'investment', 0xFFF9A825),
  ('pendapatan-lain', 'Pendapatan Lain', 'gift', 0xFFAD1457),
  ('lain-masuk', 'Lainnya', 'other', 0xFF757575),
  ('piutang', 'Piutang', 'debt', 0xFF26A69A),
];

const _blankExpense = <_SeedCategory>[
  ('lain-keluar', 'Lainnya', 'other', 0xFF757575),
  ('utang', 'Utang', 'debt', 0xFF795548),
];

const _blankIncome = <_SeedCategory>[
  ('lain-masuk', 'Lainnya', 'other', 0xFF757575),
  ('piutang', 'Piutang', 'debt', 0xFF26A69A),
];

@DriftDatabase(
  tables: [
    Ledgers,
    Accounts,
    Categories,
    Transactions,
    Budgets,
    RecurringRules,
    AgendaReminders,
    Debts,
    SavingsGoals,
    GoalContributions,
    SavingsAccounts,
    Tags,
    TransactionTags,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'dompet_pintar'));

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seed();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(recurringRules);
        await m.addColumn(transactions, transactions.recurringId);
      }
      if (from < 3) {
        await m.createTable(savingsGoals);
        await m.createTable(goalContributions);
      }
      if (from < 4) {
        await m.addColumn(categories, categories.parentId);
        await m.createTable(tags);
        await m.createTable(transactionTags);
      }
      if (from < 5) {
        // Kalau `recurringRules` baru dibuat di step from<2 di atas (migrasi
        // dari v1), createTable() sudah memakai definisi kolom TERKINI
        // (termasuk reminderEnabled/reminderDaysBefore) — addColumn kedua
        // kalinya di sini akan gagal "duplicate column". Hanya jalankan
        // addColumn kalau tabelnya sudah ada SEBELUM migrasi v1->v2 ini.
        if (from >= 2) {
          await m.addColumn(recurringRules, recurringRules.reminderEnabled);
          await m.addColumn(recurringRules, recurringRules.reminderDaysBefore);
        }
        await m.createTable(agendaReminders);
      }
      if (from < 6) {
        // agendaReminders bisa saja baru dibuat di step from<5 di atas
        // dengan definisi TERKINI (sudah termasuk estimatedAmount) kalau
        // migrasi mulai dari v4 ke bawah — addColumn kedua kalinya akan
        // gagal "duplicate column". Sama gotcha dengan recurringRules di
        // atas: hanya jalankan kalau tabelnya sudah ada SEBELUM migrasi ini.
        if (from >= 5) {
          await m.addColumn(agendaReminders, agendaReminders.estimatedAmount);
        }
        await m.addColumn(transactions, transactions.agendaId);
      }
      if (from < 7) {
        await m.addColumn(transactions, transactions.receiptPath);
      }
      if (from < 8) {
        await m.createTable(debts);
        await m.addColumn(transactions, transactions.debtId);
      }
      if (from < 9) {
        // Kategori "Utang"/"Piutang" baru supaya pembayaran utang/piutang
        // mudah dilacak terpisah dari kategori pengeluaran/pemasukan biasa
        // (lihat recordDebtPayment). insertOrIgnore: aman diulang, dan tidak
        // menimpa kalau pengguna kebetulan sudah punya id yang sama.
        final now = DateTime.now();
        await into(categories).insert(
          CategoriesCompanion.insert(
            id: 'cat-exp-utang',
            name: 'Utang',
            type: TxType.expense,
            icon: const Value('debt'),
            color: 0xFF795548,
            sortOrder: const Value(11),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
        await into(categories).insert(
          CategoriesCompanion.insert(
            id: 'cat-inc-piutang',
            name: 'Piutang',
            type: TxType.income,
            icon: const Value('debt'),
            color: 0xFF26A69A,
            sortOrder: const Value(5),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      if (from < 10) {
        // Multi buku kas. Tabel `ledgers` dibuat dulu dan Buku Utama disisipkan,
        // lalu kolom `ledgerId` (default Buku Utama) ditambahkan sehingga semua
        // data lama otomatis masuk ke sana.
        //
        // Gotcha yang sama dengan langkah v5/v6: tabel yang baru DIBUAT di
        // langkah lebih awal dalam migrasi yang sama sudah memakai definisi
        // TERKINI (sudah punya `ledgerId`), jadi addColumn kedua kalinya gagal
        // "duplicate column". `accounts` dan `categories` ada sejak v1; sisanya
        // hanya kalau sudah ada SEBELUM migrasi ini berjalan.
        await m.createTable(ledgers);
        final now = DateTime.now();
        await into(ledgers).insert(
          LedgersCompanion.insert(
            id: kMainLedgerId,
            name: _mainLedgerName,
            color: _mainLedgerColor,
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
        await m.addColumn(accounts, accounts.ledgerId);
        await m.addColumn(categories, categories.ledgerId);
        if (from >= 3) await m.addColumn(savingsGoals, savingsGoals.ledgerId);
        if (from >= 5) {
          await m.addColumn(agendaReminders, agendaReminders.ledgerId);
        }
        if (from >= 8) await m.addColumn(debts, debts.ledgerId);
      }
      if (from < 11) {
        // Tabungan berdompet. `transactions` ada sejak v1, jadi addColumn aman.
        await m.createTable(savingsAccounts);
        await m.addColumn(transactions, transactions.savingsId);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static DateTime monthStart(DateTime m) => DateTime(m.year, m.month);
  static DateTime monthEnd(DateTime m) => DateTime(m.year, m.month + 1);

  // ---------------------------------------------------------------- seed

  /// Kondisi "baru terpasang": Buku Utama dengan kategori pribadi + dompet Tunai.
  Future<void> _seed() async {
    final now = DateTime.now();
    await into(ledgers).insert(
      LedgersCompanion.insert(
        id: kMainLedgerId,
        name: _mainLedgerName,
        color: _mainLedgerColor,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _seedLedgerContent(kMainLedgerId, LedgerTemplate.personal, now: now);
  }

  /// Mengisi kategori dan satu dompet awal untuk buku [ledgerId] sesuai
  /// [template]. Semua template memuat kategori Utang/Piutang karena
  /// [recordDebtPayment] bergantung padanya.
  Future<void> _seedLedgerContent(
    String ledgerId,
    LedgerTemplate template, {
    required DateTime now,
  }) async {
    final (expense, income, accountName) = switch (template) {
      LedgerTemplate.personal => (_personalExpense, _personalIncome, 'Tunai'),
      LedgerTemplate.business => (
        _businessExpense,
        _businessIncome,
        'Kas Usaha',
      ),
      LedgerTemplate.blank => (_blankExpense, _blankIncome, 'Tunai'),
    };

    await batch((b) {
      b.insertAll(categories, [
        for (final (i, c) in expense.indexed)
          CategoriesCompanion.insert(
            id: ledgerSeedId(ledgerId, 'cat-exp-${c.$1}'),
            name: c.$2,
            type: TxType.expense,
            icon: Value(c.$3),
            color: c.$4,
            sortOrder: Value(i),
            ledgerId: Value(ledgerId),
            updatedAt: now,
          ),
        for (final (i, c) in income.indexed)
          CategoriesCompanion.insert(
            id: ledgerSeedId(ledgerId, 'cat-inc-${c.$1}'),
            name: c.$2,
            type: TxType.income,
            icon: Value(c.$3),
            color: c.$4,
            sortOrder: Value(i),
            ledgerId: Value(ledgerId),
            updatedAt: now,
          ),
      ]);
      b.insert(
        accounts,
        AccountsCompanion.insert(
          id: ledgerSeedId(ledgerId, 'acc-tunai'),
          name: accountName,
          kind: AccountKind.cash,
          ledgerId: Value(ledgerId),
          updatedAt: now,
        ),
      );
    });
  }

  // ------------------------------------------------------------ accounts

  /// Saldo dompet. Yang diarsipkan disembunyikan (dan tidak ikut Total Saldo)
  /// kecuali [includeArchived]; bila ikut, ia berada di urutan paling bawah.
  ///
  /// [ledgerId] membatasi ke satu buku kas (bawaan: Buku Utama); null = semua buku.
  Stream<List<AccountBalance>> watchAccountBalances({
    bool includeArchived = false,
    String? ledgerId = kMainLedgerId,
  }) {
    final conditions = [
      if (!includeArchived) 'a.archived = 0',
      if (ledgerId != null) 'a.ledger_id = ?',
    ];
    return customSelect(
      '''
      SELECT a.id, a.name, a.kind, a.archived, a.initial_balance,
        a.initial_balance
        + COALESCE((SELECT SUM(CASE t.type WHEN 0 THEN t.amount ELSE -t.amount END)
                    FROM transactions t
                    WHERE t.account_id = a.id AND t.deleted_at IS NULL), 0)
        + COALESCE((SELECT SUM(t.amount) FROM transactions t
                    WHERE t.transfer_to_account_id = a.id AND t.type = 2
                      AND t.deleted_at IS NULL), 0) AS balance
      FROM accounts a
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ORDER BY a.archived, a.name COLLATE NOCASE
      ''',
      variables: [if (ledgerId != null) Variable.withString(ledgerId)],
      readsFrom: {accounts, transactions},
    ).watch().map(
      (rows) => [
        for (final r in rows)
          AccountBalance(
            id: r.read<String>('id'),
            name: r.read<String>('name'),
            kind: AccountKind.values[r.read<int>('kind')],
            balance: r.read<int>('balance'),
            initialBalance: r.read<int>('initial_balance'),
            archived: r.read<bool>('archived'),
          ),
      ],
    );
  }

  static const maxAccountBalance =
      999999999999; // 12 digit, seperti input Rupiah

  static String _cleanAccountName(String name) {
    final n = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.isEmpty) throw const AccountException('Nama dompet wajib diisi.');
    if (n.length > 60) {
      throw const AccountException('Nama dompet maksimal 60 karakter.');
    }
    return n;
  }

  static void _checkInitialBalance(int v) {
    if (v < 0 || v > maxAccountBalance) {
      throw const AccountException('Saldo awal tidak valid.');
    }
  }

  /// Nama harus unik di dalam satu buku (tanpa membedakan huruf besar/kecil),
  /// termasuk terhadap dompet yang diarsipkan, agar tidak membingungkan saat
  /// dipulihkan.
  Future<void> _ensureAccountNameFree(
    String name,
    String ledgerId, {
    String? exceptId,
  }) async {
    final clash =
        (await (select(
          accounts,
        )..where((a) => a.ledgerId.equals(ledgerId))).get()).where(
          (a) => a.id != exceptId && a.name.toLowerCase() == name.toLowerCase(),
        );
    if (clash.isNotEmpty) {
      throw AccountException(
        clash.first.archived
            ? 'Sudah ada dompet "$name" yang diarsipkan. Pulihkan saja dompet itu.'
            : 'Sudah ada dompet "$name".',
      );
    }
  }

  Future<void> addAccount({
    required String name,
    required AccountKind kind,
    int initialBalance = 0,
    String ledgerId = kMainLedgerId,
  }) async {
    final clean = _cleanAccountName(name);
    _checkInitialBalance(initialBalance);
    await transaction(() async {
      await _requireLedger(ledgerId);
      await _ensureAccountNameFree(clean, ledgerId);
      await into(accounts).insert(
        AccountsCompanion.insert(
          id: _uuid.v7(),
          name: clean,
          kind: kind,
          initialBalance: Value(initialBalance),
          ledgerId: Value(ledgerId),
          updatedAt: DateTime.now(),
        ),
      );
    });
  }

  /// Apakah dompet [id] punya transaksi aktif, baik sebagai dompet asal maupun
  /// tujuan transfer. Dompet seperti ini saldo awalnya dikunci
  /// ([updateAccount]); penyesuaian lewat [adjustAccountBalance].
  Future<bool> accountHasTransactions(String id) async {
    final count =
        await (selectOnly(transactions)
              ..addColumns([transactions.id.count()])
              ..where(
                transactions.deletedAt.isNull() &
                    (transactions.accountId.equals(id) |
                        transactions.transferToAccountId.equals(id)),
              ))
            .map((r) => r.read(transactions.id.count()) ?? 0)
            .getSingle();
    return count > 0;
  }

  Future<int> _accountBalanceOf(String id) async {
    final row = await customSelect(
      '''
      SELECT a.initial_balance
        + COALESCE((SELECT SUM(CASE t.type WHEN 0 THEN t.amount ELSE -t.amount END)
                    FROM transactions t
                    WHERE t.account_id = a.id AND t.deleted_at IS NULL), 0)
        + COALESCE((SELECT SUM(t.amount) FROM transactions t
                    WHERE t.transfer_to_account_id = a.id AND t.type = 2
                      AND t.deleted_at IS NULL), 0) AS balance
      FROM accounts a WHERE a.id = ?
      ''',
      variables: [Variable.withString(id)],
      readsFrom: {accounts, transactions},
    ).getSingleOrNull();
    if (row == null) throw StateError('Dompet $id tidak ditemukan.');
    return row.read<int>('balance');
  }

  /// Menyesuaikan saldo dompet [accountId] menjadi [actualBalance] dengan
  /// mencatat satu transaksi selisih (pemasukan bila saldo aktual lebih besar,
  /// pengeluaran bila lebih kecil) berkategori "Penyesuaian Saldo". Riwayat
  /// tetap utuh dan selisihnya terlihat jelas. Mengembalikan selisih bertanda
  /// (positif = pemasukan, negatif = pengeluaran).
  Future<int> adjustAccountBalance({
    required String accountId,
    required int actualBalance,
    DateTime? date,
    String? note,
  }) async {
    if (actualBalance < 0 || actualBalance > maxAccountBalance) {
      throw const AccountException('Saldo aktual tidak valid.');
    }
    return transaction(() async {
      final account = await (select(
        accounts,
      )..where((a) => a.id.equals(accountId))).getSingleOrNull();
      if (account == null) {
        throw StateError('Dompet $accountId tidak ditemukan.');
      }
      if (account.archived) {
        throw const AccountException(
          'Dompet ini diarsipkan. Pulihkan dulu untuk menyesuaikan saldo.',
        );
      }
      await _requireLedger(account.ledgerId);
      final diff = actualBalance - await _accountBalanceOf(accountId);
      if (diff == 0) {
        throw const AccountException('Saldo sudah sama dengan saldo aktual.');
      }
      final type = diff > 0 ? TxType.income : TxType.expense;
      final categoryId = await _adjustmentCategoryId(account.ledgerId, type);
      final now = DateTime.now();
      final trimmed = note?.trim();
      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: _uuid.v7(),
          type: type,
          amount: diff.abs(),
          accountId: accountId,
          categoryId: Value(categoryId),
          date: date ?? now,
          note: Value(
            trimmed == null || trimmed.isEmpty ? 'Penyesuaian saldo' : trimmed,
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return diff;
    });
  }

  /// Mengubah nama, jenis, dan saldo awal. Saldo dompet = saldo awal +
  /// transaksi, jadi saldo awal TIDAK boleh diubah setelah dompet punya
  /// transaksi (pengguna yang mengetik saldo aktual akan mendapat angka yang
  /// meleset); gunakan [adjustAccountBalance].
  Future<void> updateAccount({
    required String id,
    required String name,
    required AccountKind kind,
    required int initialBalance,
  }) async {
    final clean = _cleanAccountName(name);
    _checkInitialBalance(initialBalance);
    await transaction(() async {
      final current = await (select(
        accounts,
      )..where((a) => a.id.equals(id))).getSingleOrNull();
      if (current == null) throw StateError('Dompet $id tidak ditemukan.');
      if (initialBalance != current.initialBalance &&
          await accountHasTransactions(id)) {
        throw const AccountException(
          'Saldo awal tidak bisa diubah karena dompet ini sudah punya '
          'transaksi. Gunakan "Sesuaikan saldo".',
        );
      }
      await _ensureAccountNameFree(clean, current.ledgerId, exceptId: id);
      final rows = await (update(accounts)..where((a) => a.id.equals(id)))
          .write(
            AccountsCompanion(
              name: Value(clean),
              kind: Value(kind),
              initialBalance: Value(initialBalance),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (rows == 0) throw StateError('Dompet $id tidak ditemukan.');
    });
  }

  /// Mengarsipkan menyembunyikan dompet dari pilihan baru dan dari Total Saldo;
  /// riwayat transaksinya tetap ada. Ditolak bila ini dompet aktif terakhir,
  /// atau bila masih dipakai transaksi berulang aktif (yang akan terus mencatat
  /// ke dompet yang tersembunyi).
  Future<void> setAccountArchived(String id, {required bool archived}) async {
    await transaction(() async {
      final current = await (select(
        accounts,
      )..where((a) => a.id.equals(id))).getSingleOrNull();
      if (current == null) throw StateError('Dompet $id tidak ditemukan.');
      if (archived && !current.archived) {
        final active =
            await (select(accounts)..where(
                  (a) =>
                      a.archived.equals(false) &
                      a.ledgerId.equals(current.ledgerId),
                ))
                .get();
        if (active.length <= 1) {
          throw const AccountException('Harus ada minimal satu dompet aktif.');
        }
        final rules =
            await (select(recurringRules)..where(
                  (r) =>
                      r.active.equals(true) &
                      (r.accountId.equals(id) |
                          r.transferToAccountId.equals(id)),
                ))
                .get();
        if (rules.isNotEmpty) {
          throw AccountException(
            'Dompet ini dipakai ${rules.length} transaksi berulang aktif. '
            'Jeda atau ubah dulu dompetnya.',
          );
        }
      }
      await (update(accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(
          archived: Value(archived),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  // ---------------------------------------------------------- categories

  /// Kategori satu jenis. Yang diarsipkan disembunyikan kecuali
  /// [includeArchived] (untuk layar kelola dan untuk mengubah transaksi lama);
  /// bila ikut, ia berada di urutan paling bawah.
  ///
  /// [ledgerId] membatasi ke satu buku kas (bawaan: Buku Utama); null = semua buku.
  Stream<List<Category>> watchCategories(
    TxType type, {
    bool includeArchived = false,
    String? ledgerId = kMainLedgerId,
  }) {
    return (select(categories)
          ..where(
            (c) =>
                c.type.equalsValue(type) &
                (includeArchived
                    ? const Constant(true)
                    : c.archived.equals(false)) &
                (ledgerId == null
                    ? const Constant(true)
                    : c.ledgerId.equals(ledgerId)),
          )
          ..orderBy([
            (c) => OrderingTerm.asc(c.archived),
            (c) => OrderingTerm.asc(c.sortOrder),
          ]))
        .watch();
  }

  static String _cleanCategoryName(String name) {
    final n = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.isEmpty) throw const CategoryException('Nama kategori wajib diisi.');
    if (n.length > 60) {
      throw const CategoryException('Nama kategori maksimal 60 karakter.');
    }
    return n;
  }

  /// Nama harus unik per jenis di dalam satu buku (tanpa membedakan huruf
  /// besar/kecil), termasuk terhadap kategori yang diarsipkan, agar tidak
  /// membingungkan saat dipulihkan.
  Future<void> _ensureNameFree(
    TxType type,
    String name,
    String ledgerId, {
    String? exceptId,
  }) async {
    final same =
        await (select(categories)..where(
              (c) => c.type.equalsValue(type) & c.ledgerId.equals(ledgerId),
            ))
            .get();
    final clash = same.where(
      (c) => c.id != exceptId && c.name.toLowerCase() == name.toLowerCase(),
    );
    if (clash.isNotEmpty) {
      throw CategoryException(
        clash.first.archived
            ? 'Sudah ada kategori "$name" yang diarsipkan. Pulihkan saja kategori itu.'
            : 'Sudah ada kategori "$name".',
      );
    }
  }

  /// Memastikan [parentId] (bila ada) adalah kategori lain, sejenis, dan
  /// bukan sub-kategori itu sendiri (menegakkan sub-kategori satu tingkat).
  Future<void> _checkParent(
    TxType type,
    String? parentId,
    String ledgerId, {
    String? selfId,
  }) async {
    if (parentId == null) return;
    if (parentId == selfId) {
      throw const CategoryException(
        'Kategori tidak bisa menjadi induk dirinya sendiri.',
      );
    }
    final parent = await (select(
      categories,
    )..where((c) => c.id.equals(parentId))).getSingleOrNull();
    if (parent == null) {
      throw const CategoryException('Kategori induk tidak ditemukan.');
    }
    if (parent.ledgerId != ledgerId) {
      throw const CategoryException(
        'Kategori induk harus berada di buku kas yang sama.',
      );
    }
    if (parent.type != type) {
      throw const CategoryException(
        'Kategori induk harus sejenis (pemasukan/pengeluaran).',
      );
    }
    if (parent.parentId != null) {
      throw const CategoryException(
        'Sub-kategori tidak bisa memiliki sub-kategori lagi.',
      );
    }
  }

  Future<String> addCategory({
    required TxType type,
    required String name,
    required String icon,
    required int color,
    String? parentId,
    String ledgerId = kMainLedgerId,
  }) async {
    if (type == TxType.transfer) {
      throw const CategoryException('Transfer tidak memakai kategori.');
    }
    final clean = _cleanCategoryName(name);
    return transaction(() async {
      await _requireLedger(ledgerId);
      await _ensureNameFree(type, clean, ledgerId);
      await _checkParent(type, parentId, ledgerId);
      final last =
          await (select(categories)
                ..where(
                  (c) => c.type.equalsValue(type) & c.ledgerId.equals(ledgerId),
                )
                ..orderBy([(c) => OrderingTerm.desc(c.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      final id = _uuid.v7();
      await into(categories).insert(
        CategoriesCompanion.insert(
          id: id,
          name: clean,
          type: type,
          icon: Value(icon),
          color: color,
          sortOrder: Value((last?.sortOrder ?? -1) + 1),
          parentId: Value(parentId),
          ledgerId: Value(ledgerId),
          updatedAt: DateTime.now(),
        ),
      );
      return id;
    });
  }

  /// Jenis (pemasukan/pengeluaran) sengaja tidak bisa diubah: transaksi dan
  /// anggaran yang sudah ada bergantung padanya.
  Future<void> updateCategory({
    required String id,
    required String name,
    required String icon,
    required int color,
    String? parentId,
  }) async {
    final clean = _cleanCategoryName(name);
    await transaction(() async {
      final current = await (select(
        categories,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (current == null) throw StateError('Kategori $id tidak ditemukan.');
      await _ensureNameFree(
        current.type,
        clean,
        current.ledgerId,
        exceptId: id,
      );
      await _checkParent(current.type, parentId, current.ledgerId, selfId: id);
      if (parentId != null) {
        final children = await (select(
          categories,
        )..where((c) => c.parentId.equals(id))).get();
        if (children.isNotEmpty) {
          throw const CategoryException(
            'Kategori ini punya sub-kategori sendiri, tidak bisa dijadikan '
            'sub-kategori.',
          );
        }
      }
      await (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(clean),
          icon: Value(icon),
          color: Value(color),
          parentId: Value(parentId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Mengarsipkan menyembunyikan kategori dari pilihan baru; transaksi, anggaran,
  /// dan aturan berulang yang memakainya tidak berubah. Kategori aktif terakhir
  /// suatu jenis tidak boleh diarsipkan, begitu juga induk yang masih punya
  /// sub-kategori aktif (arsipkan dulu sub-kategorinya).
  Future<void> setCategoryArchived(String id, {required bool archived}) async {
    await transaction(() async {
      final current = await (select(
        categories,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (current == null) throw StateError('Kategori $id tidak ditemukan.');
      if (archived && !current.archived) {
        final active =
            await (select(categories)..where(
                  (c) =>
                      c.type.equalsValue(current.type) &
                      c.archived.equals(false) &
                      c.ledgerId.equals(current.ledgerId),
                ))
                .get();
        if (active.length <= 1) {
          throw const CategoryException(
            'Harus ada minimal satu kategori aktif untuk jenis ini.',
          );
        }
        final children =
            await (select(categories)..where(
                  (c) => c.parentId.equals(id) & c.archived.equals(false),
                ))
                .get();
        if (children.isNotEmpty) {
          throw CategoryException(
            'Kategori ini masih punya ${children.length} sub-kategori aktif. '
            'Arsipkan dulu sub-kategorinya.',
          );
        }
      }
      await (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          archived: Value(archived),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<CategoryUsage> categoryUsage(String id) async {
    final tx =
        await (selectOnly(transactions)
              ..addColumns([transactions.id.count()])
              ..where(
                transactions.categoryId.equals(id) &
                    transactions.deletedAt.isNull(),
              ))
            .map((r) => r.read(transactions.id.count()) ?? 0)
            .getSingle();
    final rules =
        await (selectOnly(recurringRules)
              ..addColumns([recurringRules.id.count()])
              ..where(
                recurringRules.categoryId.equals(id) &
                    recurringRules.active.equals(true),
              ))
            .map((r) => r.read(recurringRules.id.count()) ?? 0)
            .getSingle();
    final budget = await (select(
      budgets,
    )..where((b) => b.categoryId.equals(id))).getSingleOrNull();
    return CategoryUsage(
      transactions: tx,
      activeRules: rules,
      hasBudget: budget != null,
    );
  }

  // -------------------------------------------------------- transactions

  /// Mengembalikan id transaksi baru (dipakai mis. untuk menandainya dengan tag).
  Future<String> addTransaction({
    required TxType type,
    required int amount,
    required String accountId,
    required DateTime date,
    String? categoryId,
    String? transferToAccountId,
    String? note,
    String? receiptPath,
  }) async {
    assert(amount > 0);
    assert(
      type == TxType.transfer
          ? transferToAccountId != null && transferToAccountId != accountId
          : categoryId != null,
    );
    await _checkSameLedger(
      accountId: accountId,
      categoryId: type == TxType.transfer ? null : categoryId,
      transferToAccountId: type == TxType.transfer ? transferToAccountId : null,
    );
    final now = DateTime.now();
    final trimmed = note?.trim();
    final id = _uuid.v7();
    await into(transactions).insert(
      TransactionsCompanion.insert(
        id: id,
        type: type,
        amount: amount,
        accountId: accountId,
        categoryId: Value(type == TxType.transfer ? null : categoryId),
        transferToAccountId: Value(
          type == TxType.transfer ? transferToAccountId : null,
        ),
        date: date,
        note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
        createdAt: now,
        updatedAt: now,
        receiptPath: Value(receiptPath),
      ),
    );
    return id;
  }

  /// Melepas foto struk dari transaksi (kolom dikosongkan). File fisiknya
  /// dihapus pemanggil lewat `deleteReceiptFile`.
  Future<void> removeTransactionReceipt(String id) {
    return (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        receiptPath: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Semua path foto struk yang masih dirujuk transaksi, TERMASUK yang sudah
  /// dihapus lunak (masih bisa dibatalkan) dan dari semua buku kas.
  Future<Set<String>> allReceiptPaths() async {
    final rows =
        await (selectOnly(transactions)
              ..addColumns([transactions.receiptPath])
              ..where(transactions.receiptPath.isNotNull()))
            .get();
    return {for (final r in rows) ?r.read(transactions.receiptPath)};
  }

  /// Yang akan berubah saat uji coba Ultimate berakhir (semua buku): buku kas
  /// tambahan yang terkunci, transaksi berulang di dalamnya yang dijeda, serta
  /// tabungan berisi saldo yang tinggal bisa ditarik. Untuk dialog tonggak.
  Future<TrialImpact> trialImpact() async {
    final extraLedgers = (await select(
      ledgers,
    ).get()).where((l) => !l.archived && l.id != kMainLedgerId).toList();
    final extraIds = {for (final l in extraLedgers) l.id};
    final rules = (await watchRecurringRules(ledgerId: null).first).where(
      (r) => r.rule.active && extraIds.contains(r.account.ledgerId),
    );
    final savings = (await watchSavings(
      ledgerId: null,
    ).first).where((s) => !s.savings.archived && s.balance > 0).toList();
    return TrialImpact(
      extraLedgers: extraLedgers.length,
      pausedRules: rules.length,
      savingsCount: savings.length,
      savingsTotal: savings.fold(0, (sum, s) => sum + s.balance),
    );
  }

  /// Jumlah transaksi aktif (semua buku). Dipakai untuk menentukan kapan
  /// penawaran uji coba pantas ditampilkan: setelah pengguna sudah mencatat.
  Stream<int> watchActiveTransactionCount() {
    final count = transactions.id.count();
    return (selectOnly(transactions)
          ..addColumns([count])
          ..where(transactions.deletedAt.isNull()))
        .map((r) => r.read(count) ?? 0)
        .watchSingle();
  }

  /// Transaksi tabungan hanya boleh diubah lewat halaman Tabungan
  /// ([setSavingsEntryDeleted]), karena saldo tabungan diturunkan darinya.
  Future<void> _rejectSavingsTx(String id) async {
    final row = await (select(
      transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row?.savingsId != null) {
      throw const SavingsException(
        'Transaksi ini bagian dari tabungan. Ubah lewat halaman Tabungan.',
      );
    }
  }

  Future<void> setTransactionDeleted(String id, {required bool deleted}) async {
    await _rejectSavingsTx(id);
    final now = DateTime.now();
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: Value(deleted ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Mengubah transaksi yang ada. `createdAt`, `recurringId`, dan status hapus
  /// dipertahankan; hanya `updatedAt` yang diperbarui.
  Future<void> updateTransaction({
    required String id,
    required TxType type,
    required int amount,
    required String accountId,
    required DateTime date,
    String? categoryId,
    String? transferToAccountId,
    String? note,
  }) async {
    _checkTxFields(type, amount, accountId, categoryId, transferToAccountId);
    await _rejectSavingsTx(id);
    await _checkSameLedger(
      accountId: accountId,
      categoryId: type == TxType.transfer ? null : categoryId,
      transferToAccountId: type == TxType.transfer ? transferToAccountId : null,
    );
    final trimmed = note?.trim();
    final rows = await (update(transactions)..where((t) => t.id.equals(id)))
        .write(
          TransactionsCompanion(
            type: Value(type),
            amount: Value(amount),
            accountId: Value(accountId),
            categoryId: Value(type == TxType.transfer ? null : categoryId),
            transferToAccountId: Value(
              type == TxType.transfer ? transferToAccountId : null,
            ),
            date: Value(date),
            note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (rows == 0) throw StateError('Transaksi $id tidak ditemukan.');
  }

  static void _checkTxFields(
    TxType type,
    int amount,
    String accountId,
    String? categoryId,
    String? transferToAccountId,
  ) {
    if (amount <= 0) throw ArgumentError('Nominal harus lebih dari 0.');
    if (type == TxType.transfer) {
      if (transferToAccountId == null || transferToAccountId == accountId) {
        throw ArgumentError('Transfer butuh dompet tujuan yang berbeda.');
      }
    } else if (categoryId == null) {
      throw ArgumentError('Kategori wajib diisi.');
    }
  }

  // ---------------------------------------------------- transaksi berulang

  Future<String> addRecurringRule({
    required TxType type,
    required int amount,
    required String accountId,
    required Frequency frequency,
    required DateTime startDate,
    String? categoryId,
    String? transferToAccountId,
    String? note,
    DateTime? endDate,
    bool reminderEnabled = false,
    int reminderDaysBefore = 1,
  }) async {
    _checkTxFields(type, amount, accountId, categoryId, transferToAccountId);
    await _checkSameLedger(
      accountId: accountId,
      categoryId: type == TxType.transfer ? null : categoryId,
      transferToAccountId: type == TxType.transfer ? transferToAccountId : null,
    );
    final now = DateTime.now();
    final id = _uuid.v7();
    final trimmed = note?.trim();
    await into(recurringRules).insert(
      RecurringRulesCompanion.insert(
        id: id,
        type: type,
        amount: amount,
        accountId: accountId,
        categoryId: Value(type == TxType.transfer ? null : categoryId),
        transferToAccountId: Value(
          type == TxType.transfer ? transferToAccountId : null,
        ),
        note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
        frequency: frequency,
        startDate: dateOnly(startDate),
        endDate: Value(endDate == null ? null : dateOnly(endDate)),
        reminderEnabled: Value(reminderEnabled),
        reminderDaysBefore: Value(reminderDaysBefore),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Jadwal (tanggal mulai dan frekuensi) sengaja tidak bisa diubah: mengubah
  /// jangkar akan membuat indeks kejadian yang sudah dicatat tidak bermakna.
  /// Perubahan berlaku untuk transaksi berikutnya, bukan yang sudah tercatat.
  Future<void> updateRecurringRule({
    required String id,
    required TxType type,
    required int amount,
    required String accountId,
    String? categoryId,
    String? transferToAccountId,
    String? note,
    DateTime? endDate,
    bool reminderEnabled = false,
    int reminderDaysBefore = 1,
  }) async {
    _checkTxFields(type, amount, accountId, categoryId, transferToAccountId);
    await _checkSameLedger(
      accountId: accountId,
      categoryId: type == TxType.transfer ? null : categoryId,
      transferToAccountId: type == TxType.transfer ? transferToAccountId : null,
    );
    final trimmed = note?.trim();
    final rows = await (update(recurringRules)..where((r) => r.id.equals(id)))
        .write(
          RecurringRulesCompanion(
            type: Value(type),
            amount: Value(amount),
            accountId: Value(accountId),
            categoryId: Value(type == TxType.transfer ? null : categoryId),
            transferToAccountId: Value(
              type == TxType.transfer ? transferToAccountId : null,
            ),
            note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
            endDate: Value(endDate == null ? null : dateOnly(endDate)),
            reminderEnabled: Value(reminderEnabled),
            reminderDaysBefore: Value(reminderDaysBefore),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (rows == 0) throw StateError('Aturan $id tidak ditemukan.');
  }

  /// Menjeda atau melanjutkan. Saat dilanjutkan, periode yang terlewat selama
  /// dijeda dilewati (tidak dicatat mundur): pengguna menjedanya dengan sengaja.
  Future<void> setRecurringActive(
    String id, {
    required bool active,
    DateTime? now,
  }) async {
    await transaction(() async {
      final rule = await (select(
        recurringRules,
      )..where((r) => r.id.equals(id))).getSingle();
      var nextIndex = rule.nextIndex;
      if (active && !rule.active) {
        final skipTo = firstIndexOnOrAfter(
          rule.startDate,
          rule.frequency,
          now ?? DateTime.now(),
        );
        if (skipTo > nextIndex) nextIndex = skipTo;
      }
      await (update(recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(
          active: Value(active),
          nextIndex: Value(nextIndex),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Menghapus aturan. Transaksi yang sudah dibuat darinya tetap ada.
  Future<void> deleteRecurringRule(String id) =>
      (delete(recurringRules)..where((r) => r.id.equals(id))).go();

  /// [ledgerId] membatasi ke satu buku kas (bawaan: Buku Utama); null = semua buku
  /// (dipakai penjadwal pengingat, yang bekerja lintas buku).
  Stream<List<RuleView>> watchRecurringRules({
    String? ledgerId = kMainLedgerId,
  }) {
    final toAccount = alias(accounts, 'to_acc');
    final query =
        select(recurringRules).join([
            innerJoin(
              accounts,
              accounts.id.equalsExp(recurringRules.accountId),
            ),
            leftOuterJoin(
              categories,
              categories.id.equalsExp(recurringRules.categoryId),
            ),
            leftOuterJoin(
              toAccount,
              toAccount.id.equalsExp(recurringRules.transferToAccountId),
            ),
          ])
          ..where(
            ledgerId == null
                ? const Constant(true)
                : accounts.ledgerId.equals(ledgerId),
          )
          ..orderBy([
            OrderingTerm.desc(recurringRules.active),
            OrderingTerm.asc(recurringRules.createdAt),
          ]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          RuleView(
            rule: r.readTable(recurringRules),
            account: r.readTable(accounts),
            category: r.readTableOrNull(categories),
            transferTo: r.readTableOrNull(toAccount),
          ),
      ],
    );
  }

  /// Membuat transaksi untuk semua kejadian aturan aktif yang sudah jatuh
  /// tempo (tanggal <= hari ini dan <= tanggal akhir). Mengembalikan jumlah
  /// transaksi baru.
  ///
  /// Aman dipanggil berulang: ID transaksi ditentukan oleh (aturan, indeks),
  /// jadi kejadian yang sama tidak pernah tercatat dua kali. Transaksi hasil
  /// generate yang dihapus pengguna juga tidak dibuat ulang, karena indeks aturan
  /// sudah maju.
  ///
  /// Berlaku untuk SEMUA buku kas, bukan hanya yang sedang aktif. Buku di
  /// [pausedLedgerIds] (mis. buku Ultimate yang terkunci) dijeda: aturannya tidak
  /// menghasilkan transaksi diam-diam di buku yang tersembunyi, dan indeksnya
  /// tidak maju, sehingga disusul saat buku terbuka kembali.
  Future<int> generateDueRecurring({
    DateTime? now,
    int maxPerRule = 1000,
    Set<String> pausedLedgerIds = const {},
  }) {
    return transaction(() async {
      final today = dateOnly(now ?? DateTime.now());
      var created = 0;
      final rules = await (select(
        recurringRules,
      )..where((r) => r.active.equals(true))).get();
      final pausedAccountIds = pausedLedgerIds.isEmpty
          ? const <String>{}
          : {
              for (final a in await (select(
                accounts,
              )..where((a) => a.ledgerId.isIn(pausedLedgerIds))).get())
                a.id,
            };

      for (final rule in rules) {
        if (pausedAccountIds.contains(rule.accountId)) continue;
        var index = rule.nextIndex;
        for (var n = 0; n < maxPerRule; n++) {
          final due = occurrenceAt(rule.startDate, rule.frequency, index);
          if (due.isAfter(today)) break;
          if (rule.endDate != null && due.isAfter(rule.endDate!)) break;

          final txId = 'rec-${rule.id}-$index';
          final exists =
              await (select(
                transactions,
              )..where((t) => t.id.equals(txId))).getSingleOrNull() !=
              null;
          if (!exists) {
            final stamp = DateTime.now();
            await into(transactions).insert(
              TransactionsCompanion.insert(
                id: txId,
                type: rule.type,
                amount: rule.amount,
                accountId: rule.accountId,
                categoryId: Value(rule.categoryId),
                transferToAccountId: Value(rule.transferToAccountId),
                date: due,
                note: Value(rule.note),
                createdAt: stamp,
                updatedAt: stamp,
                recurringId: Value(rule.id),
              ),
            );
            created++;
          }
          index++;
        }
        if (index != rule.nextIndex) {
          await (update(
            recurringRules,
          )..where((r) => r.id.equals(rule.id))).write(
            RecurringRulesCompanion(
              nextIndex: Value(index),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
      return created;
    });
  }

  // ------------------------------------------------------- agenda pengingat

  Future<String> addAgenda({
    required String title,
    required Frequency frequency,
    required DateTime startDate,
    String? note,
    DateTime? endDate,
    int reminderDaysBefore = 1,
    int? estimatedAmount,
    String ledgerId = kMainLedgerId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v7();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const AccountException('Judul agenda tidak boleh kosong.');
    }
    if (estimatedAmount != null && estimatedAmount <= 0) {
      throw const AccountException('Estimasi biaya harus lebih dari 0.');
    }
    await _requireLedger(ledgerId);
    final trimmedNote = note?.trim();
    await into(agendaReminders).insert(
      AgendaRemindersCompanion.insert(
        id: id,
        ledgerId: Value(ledgerId),
        title: trimmedTitle,
        note: Value(
          trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
        ),
        frequency: frequency,
        startDate: dateOnly(startDate),
        endDate: Value(endDate == null ? null : dateOnly(endDate)),
        reminderDaysBefore: Value(reminderDaysBefore),
        estimatedAmount: Value(estimatedAmount),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Jadwal (tanggal mulai dan frekuensi) sengaja tidak bisa diubah — sama
  /// alasannya dengan [updateRecurringRule].
  Future<void> updateAgenda({
    required String id,
    required String title,
    String? note,
    DateTime? endDate,
    int reminderDaysBefore = 1,
    int? estimatedAmount,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const AccountException('Judul agenda tidak boleh kosong.');
    }
    if (estimatedAmount != null && estimatedAmount <= 0) {
      throw const AccountException('Estimasi biaya harus lebih dari 0.');
    }
    final trimmedNote = note?.trim();
    final rows = await (update(agendaReminders)..where((a) => a.id.equals(id)))
        .write(
          AgendaRemindersCompanion(
            title: Value(trimmedTitle),
            note: Value(
              trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
            ),
            endDate: Value(endDate == null ? null : dateOnly(endDate)),
            reminderDaysBefore: Value(reminderDaysBefore),
            estimatedAmount: Value(estimatedAmount),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (rows == 0) throw StateError('Agenda $id tidak ditemukan.');
  }

  /// Menandai kejadian agenda [agendaId] sebagai dieksekusi: mencatat satu
  /// transaksi pengeluaran nyata (nominal BEBAS beda dari estimasi) dan
  /// memajukan `nextIndex` satu langkah — beda dari [advancePastAgenda] yang
  /// melompati banyak kejadian sekaligus tanpa transaksi; ini SATU kejadian,
  /// SATU transaksi, dipicu aksi nyata pengguna. `nextIndex + 1` berlaku
  /// seragam untuk agenda berulang maupun [Frequency.once] (untuk `once`,
  /// ini langsung membuat [AgendaView.finished] jadi true).
  Future<String> executeAgenda({
    required String agendaId,
    required int amount,
    required String accountId,
    String? categoryId,
    required DateTime date,
    String? note,
  }) {
    assert(amount > 0);
    return transaction(() async {
      final item = await (select(
        agendaReminders,
      )..where((a) => a.id.equals(agendaId))).getSingle();
      await _checkSameLedger(
        accountId: accountId,
        categoryId: categoryId,
        ledgerId: item.ledgerId,
      );
      final now = DateTime.now();
      final trimmed = note?.trim();
      final txId = _uuid.v7();
      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: txId,
          type: TxType.expense,
          amount: amount,
          accountId: accountId,
          categoryId: Value(categoryId),
          date: date,
          note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
          createdAt: now,
          updatedAt: now,
          agendaId: Value(agendaId),
        ),
      );
      await (update(
        agendaReminders,
      )..where((a) => a.id.equals(agendaId))).write(
        AgendaRemindersCompanion(
          nextIndex: Value(item.nextIndex + 1),
          updatedAt: Value(now),
        ),
      );
      return txId;
    });
  }

  /// Menjeda atau melanjutkan — sama pola [setRecurringActive], termasuk
  /// melewati (bukan mengejar mundur) periode yang terlampaui saat dijeda.
  Future<void> setAgendaActive(
    String id, {
    required bool active,
    DateTime? now,
  }) async {
    await transaction(() async {
      final item = await (select(
        agendaReminders,
      )..where((a) => a.id.equals(id))).getSingle();
      var nextIndex = item.nextIndex;
      if (active && !item.active) {
        final skipTo = firstIndexOnOrAfter(
          item.startDate,
          item.frequency,
          now ?? DateTime.now(),
        );
        if (skipTo > nextIndex) nextIndex = skipTo;
      }
      await (update(agendaReminders)..where((a) => a.id.equals(id))).write(
        AgendaRemindersCompanion(
          active: Value(active),
          nextIndex: Value(nextIndex),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> deleteAgenda(String id) =>
      (delete(agendaReminders)..where((a) => a.id.equals(id))).go();

  /// [ledgerId] membatasi ke satu buku kas (bawaan: Buku Utama); null = semua buku.
  Stream<List<AgendaReminder>> watchAgendaReminders({
    String? ledgerId = kMainLedgerId,
  }) {
    return (select(agendaReminders)
          ..where(
            (a) => ledgerId == null
                ? const Constant(true)
                : a.ledgerId.equals(ledgerId),
          )
          ..orderBy([
            (a) => OrderingTerm.desc(a.active),
            (a) => OrderingTerm.asc(a.createdAt),
          ]))
        .watch();
  }

  /// Memajukan `nextIndex` untuk kejadian yang sudah lewat hari ini, TANPA
  /// membuat transaksi (agenda murni pengingat, beda dari
  /// [generateDueRecurring]) — supaya `nextDue` selalu menunjuk ke kejadian
  /// berikutnya yang belum lewat, bukan tanggal lampau.
  Future<void> advancePastAgenda({DateTime? now}) {
    return transaction(() async {
      final today = dateOnly(now ?? DateTime.now());
      final items = await (select(
        agendaReminders,
      )..where((a) => a.active.equals(true))).get();
      for (final item in items) {
        var index = item.nextIndex;
        if (item.frequency == Frequency.once) {
          // occurrenceAt selalu mengembalikan tanggal KONSTAN untuk `once`,
          // jadi loop di bawah akan hang — cukup satu langkah kalau overdue.
          if (index == 0 && item.startDate.isBefore(today)) index = 1;
        } else {
          while (true) {
            final due = occurrenceAt(item.startDate, item.frequency, index);
            if (!due.isBefore(today)) break;
            if (item.endDate != null && due.isAfter(item.endDate!)) break;
            index++;
          }
        }
        if (index != item.nextIndex) {
          await (update(
            agendaReminders,
          )..where((a) => a.id.equals(item.id))).write(
            AgendaRemindersCompanion(
              nextIndex: Value(index),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
    });
  }

  /// Transaksi aktif (belum dihapus) dalam rentang [from, to), digabung dengan
  /// dompet dan kategorinya. Rentang null berarti tanpa batas.
  ({
    JoinedSelectStatement<HasResultSet, dynamic> query,
    TxView Function(TypedResult) map,
  })
  _txQuery({
    DateTime? from,
    DateTime? to,
    bool newestFirst = true,
    String? ledgerId,
    String? savingsId,
  }) {
    final toAccount = alias(accounts, 'to_acc');
    final query =
        select(transactions).join([
            innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
            leftOuterJoin(
              categories,
              categories.id.equalsExp(transactions.categoryId),
            ),
            leftOuterJoin(
              toAccount,
              toAccount.id.equalsExp(transactions.transferToAccountId),
            ),
          ])
          ..where(
            transactions.deletedAt.isNull() &
                (ledgerId == null
                    ? const Constant(true)
                    : accounts.ledgerId.equals(ledgerId)) &
                (savingsId == null
                    ? const Constant(true)
                    : transactions.savingsId.equals(savingsId)) &
                (from == null
                    ? const Constant(true)
                    : transactions.date.isBiggerOrEqualValue(from)) &
                (to == null
                    ? const Constant(true)
                    : transactions.date.isSmallerThanValue(to)),
          )
          ..orderBy([
            newestFirst
                ? OrderingTerm.desc(transactions.date)
                : OrderingTerm.asc(transactions.date),
            newestFirst
                ? OrderingTerm.desc(transactions.createdAt)
                : OrderingTerm.asc(transactions.createdAt),
          ]);
    TxView map(TypedResult r) => TxView(
      tx: r.readTable(transactions),
      account: r.readTable(accounts),
      category: r.readTableOrNull(categories),
      transferTo: r.readTableOrNull(toAccount),
    );
    return (query: query, map: map);
  }

  /// Transaksi satu bulan pada buku [ledgerId] (bawaan: Buku Utama).
  Stream<List<TxView>> watchTransactions(
    DateTime month, {
    String ledgerId = kMainLedgerId,
  }) {
    final q = _txQuery(
      from: monthStart(month),
      to: monthEnd(month),
      ledgerId: ledgerId,
    );
    return q.query.watch().map((rows) => rows.map(q.map).toList());
  }

  /// Untuk ekspor: urut dari yang terlama. Tanpa argumen = seluruh riwayat dari
  /// SEMUA buku kas; isi [ledgerId] untuk satu buku saja.
  Future<List<TxView>> getTransactions({
    DateTime? from,
    DateTime? to,
    String? ledgerId,
  }) async {
    final q = _txQuery(
      from: from,
      to: to,
      newestFirst: false,
      ledgerId: ledgerId,
    );
    return (await q.query.get()).map(q.map).toList();
  }

  // ------------------------------------------------------------ tabungan

  static const _savingsSumSql = '''
    COALESCE((SELECT SUM(t.amount) FROM transactions t
              WHERE t.savings_id = s.id AND t.type = ? AND t.deleted_at IS NULL),
             0)
  ''';

  /// Tabungan aktif lebih dulu (urut waktu dibuat), yang diarsipkan di bawah.
  /// Saldo = setoran (pengeluaran dompet) dikurangi penarikan (pemasukan dompet).
  ///
  /// [ledgerId] membatasi ke satu buku kas (bawaan: Buku Utama); null = semua buku.
  Stream<List<SavingsView>> watchSavings({String? ledgerId = kMainLedgerId}) {
    return customSelect(
      'SELECT s.*, $_savingsSumSql AS deposited, $_savingsSumSql AS withdrawn '
      'FROM savings_accounts s '
      '${ledgerId == null ? '' : 'WHERE s.ledger_id = ? '}'
      'ORDER BY s.archived, s.created_at, s.id',
      variables: [
        Variable.withInt(TxType.expense.index),
        Variable.withInt(TxType.income.index),
        if (ledgerId != null) Variable.withString(ledgerId),
      ],
      readsFrom: {savingsAccounts, transactions},
    ).watch().map(
      (rows) => [
        for (final r in rows)
          SavingsView(
            savings: savingsAccounts.map(r.data),
            deposited: r.read<int>('deposited'),
            withdrawn: r.read<int>('withdrawn'),
          ),
      ],
    );
  }

  Future<int> _savingsBalanceOf(String savingsId) async {
    final row = await customSelect(
      'SELECT $_savingsSumSql - $_savingsSumSql AS balance '
      'FROM savings_accounts s WHERE s.id = ?',
      variables: [
        Variable.withInt(TxType.expense.index),
        Variable.withInt(TxType.income.index),
        Variable.withString(savingsId),
      ],
      readsFrom: {savingsAccounts, transactions},
    ).getSingleOrNull();
    return row?.read<int>('balance') ?? 0;
  }

  /// Setoran dan penarikan tabungan: transaksi dompet bertanda [savingsId],
  /// terbaru dulu.
  Stream<List<TxView>> watchSavingsEntries(String savingsId) {
    final q = _txQuery(savingsId: savingsId);
    return q.query.watch().map((rows) => rows.map(q.map).toList());
  }

  static String _cleanSavingsName(String name) {
    final n = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.isEmpty) throw const SavingsException('Nama tabungan wajib diisi.');
    if (n.length > 60) {
      throw const SavingsException('Nama tabungan maksimal 60 karakter.');
    }
    return n;
  }

  Future<void> _ensureSavingsNameFree(
    String name,
    String ledgerId, {
    String? exceptId,
  }) async {
    final clash =
        (await (select(
          savingsAccounts,
        )..where((s) => s.ledgerId.equals(ledgerId))).get()).where(
          (s) => s.id != exceptId && s.name.toLowerCase() == name.toLowerCase(),
        );
    if (clash.isNotEmpty) {
      throw SavingsException(
        clash.first.archived
            ? 'Sudah ada tabungan "$name" yang diarsipkan. Pulihkan saja.'
            : 'Sudah ada tabungan "$name".',
      );
    }
  }

  Future<String> addSavings({
    required String name,
    required String icon,
    required int color,
    String ledgerId = kMainLedgerId,
  }) async {
    final clean = _cleanSavingsName(name);
    return transaction(() async {
      await _requireLedger(ledgerId);
      await _ensureSavingsNameFree(clean, ledgerId);
      final now = DateTime.now();
      final id = _uuid.v7();
      await into(savingsAccounts).insert(
        SavingsAccountsCompanion.insert(
          id: id,
          name: clean,
          icon: Value(icon),
          color: color,
          ledgerId: Value(ledgerId),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return id;
    });
  }

  Future<void> updateSavings({
    required String id,
    required String name,
    required String icon,
    required int color,
  }) async {
    final clean = _cleanSavingsName(name);
    await transaction(() async {
      final current = await (select(
        savingsAccounts,
      )..where((s) => s.id.equals(id))).getSingleOrNull();
      if (current == null) throw StateError('Tabungan $id tidak ditemukan.');
      await _ensureSavingsNameFree(clean, current.ledgerId, exceptId: id);
      await (update(savingsAccounts)..where((s) => s.id.equals(id))).write(
        SavingsAccountsCompanion(
          name: Value(clean),
          icon: Value(icon),
          color: Value(color),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Mengarsipkan hanya bila saldonya kosong: tabungan tersembunyi yang masih
  /// berisi uang akan terlupakan dan saldonya tak terlihat di mana pun.
  Future<void> setSavingsArchived(String id, {required bool archived}) async {
    await transaction(() async {
      if (archived && await _savingsBalanceOf(id) > 0) {
        throw const SavingsException(
          'Tabungan ini masih berisi saldo. Tarik seluruh saldonya dulu '
          'sebelum diarsipkan.',
        );
      }
      final rows =
          await (update(savingsAccounts)..where((s) => s.id.equals(id))).write(
            SavingsAccountsCompanion(
              archived: Value(archived),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (rows == 0) throw StateError('Tabungan $id tidak ditemukan.');
    });
  }

  /// Menghapus PERMANEN tabungan yang belum pernah dipakai. Yang sudah punya
  /// riwayat (termasuk yang dihapus lunak) hanya bisa diarsipkan, supaya
  /// transaksi dompetnya tidak menggantung.
  Future<void> deleteSavings(String id) => transaction(() async {
    final used =
        await (selectOnly(transactions)
              ..addColumns([transactions.id.count()])
              ..where(transactions.savingsId.equals(id)))
            .map((r) => r.read(transactions.id.count()) ?? 0)
            .getSingle();
    if (used > 0) {
      throw const SavingsException(
        'Tabungan ini sudah punya riwayat setoran. Arsipkan saja.',
      );
    }
    await (delete(savingsAccounts)..where((s) => s.id.equals(id))).go();
  });

  /// Kategori "Tabungan" (pengeluaran untuk setoran, pemasukan untuk penarikan)
  /// di buku [ledgerId]; lihat [_systemCategoryId].
  Future<String> _savingsCategoryId(String ledgerId, TxType type) =>
      _systemCategoryId(
        ledgerId,
        type,
        key: 'tabungan',
        name: 'Tabungan',
        icon: 'savings',
        color: 0xFF00897B,
      );

  /// Kategori "Penyesuaian Saldo" di buku [ledgerId]; lihat
  /// [_systemCategoryId].
  Future<String> _adjustmentCategoryId(String ledgerId, TxType type) =>
      _systemCategoryId(
        ledgerId,
        type,
        key: 'penyesuaian',
        name: 'Penyesuaian Saldo',
        icon: 'other',
        color: 0xFF607D8B,
      );

  /// Kategori yang dibuat aplikasi untuk fitur tertentu di buku [ledgerId].
  /// Dibuat saat pertama dibutuhkan, bukan lewat seed, supaya buku yang sudah
  /// ada tidak perlu migrasi data. Memakai kategori buatan pengguna bernama
  /// sama bila ada, agar tidak muncul ganda.
  Future<String> _systemCategoryId(
    String ledgerId,
    TxType type, {
    required String key,
    required String name,
    required String icon,
    required int color,
  }) async {
    assert(type != TxType.transfer);
    final id = ledgerSeedId(
      ledgerId,
      type == TxType.expense ? 'cat-exp-$key' : 'cat-inc-$key',
    );
    final sameType =
        await (select(categories)..where(
              (c) => c.type.equalsValue(type) & c.ledgerId.equals(ledgerId),
            ))
            .get();
    for (final c in sameType) {
      if (c.id == id) return id;
    }
    for (final c in sameType) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c.id;
    }
    final last = sameType.fold<int>(
      -1,
      (m, c) => c.sortOrder > m ? c.sortOrder : m,
    );
    await into(categories).insert(
      CategoriesCompanion.insert(
        id: id,
        name: name,
        type: type,
        icon: Value(icon),
        color: color,
        sortOrder: Value(last + 1),
        ledgerId: Value(ledgerId),
        updatedAt: DateTime.now(),
      ),
    );
    return id;
  }

  /// Mencatat satu transaksi dompet bertanda [savingsId]. Setoran = pengeluaran
  /// dari dompet [accountId]; penarikan = pemasukan ke dompet [accountId].
  Future<String> _recordSavingsMove({
    required String savingsId,
    required String accountId,
    required int amount,
    required DateTime date,
    required bool deposit,
    String? note,
  }) async {
    if (amount <= 0) {
      throw const SavingsException('Nominal harus lebih dari 0.');
    }
    if (amount > maxAccountBalance) {
      throw const SavingsException('Nominal terlalu besar.');
    }
    return transaction(() async {
      final savings = await (select(
        savingsAccounts,
      )..where((s) => s.id.equals(savingsId))).getSingleOrNull();
      if (savings == null) {
        throw StateError('Tabungan $savingsId tidak ditemukan.');
      }
      if (savings.archived) {
        throw const SavingsException(
          'Tabungan ini diarsipkan. Pulihkan dulu untuk mengubah isinya.',
        );
      }
      await _requireLedger(savings.ledgerId);
      final account = await (select(
        accounts,
      )..where((a) => a.id.equals(accountId))).getSingleOrNull();
      if (account == null) {
        throw StateError('Dompet $accountId tidak ditemukan.');
      }
      if (account.archived) {
        throw const SavingsException('Dompet ini diarsipkan.');
      }
      if (account.ledgerId != savings.ledgerId) {
        throw const SavingsException(
          'Dompet dan tabungan harus berasal dari buku kas yang sama.',
        );
      }
      if (!deposit) {
        final balance = await _savingsBalanceOf(savingsId);
        if (amount > balance) {
          throw SavingsException(
            balance == 0
                ? 'Belum ada saldo di tabungan ini.'
                : 'Saldo tabungan hanya ${rupiah(balance)}.',
          );
        }
      }
      final type = deposit ? TxType.expense : TxType.income;
      final categoryId = await _savingsCategoryId(savings.ledgerId, type);
      final now = DateTime.now();
      final trimmed = note?.trim();
      final txId = _uuid.v7();
      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: txId,
          type: type,
          amount: amount,
          accountId: accountId,
          categoryId: Value(categoryId),
          date: date,
          note: Value(
            trimmed == null || trimmed.isEmpty
                ? (deposit
                      ? 'Setoran ke ${savings.name}'
                      : 'Penarikan dari ${savings.name}')
                : trimmed,
          ),
          createdAt: now,
          updatedAt: now,
          savingsId: Value(savingsId),
        ),
      );
      return txId;
    });
  }

  /// Menyetor [amount] dari dompet [accountId] ke tabungan: dibukukan sebagai
  /// pengeluaran yang mengurangi saldo dompet itu.
  Future<String> depositToSavings({
    required String savingsId,
    required String accountId,
    required int amount,
    required DateTime date,
    String? note,
  }) => _recordSavingsMove(
    savingsId: savingsId,
    accountId: accountId,
    amount: amount,
    date: date,
    deposit: true,
    note: note,
  );

  /// Menarik [amount] dari tabungan ke dompet [accountId]: dibukukan sebagai
  /// pemasukan yang menambah saldo dompet itu. Tidak boleh melebihi saldo.
  Future<String> withdrawFromSavings({
    required String savingsId,
    required String accountId,
    required int amount,
    required DateTime date,
    String? note,
  }) => _recordSavingsMove(
    savingsId: savingsId,
    accountId: accountId,
    amount: amount,
    date: date,
    deposit: false,
    note: note,
  );

  /// Menghapus/memulihkan (soft delete) satu setoran/penarikan, sekaligus
  /// transaksi dompetnya. Ditolak bila saldo tabungan akan menjadi negatif,
  /// mis. menghapus setoran yang sudah sebagian ditarik.
  Future<void> setSavingsEntryDeleted(String txId, {required bool deleted}) {
    return transaction(() async {
      final tx = await (select(
        transactions,
      )..where((t) => t.id.equals(txId))).getSingleOrNull();
      if (tx == null || tx.savingsId == null) {
        throw StateError('Transaksi tabungan $txId tidak ditemukan.');
      }
      if ((tx.deletedAt != null) == deleted) return; // sudah sesuai
      final effect = tx.type == TxType.expense ? tx.amount : -tx.amount;
      final after =
          await _savingsBalanceOf(tx.savingsId!) + (deleted ? -effect : effect);
      if (after < 0) {
        throw const SavingsException(
          'Tidak bisa diubah: saldo tabungan akan menjadi negatif. '
          'Hapus penarikan terkait terlebih dulu.',
        );
      }
      final now = DateTime.now();
      await (update(transactions)..where((t) => t.id.equals(txId))).write(
        TransactionsCompanion(
          deletedAt: Value(deleted ? now : null),
          updatedAt: Value(now),
        ),
      );
    });
  }

  // ------------------------------------------------------ utang/piutang

  Future<String> addDebt({
    required DebtType type,
    required String counterpartyName,
    required int amount,
    String? note,
    DateTime? dueDate,
    String? accountId,
    String ledgerId = kMainLedgerId,
  }) async {
    final trimmedName = counterpartyName.trim();
    if (trimmedName.isEmpty) {
      throw const AccountException('Nama pihak tidak boleh kosong.');
    }
    if (amount <= 0) {
      throw const AccountException('Nominal harus lebih dari 0.');
    }
    await _requireLedger(ledgerId);
    if (accountId != null) {
      await _checkSameLedger(accountId: accountId, ledgerId: ledgerId);
    }
    final now = DateTime.now();
    final id = _uuid.v7();
    final trimmedNote = note?.trim();
    await into(debts).insert(
      DebtsCompanion.insert(
        id: id,
        ledgerId: Value(ledgerId),
        type: type,
        counterpartyName: trimmedName,
        amount: amount,
        note: Value(
          trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
        ),
        dueDate: Value(dueDate),
        accountId: Value(accountId),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Tipe (utang/piutang) sengaja tidak bisa diubah — sama alasannya dengan
  /// jadwal [updateAgenda]: mengubah artinya mengubah makna transaksi
  /// pembayaran yang sudah tercatat.
  Future<void> updateDebt({
    required String id,
    required String counterpartyName,
    required int amount,
    String? note,
    DateTime? dueDate,
    String? accountId,
  }) async {
    final trimmedName = counterpartyName.trim();
    if (trimmedName.isEmpty) {
      throw const AccountException('Nama pihak tidak boleh kosong.');
    }
    if (amount <= 0) {
      throw const AccountException('Nominal harus lebih dari 0.');
    }
    final trimmedNote = note?.trim();
    final rows = await (update(debts)..where((d) => d.id.equals(id))).write(
      DebtsCompanion(
        counterpartyName: Value(trimmedName),
        amount: Value(amount),
        note: Value(
          trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
        ),
        dueDate: Value(dueDate),
        accountId: Value(accountId),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (rows == 0) throw StateError('Utang/piutang $id tidak ditemukan.');
  }

  Future<void> deleteDebt(String id) =>
      (delete(debts)..where((d) => d.id.equals(id))).go();

  /// [ledgerId] membatasi ke satu buku kas (bawaan: Buku Utama); null = semua buku.
  Stream<List<Debt>> watchDebts({String? ledgerId = kMainLedgerId}) {
    return (select(debts)
          ..where(
            (d) => ledgerId == null
                ? const Constant(true)
                : d.ledgerId.equals(ledgerId),
          )
          ..orderBy([
            (d) => OrderingTerm.asc(d.paidAmount),
            (d) => OrderingTerm.asc(d.createdAt),
          ]))
        .watch();
  }

  /// Mencatat pembayaran/penerimaan nyata untuk utang/piutang [debtId]: satu
  /// transaksi DB, mencatat satu baris [Transactions] (pengeluaran untuk
  /// utang, pemasukan untuk piutang) DAN menambah `paidAmount` sekaligus —
  /// pola sama [executeAgenda]. Nominal BEBAS beda dari sisa
  /// (`amount - paidAmount`), mendukung pembayaran sebagian (cicilan)
  /// berkali-kali sampai lunas.
  Future<String> recordDebtPayment({
    required String debtId,
    required int amount,
    required String accountId,
    String? categoryId,
    required DateTime date,
    String? note,
  }) {
    assert(amount > 0);
    return transaction(() async {
      final item = await (select(
        debts,
      )..where((d) => d.id.equals(debtId))).getSingle();
      await _checkSameLedger(
        accountId: accountId,
        categoryId: categoryId,
        ledgerId: item.ledgerId,
      );
      final now = DateTime.now();
      final trimmed = note?.trim();
      final txId = _uuid.v7();
      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: txId,
          type: item.type == DebtType.debt ? TxType.expense : TxType.income,
          amount: amount,
          accountId: accountId,
          categoryId: Value(categoryId),
          date: date,
          note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
          createdAt: now,
          updatedAt: now,
          debtId: Value(debtId),
        ),
      );
      await (update(debts)..where((d) => d.id.equals(debtId))).write(
        DebtsCompanion(
          paidAmount: Value(item.paidAmount + amount),
          updatedAt: Value(now),
        ),
      );
      return txId;
    });
  }

  // ------------------------------------------------------------- reports

  /// Total pemasukan/pengeluaran satu bulan pada buku [ledgerId] (bawaan: Buku
  /// Utama). Transaksi milik buku lewat dompetnya (`accounts.ledger_id`).
  Stream<MonthTotals> watchTotals(
    DateTime month, {
    String ledgerId = kMainLedgerId,
  }) {
    return customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN t.type = 0 THEN t.amount END), 0) AS income,
        COALESCE(SUM(CASE WHEN t.type = 1 THEN t.amount END), 0) AS expense
      FROM transactions t
      JOIN accounts a ON a.id = t.account_id
      WHERE t.deleted_at IS NULL AND a.ledger_id = ?
        AND t.date >= ? AND t.date < ?
      ''',
      variables: [
        Variable.withString(ledgerId),
        Variable.withDateTime(monthStart(month)),
        Variable.withDateTime(monthEnd(month)),
      ],
      readsFrom: {transactions, accounts},
    ).watchSingle().map(
      (r) => (income: r.read<int>('income'), expense: r.read<int>('expense')),
    );
  }

  static String _ymKey(DateTime m) =>
      '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';

  /// [months] bulan terakhir, berakhir di (dan termasuk) [endMonth]. Bulan
  /// tanpa transaksi tetap muncul dengan nilai 0, bukan hilang dari daftar.
  ///
  /// Bucket per bulan dikerjakan di Dart, BUKAN lewat `strftime(..., 'unixepoch')`
  /// di SQL: strftime menafsirkan detik-epoch sebagai UTC, sedangkan tanggal
  /// di app ini naif-lokal (lihat `monthStart`/`monthEnd`) — di zona +7 ke
  /// atas, transaksi awal bulan bisa "geser" ke bulan sebelumnya kalau
  /// dibucket lewat SQL.
  Stream<List<MonthlyTotal>> watchMonthlyTrend(
    DateTime endMonth, {
    int months = 6,
    String ledgerId = kMainLedgerId,
  }) {
    final start = DateTime(endMonth.year, endMonth.month - months + 1);
    return customSelect(
      '''
      SELECT t.type AS type, t.amount AS amount, t.date AS date
      FROM transactions t
      JOIN accounts a ON a.id = t.account_id
      WHERE t.deleted_at IS NULL AND t.type IN (0, 1) AND a.ledger_id = ?
        AND t.date >= ? AND t.date < ?
      ''',
      variables: [
        Variable.withString(ledgerId),
        Variable.withDateTime(monthStart(start)),
        Variable.withDateTime(monthEnd(endMonth)),
      ],
      readsFrom: {transactions, accounts},
    ).watch().map((rows) {
      final byYm = <String, ({int income, int expense})>{};
      for (final r in rows) {
        final key = _ymKey(r.read<DateTime>('date'));
        final cur = byYm[key] ?? (income: 0, expense: 0);
        final amount = r.read<int>('amount');
        byYm[key] = r.read<int>('type') == 0
            ? (income: cur.income + amount, expense: cur.expense)
            : (income: cur.income, expense: cur.expense + amount);
      }
      return [
        for (var i = 0; i < months; i++)
          () {
            final m = DateTime(start.year, start.month + i);
            final t = byYm[_ymKey(m)];
            return MonthlyTotal(
              month: m,
              income: t?.income ?? 0,
              expense: t?.expense ?? 0,
            );
          }(),
      ];
    });
  }

  Stream<List<CategorySpend>> watchExpenseByCategory(
    DateTime month, {
    String ledgerId = kMainLedgerId,
  }) {
    return customSelect(
      '''
      SELECT c.id AS id, c.name AS name, c.icon AS icon, c.color AS color,
             SUM(t.amount) AS total
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.deleted_at IS NULL AND t.type = 1 AND c.ledger_id = ?
        AND t.date >= ? AND t.date < ?
      GROUP BY c.id
      ORDER BY total DESC
      ''',
      variables: [
        Variable.withString(ledgerId),
        Variable.withDateTime(monthStart(month)),
        Variable.withDateTime(monthEnd(month)),
      ],
      readsFrom: {transactions, categories},
    ).watch().map(
      (rows) => [
        for (final r in rows)
          CategorySpend(
            categoryId: r.read<String>('id'),
            name: r.read<String>('name'),
            icon: r.read<String>('icon'),
            color: r.read<int>('color'),
            total: r.read<int>('total'),
          ),
      ],
    );
  }

  /// Pengeluaran per kategori per bulan, [months] bulan terakhir berakhir di
  /// (dan termasuk) [endMonth] — untuk Analisa Tren (fitur premium). Bucket
  /// per bulan di Dart, sama alasannya dengan [watchMonthlyTrend].
  Stream<List<CategoryMonthlyTotal>> watchCategoryMonthlyTrend(
    DateTime endMonth, {
    int months = 6,
    String ledgerId = kMainLedgerId,
  }) {
    final start = DateTime(endMonth.year, endMonth.month - months + 1);
    return customSelect(
      '''
      SELECT c.id AS id, c.name AS name, c.icon AS icon, c.color AS color,
             t.amount AS amount, t.date AS date
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.deleted_at IS NULL AND t.type = 1 AND c.ledger_id = ?
        AND t.date >= ? AND t.date < ?
      ''',
      variables: [
        Variable.withString(ledgerId),
        Variable.withDateTime(monthStart(start)),
        Variable.withDateTime(monthEnd(endMonth)),
      ],
      readsFrom: {transactions, categories},
    ).watch().map((rows) {
      final byKey = <String, CategoryMonthlyTotal>{};
      for (final r in rows) {
        final categoryId = r.read<String>('id');
        final month = _ymKey(r.read<DateTime>('date'));
        final key = '$categoryId|$month';
        final existing = byKey[key];
        byKey[key] = CategoryMonthlyTotal(
          categoryId: categoryId,
          categoryName: r.read<String>('name'),
          icon: r.read<String>('icon'),
          color: r.read<int>('color'),
          month: DateTime.parse('$month-01'),
          total: (existing?.total ?? 0) + r.read<int>('amount'),
        );
      }
      return byKey.values.toList();
    });
  }

  // ------------------------------------------------------ target tabungan

  static const maxGoalTarget =
      999999999999; // 12 digit, sama dengan input Rupiah

  static String _cleanGoalName(String name) {
    final n = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.isEmpty) throw const GoalException('Nama target wajib diisi.');
    if (n.length > 60) {
      throw const GoalException('Nama target maksimal 60 karakter.');
    }
    return n;
  }

  static void _checkTarget(int target) {
    if (target <= 0) {
      throw const GoalException('Nominal target harus lebih dari 0.');
    }
    if (target > maxGoalTarget) {
      throw const GoalException('Nominal target terlalu besar.');
    }
  }

  static const _savedSql = '''
    COALESCE((SELECT SUM(CASE c.kind WHEN 0 THEN c.amount ELSE -c.amount END)
              FROM goal_contributions c
              WHERE c.goal_id = g.id AND c.deleted_at IS NULL), 0)
  ''';

  /// Target aktif lebih dulu (urut waktu dibuat), yang diarsipkan di bawah.
  ///
  /// [ledgerId] membatasi ke satu buku kas (bawaan: Buku Utama); null = semua buku.
  Stream<List<GoalView>> watchGoals({String? ledgerId = kMainLedgerId}) {
    return customSelect(
      'SELECT g.*, $_savedSql AS saved FROM savings_goals g '
      '${ledgerId == null ? '' : 'WHERE g.ledger_id = ? '}'
      'ORDER BY g.archived, g.created_at, g.id',
      variables: [if (ledgerId != null) Variable.withString(ledgerId)],
      readsFrom: {savingsGoals, goalContributions},
    ).watch().map(
      (rows) => [
        for (final r in rows)
          GoalView(goal: savingsGoals.map(r.data), saved: r.read<int>('saved')),
      ],
    );
  }

  Future<int> _savedOf(String goalId) async {
    final row = await customSelect(
      'SELECT $_savedSql AS saved FROM savings_goals g WHERE g.id = ?',
      variables: [Variable.withString(goalId)],
      readsFrom: {savingsGoals, goalContributions},
    ).getSingleOrNull();
    return row?.read<int>('saved') ?? 0;
  }

  Future<String> addGoal({
    required String name,
    required int targetAmount,
    required String icon,
    required int color,
    DateTime? deadline,
    String ledgerId = kMainLedgerId,
  }) async {
    final clean = _cleanGoalName(name);
    _checkTarget(targetAmount);
    await _requireLedger(ledgerId);
    final now = DateTime.now();
    final id = _uuid.v7();
    await into(savingsGoals).insert(
      SavingsGoalsCompanion.insert(
        id: id,
        ledgerId: Value(ledgerId),
        name: clean,
        targetAmount: targetAmount,
        deadline: Value(deadline == null ? null : dateOnly(deadline)),
        icon: Value(icon),
        color: color,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> updateGoal({
    required String id,
    required String name,
    required int targetAmount,
    required String icon,
    required int color,
    DateTime? deadline,
  }) async {
    final clean = _cleanGoalName(name);
    _checkTarget(targetAmount);
    final rows = await (update(savingsGoals)..where((g) => g.id.equals(id)))
        .write(
          SavingsGoalsCompanion(
            name: Value(clean),
            targetAmount: Value(targetAmount),
            deadline: Value(deadline == null ? null : dateOnly(deadline)),
            icon: Value(icon),
            color: Value(color),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (rows == 0) throw StateError('Target $id tidak ditemukan.');
  }

  Future<void> setGoalArchived(String id, {required bool archived}) async {
    final rows = await (update(savingsGoals)..where((g) => g.id.equals(id)))
        .write(
          SavingsGoalsCompanion(
            archived: Value(archived),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (rows == 0) throw StateError('Target $id tidak ditemukan.');
  }

  /// Menghapus PERMANEN target beserta seluruh setoran dan penarikannya.
  Future<void> deleteGoal(String id) => transaction(() async {
    await (delete(goalContributions)..where((c) => c.goalId.equals(id))).go();
    await (delete(savingsGoals)..where((g) => g.id.equals(id))).go();
  });

  Future<void> addContribution({
    required String goalId,
    required ContributionKind kind,
    required int amount,
    DateTime? date,
    String? note,
  }) async {
    if (amount <= 0) throw const GoalException('Nominal harus lebih dari 0.');
    if (amount > maxGoalTarget) {
      throw const GoalException('Nominal terlalu besar.');
    }
    await transaction(() async {
      final goal = await (select(
        savingsGoals,
      )..where((g) => g.id.equals(goalId))).getSingleOrNull();
      if (goal == null) throw StateError('Target $goalId tidak ditemukan.');
      if (goal.archived) {
        throw const GoalException(
          'Target ini diarsipkan. Pulihkan dulu untuk mengubah dananya.',
        );
      }
      if (kind == ContributionKind.withdrawal) {
        final saved = await _savedOf(goalId);
        if (amount > saved) {
          throw GoalException(
            saved == 0
                ? 'Belum ada dana terkumpul untuk ditarik.'
                : 'Dana terkumpul hanya ${rupiah(saved)}.',
          );
        }
      }
      final now = DateTime.now();
      final trimmed = note?.trim();
      await into(goalContributions).insert(
        GoalContributionsCompanion.insert(
          id: _uuid.v7(),
          goalId: goalId,
          kind: kind,
          amount: amount,
          date: dateOnly(date ?? now),
          note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  Stream<List<GoalContribution>> watchContributions(String goalId) {
    return (select(goalContributions)
          ..where((c) => c.goalId.equals(goalId) & c.deletedAt.isNull())
          ..orderBy([
            (c) => OrderingTerm.desc(c.date),
            (c) => OrderingTerm.desc(c.createdAt),
          ]))
        .watch();
  }

  /// Menghapus/memulihkan (soft delete) satu setoran/penarikan. Ditolak bila
  /// hasilnya membuat dana terkumpul negatif, mis. menghapus setoran yang sudah
  /// sebagian ditarik.
  Future<void> setContributionDeleted(String id, {required bool deleted}) {
    return transaction(() async {
      final c = await (select(
        goalContributions,
      )..where((x) => x.id.equals(id))).getSingleOrNull();
      if (c == null) throw StateError('Data $id tidak ditemukan.');
      if ((c.deletedAt != null) == deleted) return; // sudah sesuai

      final effect = c.kind == ContributionKind.deposit ? c.amount : -c.amount;
      final after = await _savedOf(c.goalId) + (deleted ? -effect : effect);
      if (after < 0) {
        throw const GoalException(
          'Tidak bisa diubah: dana terkumpul akan menjadi negatif. '
          'Hapus penarikan terkait terlebih dulu.',
        );
      }
      final now = DateTime.now();
      await (update(goalContributions)..where((x) => x.id.equals(id))).write(
        GoalContributionsCompanion(
          deletedAt: Value(deleted ? now : null),
          updatedAt: Value(now),
        ),
      );
    });
  }

  // ------------------------------------------------------------- budgets

  /// Hanya kategori tingkat atas: pemakaian sub-kategori otomatis masuk ke
  /// anggaran induknya (satu tingkat saja, jadi cukup subquery langsung tanpa
  /// CTE rekursif). Sub-kategori sendiri tidak punya baris anggaran terpisah.
  ///
  /// [ledgerId] membatasi ke satu buku kas (bawaan: Buku Utama); null = semua buku
  /// (dipakai notifikasi anggaran, yang bekerja lintas buku).
  Stream<List<BudgetProgress>> watchBudgetProgress(
    DateTime month, {
    String? ledgerId = kMainLedgerId,
  }) {
    return customSelect(
      '''
      SELECT c.id AS id, b.amount AS budget,
        COALESCE((SELECT SUM(t.amount) FROM transactions t
                  WHERE t.type = 1 AND t.deleted_at IS NULL
                    AND t.date >= ? AND t.date < ?
                    AND (t.category_id = c.id OR t.category_id IN (
                      SELECT id FROM categories WHERE parent_id = c.id
                    ))), 0) AS spent
      FROM categories c
      LEFT JOIN budgets b ON b.category_id = c.id
      WHERE c.type = 1 AND c.archived = 0 AND c.parent_id IS NULL
        ${ledgerId == null ? '' : 'AND c.ledger_id = ?'}
      ORDER BY c.ledger_id, c.sort_order
      ''',
      variables: [
        Variable.withDateTime(monthStart(month)),
        Variable.withDateTime(monthEnd(month)),
        if (ledgerId != null) Variable.withString(ledgerId),
      ],
      readsFrom: {transactions, categories, budgets},
    ).watch().asyncMap((rows) async {
      final cats = {for (final c in await select(categories).get()) c.id: c};
      return [
        for (final r in rows)
          BudgetProgress(
            category: cats[r.read<String>('id')]!,
            spent: r.read<int>('spent'),
            budget: r.read<int?>('budget'),
          ),
      ];
    });
  }

  /// [amount] null atau 0 menghapus anggaran kategori tersebut.
  Future<void> setBudget(String categoryId, int? amount) async {
    if (amount == null || amount <= 0) {
      await (delete(
        budgets,
      )..where((b) => b.categoryId.equals(categoryId))).go();
      return;
    }
    await into(budgets).insertOnConflictUpdate(
      BudgetsCompanion.insert(
        categoryId: categoryId,
        amount: amount,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ----------------------------------------------------------------- tags

  static String _cleanTagName(String name) {
    final n = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.isEmpty) throw const TagException('Nama tag wajib diisi.');
    if (n.length > 40)
      throw const TagException('Nama tag maksimal 40 karakter.');
    return n;
  }

  /// Nama harus unik (tanpa membedakan huruf besar/kecil).
  Future<void> _ensureTagNameFree(String name, {String? exceptId}) async {
    final same = await select(tags).get();
    final clash = same.where(
      (t) => t.id != exceptId && t.name.toLowerCase() == name.toLowerCase(),
    );
    if (clash.isNotEmpty) {
      throw TagException('Sudah ada tag "$name".');
    }
  }

  Future<String> addTag(String name) async {
    final clean = _cleanTagName(name);
    return transaction(() async {
      await _ensureTagNameFree(clean);
      final id = _uuid.v7();
      await into(tags).insert(
        TagsCompanion.insert(id: id, name: clean, updatedAt: DateTime.now()),
      );
      return id;
    });
  }

  Future<void> renameTag(String id, String name) async {
    final clean = _cleanTagName(name);
    await transaction(() async {
      await _ensureTagNameFree(clean, exceptId: id);
      final rows = await (update(tags)..where((t) => t.id.equals(id))).write(
        TagsCompanion(name: Value(clean), updatedAt: Value(DateTime.now())),
      );
      if (rows == 0) throw StateError('Tag $id tidak ditemukan.');
    });
  }

  /// Menghapus PERMANEN tag ini (dan melepasnya dari semua transaksi).
  Future<void> deleteTag(String id) => transaction(() async {
    await (delete(transactionTags)..where((t) => t.tagId.equals(id))).go();
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  });

  Stream<List<Tag>> watchTags() =>
      (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<Tag>> watchTagsForTransaction(String transactionId) {
    final q =
        select(tags).join([
            innerJoin(
              transactionTags,
              transactionTags.tagId.equalsExp(tags.id),
            ),
          ])
          ..where(transactionTags.transactionId.equals(transactionId))
          ..orderBy([OrderingTerm.asc(tags.name)]);
    return q.watch().map((rows) => rows.map((r) => r.readTable(tags)).toList());
  }

  /// Mengganti seluruh tag transaksi ini dengan [tagIds].
  Future<void> setTransactionTags(String transactionId, List<String> tagIds) =>
      transaction(() async {
        await (delete(
          transactionTags,
        )..where((t) => t.transactionId.equals(transactionId))).go();
        if (tagIds.isEmpty) return;
        await batch((b) {
          b.insertAll(transactionTags, [
            for (final tagId in tagIds.toSet())
              TransactionTagsCompanion.insert(
                transactionId: transactionId,
                tagId: tagId,
              ),
          ]);
        });
      });

  // ------------------------------------------------------------ buku kas

  /// Semua buku (yang diarsipkan di urutan bawah). Buku Utama selalu ada.
  Stream<List<Ledger>> watchLedgers() {
    return (select(ledgers)..orderBy([
          (l) => OrderingTerm.asc(l.archived),
          (l) => OrderingTerm.asc(l.sortOrder),
          (l) => OrderingTerm.asc(l.createdAt),
        ]))
        .watch();
  }

  /// Total saldo dompet aktif per buku (id buku -> saldo), untuk pengalih buku.
  Stream<Map<String, int>> watchLedgerBalances() {
    return customSelect(
      '''
      SELECT a.ledger_id AS ledger_id,
        SUM(a.initial_balance
          + COALESCE((SELECT SUM(CASE t.type WHEN 0 THEN t.amount ELSE -t.amount END)
                      FROM transactions t
                      WHERE t.account_id = a.id AND t.deleted_at IS NULL), 0)
          + COALESCE((SELECT SUM(t.amount) FROM transactions t
                      WHERE t.transfer_to_account_id = a.id AND t.type = 2
                        AND t.deleted_at IS NULL), 0)) AS total
      FROM accounts a
      WHERE a.archived = 0
      GROUP BY a.ledger_id
      ''',
      readsFrom: {accounts, transactions},
    ).watch().map(
      (rows) => {
        for (final r in rows) r.read<String>('ledger_id'): r.read<int>('total'),
      },
    );
  }

  static String _cleanLedgerName(String name) {
    final n = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.isEmpty) throw const LedgerException('Nama buku kas wajib diisi.');
    if (n.length > 40) {
      throw const LedgerException('Nama buku kas maksimal 40 karakter.');
    }
    return n;
  }

  Future<void> _ensureLedgerNameFree(String name, {String? exceptId}) async {
    final clash = (await select(ledgers).get()).where(
      (l) => l.id != exceptId && l.name.toLowerCase() == name.toLowerCase(),
    );
    if (clash.isNotEmpty) {
      throw LedgerException(
        clash.first.archived
            ? 'Sudah ada buku "$name" yang diarsipkan. Pulihkan saja buku itu.'
            : 'Sudah ada buku "$name".',
      );
    }
  }

  /// Membuat buku baru dan mengisinya sesuai [template]. Buku yang diarsipkan
  /// tidak dihitung terhadap batas [kMaxLedgers].
  Future<String> addLedger({
    required String name,
    required String icon,
    required int color,
    LedgerTemplate template = LedgerTemplate.personal,
  }) async {
    final clean = _cleanLedgerName(name);
    return transaction(() async {
      final all = await select(ledgers).get();
      if (all.where((l) => !l.archived).length >= kMaxLedgers) {
        throw const LedgerException(
          'Jumlah buku kas sudah mencapai batas ($kMaxLedgers). '
          'Arsipkan buku yang tidak dipakai dulu.',
        );
      }
      await _ensureLedgerNameFree(clean);
      final now = DateTime.now();
      final id = 'ledger-${_uuid.v7()}';
      await into(ledgers).insert(
        LedgersCompanion.insert(
          id: id,
          name: clean,
          icon: Value(icon),
          color: color,
          sortOrder: Value(
            all.fold<int>(0, (m, l) => l.sortOrder > m ? l.sortOrder : m) + 1,
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _seedLedgerContent(id, template, now: now);
      return id;
    });
  }

  Future<void> updateLedger({
    required String id,
    required String name,
    required String icon,
    required int color,
  }) async {
    final clean = _cleanLedgerName(name);
    await transaction(() async {
      await _ensureLedgerNameFree(clean, exceptId: id);
      final rows = await (update(ledgers)..where((l) => l.id.equals(id))).write(
        LedgersCompanion(
          name: Value(clean),
          icon: Value(icon),
          color: Value(color),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (rows == 0) throw const LedgerException('Buku kas tidak ditemukan.');
    });
  }

  /// Mengarsipkan menyembunyikan buku dari pengalih; datanya tetap ada dan
  /// aturan berulangnya dijeda (lihat [generateDueRecurring]). Buku Utama tidak
  /// bisa diarsipkan.
  Future<void> setLedgerArchived(String id, {required bool archived}) async {
    if (id == kMainLedgerId) {
      throw const LedgerException('Buku Utama tidak bisa diarsipkan.');
    }
    await transaction(() async {
      if (!archived) {
        final active = (await select(ledgers).get()).where((l) => !l.archived);
        if (active.length >= kMaxLedgers) {
          throw const LedgerException(
            'Jumlah buku kas sudah mencapai batas ($kMaxLedgers).',
          );
        }
      }
      final rows = await (update(ledgers)..where((l) => l.id.equals(id))).write(
        LedgersCompanion(
          archived: Value(archived),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (rows == 0) throw const LedgerException('Buku kas tidak ditemukan.');
    });
  }

  /// Jumlah isi sebuah buku, untuk dialog konfirmasi hapus.
  Future<({int transactions, int accounts})> ledgerUsage(String id) async {
    final accountRows = await (select(
      accounts,
    )..where((a) => a.ledgerId.equals(id))).get();
    if (accountRows.isEmpty) return (transactions: 0, accounts: 0);
    final txCount =
        await (selectOnly(transactions)
              ..addColumns([transactions.id.count()])
              ..where(
                transactions.accountId.isIn([
                      for (final a in accountRows) a.id,
                    ]) &
                    transactions.deletedAt.isNull(),
              ))
            .map((r) => r.read(transactions.id.count()) ?? 0)
            .getSingle();
    return (transactions: txCount, accounts: accountRows.length);
  }

  /// Menghapus PERMANEN sebuah buku beserta seluruh isinya (dompet, kategori,
  /// transaksi, aturan berulang, anggaran, target, agenda, utang/piutang).
  /// Buku Utama tidak bisa dihapus. TIDAK BISA dibatalkan — pemanggil wajib
  /// meminta konfirmasi eksplisit.
  Future<void> deleteLedger(String id) async {
    if (id == kMainLedgerId) {
      throw const LedgerException('Buku Utama tidak bisa dihapus.');
    }
    await transaction(() async {
      final exists = await (select(
        ledgers,
      )..where((l) => l.id.equals(id))).getSingleOrNull();
      if (exists == null)
        throw const LedgerException('Buku kas tidak ditemukan.');

      // `categories.parent_id` menunjuk ke dirinya sendiri; urutan hapus dan
      // defer_foreign_keys sama alasannya dengan eraseAllData/restore.
      await customStatement('PRAGMA defer_foreign_keys = ON');
      final accountIds = [
        for (final a in await (select(
          accounts,
        )..where((a) => a.ledgerId.equals(id))).get())
          a.id,
      ];
      final categoryIds = [
        for (final c in await (select(
          categories,
        )..where((c) => c.ledgerId.equals(id))).get())
          c.id,
      ];
      final goalIds = [
        for (final g in await (select(
          savingsGoals,
        )..where((g) => g.ledgerId.equals(id))).get())
          g.id,
      ];
      final txIds = [
        for (final t in await (select(
          transactions,
        )..where((t) => t.accountId.isIn(accountIds))).get())
          t.id,
      ];
      await (delete(
        transactionTags,
      )..where((t) => t.transactionId.isIn(txIds))).go();
      await (delete(transactions)..where((t) => t.id.isIn(txIds))).go();
      await (delete(
        recurringRules,
      )..where((r) => r.accountId.isIn(accountIds))).go();
      await (delete(
        budgets,
      )..where((b) => b.categoryId.isIn(categoryIds))).go();
      await (delete(
        goalContributions,
      )..where((c) => c.goalId.isIn(goalIds))).go();
      await (delete(savingsGoals)..where((g) => g.ledgerId.equals(id))).go();
      await (delete(savingsAccounts)..where((s) => s.ledgerId.equals(id))).go();
      await (delete(agendaReminders)..where((a) => a.ledgerId.equals(id))).go();
      await (delete(debts)..where((d) => d.ledgerId.equals(id))).go();
      await (delete(categories)..where((c) => c.ledgerId.equals(id))).go();
      await (delete(accounts)..where((a) => a.ledgerId.equals(id))).go();
      await (delete(ledgers)..where((l) => l.id.equals(id))).go();
    });
  }

  /// Buku [id] harus ada dan tidak diarsipkan (untuk menulis ke dalamnya).
  Future<Ledger> _requireLedger(String id) async {
    final l = await (select(
      ledgers,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (l == null) throw const LedgerException('Buku kas tidak ditemukan.');
    if (l.archived) {
      throw LedgerException(
        'Buku "${l.name}" diarsipkan. Pulihkan dulu untuk mengubah isinya.',
      );
    }
    return l;
  }

  /// Menegakkan aturan "satu buku": dompet asal, dompet tujuan, kategori, dan
  /// (bila diberikan) [ledgerId] harus berada di buku yang sama.
  Future<void> _checkSameLedger({
    required String accountId,
    String? categoryId,
    String? transferToAccountId,
    String? ledgerId,
  }) async {
    final ids = <String>{?ledgerId};
    final accountIds = {accountId, ?transferToAccountId};
    for (final a in await (select(
      accounts,
    )..where((a) => a.id.isIn(accountIds))).get()) {
      ids.add(a.ledgerId);
    }
    if (categoryId != null) {
      final c = await (select(
        categories,
      )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
      if (c != null) ids.add(c.ledgerId);
    }
    if (ids.length > 1) {
      throw const LedgerException(
        'Dompet dan kategori harus berasal dari buku kas yang sama.',
      );
    }
  }

  // ------------------------------------------------------------ hapus data

  /// Menghapus SELURUH data secara permanen dan mengembalikan ke kondisi
  /// seperti baru terpasang (kategori bawaan + dompet Tunai). TIDAK BISA
  /// dibatalkan — pemanggil bertanggung jawab meminta konfirmasi eksplisit.
  ///
  /// Urutan hapus dan `defer_foreign_keys` sama seperti `BackupService.restore`
  /// (lib/data/backup.dart) — alasan sama: `categories.parent_id` menunjuk ke
  /// dirinya sendiri.
  Future<void> eraseAllData() => transaction(() async {
    await customStatement('PRAGMA defer_foreign_keys = ON');
    await delete(budgets).go();
    await delete(transactionTags).go();
    await delete(tags).go();
    await delete(goalContributions).go();
    await delete(savingsGoals).go();
    await delete(savingsAccounts).go();
    await delete(transactions).go();
    await delete(recurringRules).go();
    await delete(agendaReminders).go();
    await delete(debts).go();
    await delete(categories).go();
    await delete(accounts).go();
    await delete(ledgers).go();
    await _seed();
  });
}
