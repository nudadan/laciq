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

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get kind => intEnum<AccountKind>()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
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

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Budgets,
    RecurringRules,
    AgendaReminders,
    Debts,
    SavingsGoals,
    GoalContributions,
    Tags,
    TransactionTags,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'dompet_pintar'));

  @override
  int get schemaVersion => 9;

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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static DateTime monthStart(DateTime m) => DateTime(m.year, m.month);
  static DateTime monthEnd(DateTime m) => DateTime(m.year, m.month + 1);

  // ---------------------------------------------------------------- seed

  Future<void> _seed() async {
    final now = DateTime.now();
    const expense = <(String, String, String, int)>[
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
    const income = <(String, String, String, int)>[
      ('gaji', 'Gaji', 'salary', 0xFF2E7D32),
      ('bonus', 'Bonus / THR', 'bonus', 0xFF00ACC1),
      ('usaha', 'Usaha', 'business', 0xFFF9A825),
      ('hadiah', 'Hadiah', 'gift', 0xFFAD1457),
      ('lain-masuk', 'Lainnya', 'other', 0xFF757575),
      ('piutang', 'Piutang', 'debt', 0xFF26A69A),
    ];

    await batch((b) {
      b.insertAll(categories, [
        for (final (i, c) in expense.indexed)
          CategoriesCompanion.insert(
            id: 'cat-exp-${c.$1}',
            name: c.$2,
            type: TxType.expense,
            icon: Value(c.$3),
            color: c.$4,
            sortOrder: Value(i),
            updatedAt: now,
          ),
        for (final (i, c) in income.indexed)
          CategoriesCompanion.insert(
            id: 'cat-inc-${c.$1}',
            name: c.$2,
            type: TxType.income,
            icon: Value(c.$3),
            color: c.$4,
            sortOrder: Value(i),
            updatedAt: now,
          ),
      ]);
      b.insert(
        accounts,
        AccountsCompanion.insert(
          id: 'acc-tunai',
          name: 'Tunai',
          kind: AccountKind.cash,
          updatedAt: now,
        ),
      );
    });
  }

  // ------------------------------------------------------------ accounts

  /// Saldo dompet. Yang diarsipkan disembunyikan (dan tidak ikut Total Saldo)
  /// kecuali [includeArchived]; bila ikut, ia berada di urutan paling bawah.
  Stream<List<AccountBalance>> watchAccountBalances({
    bool includeArchived = false,
  }) {
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
      ${includeArchived ? '' : 'WHERE a.archived = 0'}
      ORDER BY a.archived, a.name COLLATE NOCASE
      ''',
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

  /// Nama harus unik (tanpa membedakan huruf besar/kecil), termasuk terhadap
  /// dompet yang diarsipkan, agar tidak membingungkan saat dipulihkan.
  Future<void> _ensureAccountNameFree(String name, {String? exceptId}) async {
    final clash = (await select(accounts).get()).where(
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
  }) async {
    final clean = _cleanAccountName(name);
    _checkInitialBalance(initialBalance);
    await transaction(() async {
      await _ensureAccountNameFree(clean);
      await into(accounts).insert(
        AccountsCompanion.insert(
          id: _uuid.v7(),
          name: clean,
          kind: kind,
          initialBalance: Value(initialBalance),
          updatedAt: DateTime.now(),
        ),
      );
    });
  }

  /// Mengubah nama, jenis, dan saldo awal. Mengubah saldo awal langsung
  /// mengubah saldo dompet (saldo = saldo awal + transaksi).
  Future<void> updateAccount({
    required String id,
    required String name,
    required AccountKind kind,
    required int initialBalance,
  }) async {
    final clean = _cleanAccountName(name);
    _checkInitialBalance(initialBalance);
    await transaction(() async {
      await _ensureAccountNameFree(clean, exceptId: id);
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
        final active = await (select(
          accounts,
        )..where((a) => a.archived.equals(false))).get();
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
  Stream<List<Category>> watchCategories(
    TxType type, {
    bool includeArchived = false,
  }) {
    return (select(categories)
          ..where(
            (c) =>
                c.type.equalsValue(type) &
                (includeArchived
                    ? const Constant(true)
                    : c.archived.equals(false)),
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

  /// Nama harus unik per jenis (tanpa membedakan huruf besar/kecil), termasuk
  /// terhadap kategori yang diarsipkan, agar tidak membingungkan saat dipulihkan.
  Future<void> _ensureNameFree(
    TxType type,
    String name, {
    String? exceptId,
  }) async {
    final same = await (select(
      categories,
    )..where((c) => c.type.equalsValue(type))).get();
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
    String? parentId, {
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
  }) async {
    if (type == TxType.transfer) {
      throw const CategoryException('Transfer tidak memakai kategori.');
    }
    final clean = _cleanCategoryName(name);
    return transaction(() async {
      await _ensureNameFree(type, clean);
      await _checkParent(type, parentId);
      final last =
          await (select(categories)
                ..where((c) => c.type.equalsValue(type))
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
      await _ensureNameFree(current.type, clean, exceptId: id);
      await _checkParent(current.type, parentId, selfId: id);
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
                      c.archived.equals(false),
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

  Future<void> setTransactionDeleted(String id, {required bool deleted}) {
    final now = DateTime.now();
    return (update(transactions)..where((t) => t.id.equals(id))).write(
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

  Stream<List<RuleView>> watchRecurringRules() {
    final toAccount = alias(accounts, 'to_acc');
    final query =
        select(recurringRules).join([
          innerJoin(accounts, accounts.id.equalsExp(recurringRules.accountId)),
          leftOuterJoin(
            categories,
            categories.id.equalsExp(recurringRules.categoryId),
          ),
          leftOuterJoin(
            toAccount,
            toAccount.id.equalsExp(recurringRules.transferToAccountId),
          ),
        ])..orderBy([
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
  Future<int> generateDueRecurring({DateTime? now, int maxPerRule = 1000}) {
    return transaction(() async {
      final today = dateOnly(now ?? DateTime.now());
      var created = 0;
      final rules = await (select(
        recurringRules,
      )..where((r) => r.active.equals(true))).get();

      for (final rule in rules) {
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
    final trimmedNote = note?.trim();
    await into(agendaReminders).insert(
      AgendaRemindersCompanion.insert(
        id: id,
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

  Stream<List<AgendaReminder>> watchAgendaReminders() {
    return (select(agendaReminders)..orderBy([
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
  _txQuery({DateTime? from, DateTime? to, bool newestFirst = true}) {
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

  Stream<List<TxView>> watchTransactions(DateTime month) {
    final q = _txQuery(from: monthStart(month), to: monthEnd(month));
    return q.query.watch().map((rows) => rows.map(q.map).toList());
  }

  /// Untuk ekspor: urut dari yang terlama. Tanpa argumen = seluruh riwayat.
  Future<List<TxView>> getTransactions({DateTime? from, DateTime? to}) async {
    final q = _txQuery(from: from, to: to, newestFirst: false);
    return (await q.query.get()).map(q.map).toList();
  }

  // ------------------------------------------------------ utang/piutang

  Future<String> addDebt({
    required DebtType type,
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
    final now = DateTime.now();
    final id = _uuid.v7();
    final trimmedNote = note?.trim();
    await into(debts).insert(
      DebtsCompanion.insert(
        id: id,
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

  Stream<List<Debt>> watchDebts() {
    return (select(debts)..orderBy([
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

  Stream<MonthTotals> watchTotals(DateTime month) {
    return customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 0 THEN amount END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 1 THEN amount END), 0) AS expense
      FROM transactions
      WHERE deleted_at IS NULL AND date >= ? AND date < ?
      ''',
      variables: [
        Variable.withDateTime(monthStart(month)),
        Variable.withDateTime(monthEnd(month)),
      ],
      readsFrom: {transactions},
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
  }) {
    final start = DateTime(endMonth.year, endMonth.month - months + 1);
    return customSelect(
      '''
      SELECT type, amount, date FROM transactions
      WHERE deleted_at IS NULL AND type IN (0, 1) AND date >= ? AND date < ?
      ''',
      variables: [
        Variable.withDateTime(monthStart(start)),
        Variable.withDateTime(monthEnd(endMonth)),
      ],
      readsFrom: {transactions},
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

  Stream<List<CategorySpend>> watchExpenseByCategory(DateTime month) {
    return customSelect(
      '''
      SELECT c.id AS id, c.name AS name, c.icon AS icon, c.color AS color,
             SUM(t.amount) AS total
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.deleted_at IS NULL AND t.type = 1 AND t.date >= ? AND t.date < ?
      GROUP BY c.id
      ORDER BY total DESC
      ''',
      variables: [
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
  }) {
    final start = DateTime(endMonth.year, endMonth.month - months + 1);
    return customSelect(
      '''
      SELECT c.id AS id, c.name AS name, c.icon AS icon, c.color AS color,
             t.amount AS amount, t.date AS date
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.deleted_at IS NULL AND t.type = 1 AND t.date >= ? AND t.date < ?
      ''',
      variables: [
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
  Stream<List<GoalView>> watchGoals() {
    return customSelect(
      'SELECT g.*, $_savedSql AS saved FROM savings_goals g '
      'ORDER BY g.archived, g.created_at, g.id',
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
  }) async {
    final clean = _cleanGoalName(name);
    _checkTarget(targetAmount);
    final now = DateTime.now();
    final id = _uuid.v7();
    await into(savingsGoals).insert(
      SavingsGoalsCompanion.insert(
        id: id,
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
  Stream<List<BudgetProgress>> watchBudgetProgress(DateTime month) {
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
      ORDER BY c.sort_order
      ''',
      variables: [
        Variable.withDateTime(monthStart(month)),
        Variable.withDateTime(monthEnd(month)),
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
    await delete(transactions).go();
    await delete(recurringRules).go();
    await delete(agendaReminders).go();
    await delete(debts).go();
    await delete(categories).go();
    await delete(accounts).go();
    await _seed();
  });
}
