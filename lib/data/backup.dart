import 'dart:convert';

import 'database.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Isi backup yang sudah divalidasi penuh, siap dipulihkan.
class BackupData {
  const BackupData({
    required this.exportedAt,
    this.ledgers = const [],
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.budgets,
    this.recurringRules = const [],
    this.savingsGoals = const [],
    this.goalContributions = const [],
    this.tags = const [],
    this.transactionTags = const [],
    this.agendaReminders = const [],
    this.debts = const [],
    this.savingsAccounts = const [],
  });

  final DateTime? exportedAt;

  /// Buku kas. Backup lama (format < 7) tidak punya daftar ini; `parse` mengisinya
  /// dengan Buku Utama. Kosong hanya bila `BackupData` dibuat langsung (mis. tes),
  /// dan `restore` menambahkan Buku Utama bawaan.
  final List<Ledger> ledgers;
  final List<Account> accounts;
  final List<Category> categories;
  final List<TxEntry> transactions;
  final List<Budget> budgets;
  final List<RecurringRule> recurringRules;
  final List<SavingsGoal> savingsGoals;
  final List<GoalContribution> goalContributions;
  final List<Tag> tags;
  final List<TransactionTag> transactionTags;
  final List<AgendaReminder> agendaReminders;
  final List<Debt> debts;
  final List<SavingsAccount> savingsAccounts;

  int get activeTransactionCount =>
      transactions.where((t) => t.deletedAt == null).length;
}

/// Backup berupa JSON berversi, bukan salinan file SQLite: formatnya tidak
/// bergantung pada versi skema internal dan bisa divalidasi sebelum menyentuh
/// data yang ada.
///
/// PERHATIAN: file backup TIDAK terenkripsi dan berisi seluruh data keuangan.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const formatName = 'dompet_pintar_backup';

  /// v2 menambah `recurringRules`, v3 menambah `savingsGoals` dan
  /// `goalContributions`, v4 menambah `parentId` di kategori (sub-kategori)
  /// serta `tags`/`transactionTags`, v5 menambah `agendaReminders`, v6
  /// menambah `debts` (utang/piutang), v7 menambah `ledgers` (multi buku kas)
  /// dan `ledgerId` di dompet/kategori/target/agenda/utang, v8 menambah
  /// `savingsAccounts` (tabungan) dan `savingsId` di transaksi, v9 menambah
  /// `reportGroup` di kategori dan `kind` di buku kas (laporan Laba Rugi). Backup
  /// versi lama tetap bisa dipulihkan: semua isinya masuk ke Buku Utama, kelompok
  /// laporan kosong (= bawaan jenis) dan buku bersifat pribadi.
  static const formatVersion = 9;

  Future<String> export() async {
    final ledgersList = await _db.select(_db.ledgers).get();
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final transactions = await _db.select(_db.transactions).get();
    final budgets = await _db.select(_db.budgets).get();
    final rules = await _db.select(_db.recurringRules).get();
    final goals = await _db.select(_db.savingsGoals).get();
    final contributions = await _db.select(_db.goalContributions).get();
    final tags = await _db.select(_db.tags).get();
    final transactionTags = await _db.select(_db.transactionTags).get();
    final agenda = await _db.select(_db.agendaReminders).get();
    final debtsList = await _db.select(_db.debts).get();
    final savingsList = await _db.select(_db.savingsAccounts).get();
    return const JsonEncoder.withIndent(' ').convert({
      'format': formatName,
      'version': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'ledgers': [for (final e in ledgersList) e.toJson()],
      'accounts': [for (final e in accounts) e.toJson()],
      'categories': [for (final e in categories) e.toJson()],
      'transactions': [for (final e in transactions) e.toJson()],
      'budgets': [for (final e in budgets) e.toJson()],
      'recurringRules': [for (final e in rules) e.toJson()],
      'savingsGoals': [for (final e in goals) e.toJson()],
      'goalContributions': [for (final e in contributions) e.toJson()],
      'tags': [for (final e in tags) e.toJson()],
      'transactionTags': [for (final e in transactionTags) e.toJson()],
      'agendaReminders': [for (final e in agenda) e.toJson()],
      'debts': [for (final e in debtsList) e.toJson()],
      'savingsAccounts': [for (final e in savingsList) e.toJson()],
    });
  }

  /// Memvalidasi dan mengurai tanpa mengubah database. Melempar
  /// [BackupException] dengan pesan yang bisa langsung ditampilkan.
  static BackupData parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const BackupException('File bukan backup LaciQ yang valid.');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != formatName) {
      throw const BackupException('File bukan backup LaciQ yang valid.');
    }
    final Map<String, dynamic> root = decoded;
    final version = root['version'];
    if (version is! int || version < 1) {
      throw const BackupException('Versi backup tidak dikenali.');
    }
    if (version > formatVersion) {
      throw const BackupException(
        'Backup ini dibuat oleh versi aplikasi yang lebih baru. '
        'Perbarui aplikasi terlebih dahulu.',
      );
    }

    try {
      // [optional]: kunci yang tidak ada di backup versi lama dianggap kosong.
      // [withLedger]: backup format < 7 tidak punya `ledgerId`; barisnya masuk
      // ke Buku Utama.
      List<T> read<T>(
        String key,
        T Function(Map<String, dynamic>) from, {
        bool optional = false,
        bool withLedger = false,
        Map<String, dynamic> defaults = const {},
      }) => [
        for (final e
            in (root[key] ?? (optional ? const [] : null)) as List<dynamic>)
          from({
            if (withLedger) 'ledgerId': kMainLedgerId,
            ...defaults,
            ...(e as Map<String, dynamic>),
          }),
      ];

      // `kind` baru ada sejak backup v9; 0 = pribadi (LedgerKind.personal).
      final ledgersRead = read(
        'ledgers',
        Ledger.fromJson,
        optional: true,
        defaults: {'kind': LedgerKind.personal.index},
      );
      final data = BackupData(
        exportedAt: DateTime.tryParse('${root['exportedAt']}')?.toLocal(),
        ledgers: ledgersRead.isEmpty
            ? [_defaultMainLedger(DateTime.now())]
            : ledgersRead,
        accounts: read('accounts', Account.fromJson, withLedger: true),
        categories: read('categories', Category.fromJson, withLedger: true),
        transactions: read('transactions', TxEntry.fromJson),
        budgets: read('budgets', Budget.fromJson),
        recurringRules: read(
          'recurringRules',
          RecurringRule.fromJson,
          optional: true,
        ),
        savingsGoals: read(
          'savingsGoals',
          SavingsGoal.fromJson,
          optional: true,
          withLedger: true,
        ),
        goalContributions: read(
          'goalContributions',
          GoalContribution.fromJson,
          optional: true,
        ),
        tags: read('tags', Tag.fromJson, optional: true),
        transactionTags: read(
          'transactionTags',
          TransactionTag.fromJson,
          optional: true,
        ),
        agendaReminders: read(
          'agendaReminders',
          AgendaReminder.fromJson,
          optional: true,
          withLedger: true,
        ),
        debts: read('debts', Debt.fromJson, optional: true, withLedger: true),
        savingsAccounts: read(
          'savingsAccounts',
          SavingsAccount.fromJson,
          optional: true,
          withLedger: true,
        ),
      );
      _checkIntegrity(data);
      return data;
    } on BackupException {
      rethrow;
    } catch (_) {
      // TypeError/FormatException/dst. dari data yang rusak atau dimodifikasi.
      throw const BackupException('Isi backup rusak atau tidak lengkap.');
    }
  }

  /// Buku Utama bawaan, untuk backup lama dan untuk `restore` bila daftar buku kosong.
  static Ledger _defaultMainLedger(DateTime now) => Ledger(
    id: kMainLedgerId,
    name: 'Buku Utama',
    icon: 'savings',
    color: 0xFF1E88E5,
    sortOrder: 0,
    archived: false,
    kind: LedgerKind.personal,
    createdAt: now,
    updatedAt: now,
  );

  /// Semua yang non-null harus berada di buku yang sama dengan [base].
  static bool _sameLedger(String base, String? a, String? b) =>
      (a == null || a == base) && (b == null || b == base);

  static BackupException _inconsistent(String detail) =>
      BackupException('Isi backup rusak atau tidak konsisten ($detail).');

  /// Aturan yang sama dengan `AppDatabase._checkTxFields`: transfer punya
  /// dompet tujuan yang berbeda dan tanpa kategori; selain itu punya kategori
  /// yang sejenis dan tanpa dompet tujuan. [categoryTypes] sudah pasti memuat
  /// setiap `categoryId` (referensi digantung diperiksa lebih dulu).
  static void _checkShape(
    String what,
    TxType type,
    String accountId,
    String? categoryId,
    String? transferToAccountId,
    Map<String, TxType> categoryTypes,
  ) {
    if (type == TxType.transfer) {
      if (transferToAccountId == null) {
        throw _inconsistent('$what transfer tanpa dompet tujuan');
      }
      if (transferToAccountId == accountId) {
        throw _inconsistent('$what transfer ke dompet yang sama');
      }
      if (categoryId != null) {
        throw _inconsistent('$what transfer memakai kategori');
      }
    } else {
      if (categoryId == null) throw _inconsistent('$what tanpa kategori');
      if (transferToAccountId != null) {
        throw _inconsistent('$what bukan transfer tetapi punya dompet tujuan');
      }
      if (categoryTypes[categoryId] != type) {
        throw _inconsistent('$what memakai kategori berjenis lain');
      }
    }
  }

  static void _checkIntegrity(BackupData d) {
    const corrupt = BackupException('Isi backup rusak atau tidak konsisten.');
    // Buku kas: ID unik, Buku Utama wajib ada dan tidak diarsipkan, dan setiap
    // `ledgerId` merujuk buku yang ada (kolomnya tanpa foreign key).
    final ledgerIds = {for (final l in d.ledgers) l.id};
    if (ledgerIds.length != d.ledgers.length ||
        !d.ledgers.any((l) => l.id == kMainLedgerId && !l.archived)) {
      throw corrupt;
    }
    final accountLedger = {for (final a in d.accounts) a.id: a.ledgerId};
    final categoryLedger = {for (final c in d.categories) c.id: c.ledgerId};
    for (final id in [
      ...accountLedger.values,
      ...categoryLedger.values,
      for (final g in d.savingsGoals) g.ledgerId,
      for (final a in d.agendaReminders) a.ledgerId,
      for (final debt in d.debts) debt.ledgerId,
      for (final s in d.savingsAccounts) s.ledgerId,
    ]) {
      if (!ledgerIds.contains(id)) throw corrupt;
    }
    final accountIds = {for (final a in d.accounts) a.id};
    final categoryIds = {for (final c in d.categories) c.id};
    if (accountIds.length != d.accounts.length ||
        categoryIds.length != d.categories.length ||
        {for (final t in d.transactions) t.id}.length !=
            d.transactions.length ||
        {for (final b in d.budgets) b.categoryId}.length != d.budgets.length) {
      throw corrupt; // ID ganda
    }
    for (final t in d.transactions) {
      if (t.amount <= 0 ||
          !accountIds.contains(t.accountId) ||
          (t.categoryId != null && !categoryIds.contains(t.categoryId)) ||
          (t.transferToAccountId != null &&
              !accountIds.contains(t.transferToAccountId))) {
        throw corrupt;
      }
      if (!_sameLedger(
        accountLedger[t.accountId]!,
        categoryLedger[t.categoryId],
        accountLedger[t.transferToAccountId],
      )) {
        throw _inconsistent('transaksi lintas buku kas');
      }
    }
    for (final b in d.budgets) {
      if (b.amount <= 0 || !categoryIds.contains(b.categoryId)) throw corrupt;
    }
    // parentId: harus ada, bukan diri sendiri, sejenis, dan satu tingkat saja
    // (induknya tidak boleh punya induk lagi -> tidak ada cucu).
    for (final c in d.categories) {
      final group = c.reportGroup;
      // Kelompok laporan harus cocok dengan jenis, dan sub-kategori tidak punya
      // kelompok sendiri (mengikuti induknya).
      if (group != null && (c.parentId != null || !group.allowedFor(c.type))) {
        throw corrupt;
      }
      final parentId = c.parentId;
      if (parentId == null) continue;
      if (parentId == c.id || !categoryIds.contains(parentId)) throw corrupt;
      final parent = d.categories.firstWhere((p) => p.id == parentId);
      if (parent.type != c.type ||
          parent.parentId != null ||
          parent.ledgerId != c.ledgerId) {
        throw corrupt;
      }
    }
    final tagIds = {for (final t in d.tags) t.id};
    if (tagIds.length != d.tags.length) throw corrupt; // ID ganda
    final transactionIds = {for (final t in d.transactions) t.id};
    final ttPairs = <String>{};
    for (final tt in d.transactionTags) {
      if (!transactionIds.contains(tt.transactionId) ||
          !tagIds.contains(tt.tagId) ||
          !ttPairs.add('${tt.transactionId}|${tt.tagId}')) {
        throw corrupt; // referensi menggantung atau pasangan ganda
      }
    }
    // Bentuk transaksi dan aturan berulang. Kolomnya nullable, jadi SQLite tidak
    // menolak yang menyimpang: data seperti itu masuk diam-diam lalu tampil
    // sebagai angka yang tidak cocok (mis. pengeluaran tanpa kategori hilang
    // dari donut tetapi ikut di total).
    final categoryTypes = {for (final c in d.categories) c.id: c.type};
    for (final t in d.transactions) {
      _checkShape(
        'transaksi',
        t.type,
        t.accountId,
        t.categoryId,
        t.transferToAccountId,
        categoryTypes,
      );
    }
    for (final r in d.recurringRules) {
      _checkShape(
        'aturan berulang',
        r.type,
        r.accountId,
        r.categoryId,
        r.transferToAccountId,
        categoryTypes,
      );
    }
    // Aplikasi selalu menyisakan minimal satu dompet dan satu kategori aktif per
    // jenis di setiap buku yang aktif. Tanpa itu, setelah restore tidak ada yang
    // bisa dipilih di form.
    for (final ledger in d.ledgers.where((l) => !l.archived)) {
      if (!d.accounts.any((a) => a.ledgerId == ledger.id && !a.archived)) {
        throw const BackupException(
          'Backup harus memuat minimal satu dompet aktif.',
        );
      }
      for (final type in [TxType.income, TxType.expense]) {
        if (!d.categories.any(
          (c) => c.ledgerId == ledger.id && c.type == type && !c.archived,
        )) {
          throw const BackupException(
            'Backup harus memuat minimal satu kategori aktif untuk tiap jenis.',
          );
        }
      }
    }
    if ({for (final r in d.recurringRules) r.id}.length !=
        d.recurringRules.length) {
      throw corrupt;
    }
    for (final r in d.recurringRules) {
      if (r.amount <= 0 ||
          r.nextIndex < 0 ||
          !accountIds.contains(r.accountId) ||
          (r.categoryId != null && !categoryIds.contains(r.categoryId)) ||
          (r.transferToAccountId != null &&
              !accountIds.contains(r.transferToAccountId))) {
        throw corrupt;
      }
      if (!_sameLedger(
        accountLedger[r.accountId]!,
        categoryLedger[r.categoryId],
        accountLedger[r.transferToAccountId],
      )) {
        throw _inconsistent('aturan berulang lintas buku kas');
      }
    }
    final goalIds = {for (final g in d.savingsGoals) g.id};
    if (goalIds.length != d.savingsGoals.length ||
        {for (final c in d.goalContributions) c.id}.length !=
            d.goalContributions.length ||
        d.savingsGoals.any((g) => g.targetAmount <= 0)) {
      throw corrupt;
    }
    final saved = <String, int>{};
    for (final c in d.goalContributions) {
      if (c.amount <= 0 || !goalIds.contains(c.goalId)) throw corrupt;
      if (c.deletedAt == null) {
        saved[c.goalId] =
            (saved[c.goalId] ?? 0) +
            (c.kind == ContributionKind.deposit ? c.amount : -c.amount);
      }
    }
    // Dana terkumpul tidak boleh negatif: pasti file yang dimodifikasi/rusak.
    if (saved.values.any((v) => v < 0)) throw corrupt;

    // Agenda tidak punya foreign key ke akun/kategori (murni pengingat +
    // estimasi opsional, lihat AgendaReminders di database.dart) — cukup ID
    // tidak ganda dan estimasi (kalau ada) positif.
    if ({for (final a in d.agendaReminders) a.id}.length !=
        d.agendaReminders.length) {
      throw corrupt;
    }
    for (final a in d.agendaReminders) {
      if (a.nextIndex < 0 ||
          (a.estimatedAmount != null && a.estimatedAmount! <= 0)) {
        throw corrupt;
      }
    }

    // Debts (utang/piutang) juga tanpa foreign key ke akun (opsional, lihat
    // Debts di database.dart) — cukup ID tidak ganda, pokok positif, dan
    // paidAmount tidak negatif (boleh melebihi pokok/overpay, lihat DebtView).
    if ({for (final debt in d.debts) debt.id}.length != d.debts.length) {
      throw corrupt;
    }
    for (final debt in d.debts) {
      if (debt.amount <= 0 || debt.paidAmount < 0) throw corrupt;
    }

    // Tabungan: ID tidak ganda; setiap transaksi bertanda tabungan merujuk
    // tabungan yang ada, bukan transfer, searah (pengeluaran = setoran,
    // pemasukan = penarikan), dan satu buku dengan tabungannya; saldo tidak
    // boleh negatif (file yang dimodifikasi/rusak).
    final savingsLedger = {for (final s in d.savingsAccounts) s.id: s.ledgerId};
    if (savingsLedger.length != d.savingsAccounts.length) throw corrupt;
    final savingsBalance = <String, int>{};
    for (final t in d.transactions) {
      final sid = t.savingsId;
      if (sid == null) continue;
      if (!savingsLedger.containsKey(sid) || t.type == TxType.transfer) {
        throw corrupt;
      }
      if (accountLedger[t.accountId] != savingsLedger[sid]) {
        throw _inconsistent('transaksi tabungan lintas buku kas');
      }
      if (t.deletedAt == null) {
        savingsBalance[sid] =
            (savingsBalance[sid] ?? 0) +
            (t.type == TxType.expense ? t.amount : -t.amount);
      }
    }
    if (savingsBalance.values.any((v) => v < 0)) throw corrupt;
  }

  /// MENGGANTI seluruh data yang ada. Berjalan dalam satu transaksi: jika ada
  /// yang gagal, semuanya dibatalkan dan data lama tetap utuh.
  ///
  /// `defer_foreign_keys` menunda semua pemeriksaan FK sampai transaksi ini
  /// selesai (otomatis kembali OFF setelahnya) — tanpa ini, `categories`
  /// (kolom `parent_id` menunjuk ke dirinya sendiri) butuh urutan hapus/insert
  /// yang rumit karena SQLite memeriksa FK per baris, bukan per transaksi.
  Future<void> restore(BackupData data) {
    return _db.transaction(() async {
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.transactionTags).go();
      await _db.delete(_db.tags).go();
      await _db.delete(_db.goalContributions).go();
      await _db.delete(_db.savingsGoals).go();
      await _db.delete(_db.savingsAccounts).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.recurringRules).go();
      await _db.delete(_db.agendaReminders).go();
      await _db.delete(_db.debts).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.accounts).go();
      await _db.delete(_db.ledgers).go();

      final ledgerRows = data.ledgers.any((l) => l.id == kMainLedgerId)
          ? data.ledgers
          : [_defaultMainLedger(DateTime.now()), ...data.ledgers];
      await _db.batch((b) {
        b.insertAll(_db.ledgers, [
          for (final e in ledgerRows) e.toCompanion(false),
        ]);
        b.insertAll(_db.accounts, [
          for (final e in data.accounts) e.toCompanion(false),
        ]);
        b.insertAll(_db.categories, [
          for (final e in data.categories) e.toCompanion(false),
        ]);
        b.insertAll(_db.savingsGoals, [
          for (final e in data.savingsGoals) e.toCompanion(false),
        ]);
        b.insertAll(_db.goalContributions, [
          for (final e in data.goalContributions) e.toCompanion(false),
        ]);
        b.insertAll(_db.recurringRules, [
          for (final e in data.recurringRules) e.toCompanion(false),
        ]);
        b.insertAll(_db.transactions, [
          for (final e in data.transactions) e.toCompanion(false),
        ]);
        b.insertAll(_db.budgets, [
          for (final e in data.budgets) e.toCompanion(false),
        ]);
        b.insertAll(_db.tags, [
          for (final e in data.tags) e.toCompanion(false),
        ]);
        b.insertAll(_db.transactionTags, [
          for (final e in data.transactionTags) e.toCompanion(false),
        ]);
        b.insertAll(_db.agendaReminders, [
          for (final e in data.agendaReminders) e.toCompanion(false),
        ]);
        b.insertAll(_db.debts, [
          for (final e in data.debts) e.toCompanion(false),
        ]);
        b.insertAll(_db.savingsAccounts, [
          for (final e in data.savingsAccounts) e.toCompanion(false),
        ]);
      });
    });
  }
}
