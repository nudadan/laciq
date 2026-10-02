import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:intl/intl.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/recurrence.dart';
import '../ai/ai_extraction_service.dart';
import '../ledgers/ledgers_page.dart' show RecordingInLedgerBanner;
import '../security/lock_providers.dart' show keyValueStoreProvider;
import '../subscription/subscription_page.dart';
import '../subscription/subscription_plans.dart' show ActiveTier;
import 'receipt_scanner.dart' show ScannedReceipt;

enum _Mode { create, editTx, editRule, executeAgenda, payDebt }

/// Satu form untuk lima keperluan:
/// - buat baru (opsional langsung dijadikan berulang),
/// - ubah satu transaksi ([editingTx]),
/// - ubah aturan berulang ([editingRule]),
/// - catat transaksi nyata dari eksekusi agenda ([fromAgenda]),
/// - catat pembayaran/penerimaan utang-piutang ([fromDebtPayment]).
///
/// Menutup halaman dengan `String?` pesan konfirmasi untuk ditampilkan induk.
class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({
    super.key,
    this.editingTx,
    this.editingRule,
    this.initialFrequency,
    this.fromAgenda,
    this.fromDebtPayment,
  }) : assert(
         (editingTx == null ? 0 : 1) +
                 (editingRule == null ? 0 : 1) +
                 (fromAgenda == null ? 0 : 1) +
                 (fromDebtPayment == null ? 0 : 1) <=
             1,
         'Hanya satu mode yang boleh diisi.',
       );

  final TxEntry? editingTx;
  final RecurringRule? editingRule;

  /// Untuk membuat baru dengan pengulangan sudah terpilih.
  final Frequency? initialFrequency;

  /// Eksekusi agenda: nominal/catatan diprefill dari sini, tapi bebas
  /// disesuaikan sebelum disimpan (lihat [AppDatabase.executeAgenda]).
  final AgendaReminder? fromAgenda;

  /// Catat pembayaran (utang) atau penerimaan (piutang): nominal diprefill
  /// dari sisa (`amount - paidAmount`), tipe transaksi terkunci sesuai
  /// [DebtType] tapi nominal bebas disesuaikan (cicilan) — lihat
  /// [AppDatabase.recordDebtPayment].
  final Debt? fromDebtPayment;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _newTagCtrl = TextEditingController();
  late TxType _type;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  late DateTime _date;
  DateTime? _endDate;
  Frequency? _frequency;
  bool _reminderEnabled = false;
  int _reminderDaysBefore = 1;
  String? _error;
  List<String> _tagIds = [];
  bool _tagsLoaded = false;

  /// Diisi lewat [_scanReceipt] (fitur Premium) — path relatif foto struk
  /// yang sudah disimpan lokal, ikut disimpan ke `Transactions.receiptPath`.
  String? _receiptPath;

  /// Sedang menunggu hasil ekstraksi AI (Ultimate) setelah scan.
  bool _aiBusy = false;

  _Mode get _mode => widget.editingRule != null
      ? _Mode.editRule
      : widget.editingTx != null
      ? _Mode.editTx
      : widget.fromAgenda != null
      ? _Mode.executeAgenda
      : widget.fromDebtPayment != null
      ? _Mode.payDebt
      : _Mode.create;

  @override
  void initState() {
    super.initState();
    final tx = widget.editingTx;
    final rule = widget.editingRule;
    final agenda = widget.fromAgenda;
    final debt = widget.fromDebtPayment;
    if (tx != null) {
      _type = tx.type;
      _amountCtrl.text = groupedNumber(tx.amount);
      _accountId = tx.accountId;
      _toAccountId = tx.transferToAccountId;
      _categoryId = tx.categoryId;
      _date = tx.date;
      _noteCtrl.text = tx.note ?? '';
    } else if (rule != null) {
      _type = rule.type;
      _amountCtrl.text = groupedNumber(rule.amount);
      _accountId = rule.accountId;
      _toAccountId = rule.transferToAccountId;
      _categoryId = rule.categoryId;
      _date = rule.startDate;
      _endDate = rule.endDate;
      _frequency = rule.frequency;
      _reminderEnabled = rule.reminderEnabled;
      _reminderDaysBefore = rule.reminderDaysBefore;
      _noteCtrl.text = rule.note ?? '';
    } else if (agenda != null) {
      _type = TxType.expense;
      _date = DateTime.now();
      if (agenda.estimatedAmount != null) {
        _amountCtrl.text = groupedNumber(agenda.estimatedAmount!);
      }
      _noteCtrl.text = agenda.title;
    } else if (debt != null) {
      _type = debt.type == DebtType.debt ? TxType.expense : TxType.income;
      _date = DateTime.now();
      final remaining = debt.amount - debt.paidAmount;
      if (remaining > 0) _amountCtrl.text = groupedNumber(remaining);
      _accountId = debt.accountId;
      _noteCtrl.text = debt.counterpartyName;
      // Kategori "Utang"/"Piutang" (lihat AppDatabase._seed) diprapilih
      // supaya pembayaran mudah dilacak terpisah, tapi tetap bisa diganti
      // pengguna ke kategori lain sebelum simpan.
      _categoryId = debtCategoryId(debt.ledgerId, debt.type);
    } else {
      _type = TxType.expense;
      _date = DateTime.now();
      _frequency = widget.initialFrequency;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _newTagCtrl.dispose();
    super.dispose();
  }

  /// Kategori tersusun: tiap induk diikuti langsung oleh sub-kategorinya.
  static List<Category> _orderedWithChildren(List<Category> cats) {
    final byParent = <String, List<Category>>{};
    final topLevel = <Category>[];
    for (final c in cats) {
      if (c.parentId == null) {
        topLevel.add(c);
      } else {
        byParent.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }
    final topLevelIds = topLevel.map((c) => c.id).toSet();
    return [
      for (final p in topLevel) ...[p, ...?byParent[p.id]],
      // Sub-kategori yang induknya tidak ikut tampil (mis. sudah diarsipkan).
      for (final e in byParent.entries)
        if (!topLevelIds.contains(e.key)) ...e.value,
    ];
  }

  Future<void> _addTag() async {
    final name = _newTagCtrl.text;
    if (name.trim().isEmpty) return;
    try {
      final id = await ref.read(databaseProvider).addTag(name);
      _newTagCtrl.clear();
      setState(() => _tagIds = [..._tagIds, id]);
    } on TagException catch (e) {
      setState(() => _error = e.message);
    }
  }

  /// Scan struk (OCR, fitur Premium): pilih sumber foto → jalankan scanner →
  /// isi field yang berhasil ditebak. Tebakan yang gagal dibiarkan seperti
  /// semula (bukan dikosongkan), pengguna selalu bisa mengoreksi sebelum
  /// menyimpan. Belum premium: arahkan ke [SubscriptionPage], pola sama
  /// [_ReminderPicker].
  Future<void> _scanReceipt() async {
    final messenger = ScaffoldMessenger.of(context);
    final premium = ref.read(isPremiumProvider).value ?? false;
    if (!premium) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionPage()));
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Kamera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeri'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final ScannedReceipt? picked;
    try {
      picked = await ref.read(receiptScannerProvider).scan(source);
    } catch (e) {
      // Jangan diam: gagal baca foto/OCR harus terlihat supaya pengguna tahu
      // harus mengulang, dan jenis galatnya membantu penelusuran.
      debugPrint('Scan struk gagal: $e');
      if (mounted) {
        final code = e is PlatformException ? e.code : e.runtimeType.toString();
        notify(
          messenger,
          'Scan struk gagal ($code). Coba foto ulang, atau pilih dari Galeri.',
        );
      }
      return;
    }
    if (picked == null || !mounted) return;
    final scanned = picked;
    setState(() {
      if (scanned.amount != null) {
        _amountCtrl.text = groupedNumber(scanned.amount!);
      }
      if (scanned.date != null) _date = scanned.date!;
      if (scanned.noteGuess != null) _noteCtrl.text = scanned.noteGuess!;
      _receiptPath = scanned.photoPath;
    });
    await _enhanceWithAi(scanned);
  }

  static const _aiConsentKey = 'ai_extraction_consent';

  /// Teks struk keluar dari perangkat ke server AI — minta izin sekali,
  /// diingat. Menolak = lewati AI kali ini saja (heuristik tetap dipakai).
  Future<bool> _ensureAiConsent() async {
    final store = ref.read(keyValueStoreProvider);
    if (await store.read(_aiConsentKey) == 'granted') return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Isi otomatis dengan AI?'),
        content: const Text(
          'Teks hasil scan struk (bukan fotonya) akan dikirim ke server AI '
          'kami untuk mengenali nama toko, kategori, total, dan tanggal. Tidak '
          'disimpan di server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Lewati'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Izinkan'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await store.write(_aiConsentKey, 'granted');
    return true;
  }

  /// Fitur Ultimate: setelah heuristik on-device mengisi form, minta AI
  /// menebak nama toko + kategori dan timpa HANYA field yang belum diubah
  /// pengguna selama menunggu. Gagal/offline = diam, heuristik tetap berlaku.
  Future<void> _enhanceWithAi(ScannedReceipt scanned) async {
    final rawText = scanned.rawText;
    if (rawText == null || rawText.trim().isEmpty) return;
    if (_type == TxType.transfer) return;
    if (!(ref.read(isUltimateProvider).value ?? false)) return;
    if (!await _ensureAiConsent() || !mounted) return;

    final all = ref.read(allCategoriesProvider(_type)).value ?? const [];
    final byId = {for (final c in all) c.id: c};
    final options = [
      for (final c in all)
        if (!c.archived)
          AiCategoryOption(
            id: c.id,
            label: c.parentId != null && byId[c.parentId] != null
                ? '${byId[c.parentId]!.name} › ${c.name}'
                : c.name,
          ),
    ];
    if (options.isEmpty) return;

    final typeAtStart = _type;
    final noteAtStart = _noteCtrl.text;
    final categoryAtStart = _categoryId;
    final amountAtStart = _amountCtrl.text;
    final dateAtStart = _date;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _aiBusy = true);
    AiReceiptExtraction? result;
    try {
      result = await ref
          .read(aiExtractionServiceProvider)
          .extract(rawText: rawText, categories: options);
    } on AiQuotaExceeded catch (e) {
      if (mounted && !_aiQuotaNoticeShown) {
        _aiQuotaNoticeShown = true;
        notify(
          messenger,
          e.daily
              ? 'Batas scan AI hari ini tercapai. Hasil scan biasa tetap dipakai.'
              : 'Kuota scan AI bulan ini habis. Hasil scan biasa tetap dipakai.',
        );
      }
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
    if (!mounted || result == null || _type != typeAtStart) return;
    final extraction = result;
    // Beri tahu sebelum kuota habis, bukan setelah kena 429. Hanya satu kali,
    // saat sisa tepat 10, supaya tidak berisik.
    final left = extraction.remaining;
    if (left == 10) {
      notify(messenger, 'Sisa scan AI bulan ini: $left');
    }
    setState(() {
      final merchant = extraction.merchant;
      if (merchant != null && _noteCtrl.text == noteAtStart) {
        _noteCtrl.text = merchant;
      }
      final categoryId = extraction.categoryId;
      if (categoryId != null && _categoryId == categoryAtStart) {
        _categoryId = categoryId;
      }
      // Total dan tanggal dari AI menimpa hasil heuristik (itu tujuannya: heuristik
      // bisa salah pada struk berlayout kompleks), tapi TIDAK bila pengguna sudah
      // mengubahnya sendiri selama menunggu.
      final total = extraction.total;
      if (total != null && _amountCtrl.text == amountAtStart) {
        _amountCtrl.text = groupedNumber(total);
      }
      final date = extraction.date;
      if (date != null && _date == dateAtStart) _date = date;
    });
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
    );
  }

  String? _validate(int? amount) {
    if (amount == null || amount <= 0) return 'Masukkan nominal lebih dari 0.';
    if (_accountId == null) return 'Pilih dompet terlebih dahulu.';
    if (_type == TxType.transfer) {
      if (_toAccountId == null) return 'Pilih dompet tujuan.';
      if (_toAccountId == _accountId) {
        return 'Dompet asal dan tujuan tidak boleh sama.';
      }
    } else if (_categoryId == null) {
      return 'Pilih kategori.';
    }
    final end = _endDate;
    if (end != null && dateOnly(end).isBefore(dateOnly(_date))) {
      return 'Tanggal berakhir tidak boleh sebelum tanggal mulai.';
    }
    return null;
  }

  Future<void> _save() async {
    final amount = parseRupiah(_amountCtrl.text);
    final error = _validate(amount);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final db = ref.read(databaseProvider);
    final isTransfer = _type == TxType.transfer;
    final categoryId = isTransfer ? null : _categoryId;
    final toId = isTransfer ? _toAccountId : null;
    String? message;
    try {
      switch (_mode) {
        case _Mode.editTx:
          await db.updateTransaction(
            id: widget.editingTx!.id,
            type: _type,
            amount: amount!,
            accountId: _accountId!,
            categoryId: categoryId,
            transferToAccountId: toId,
            date: _date,
            note: _noteCtrl.text,
          );
          await db.setTransactionTags(widget.editingTx!.id, _tagIds);
          message = 'Perubahan disimpan';
        case _Mode.editRule:
          await db.updateRecurringRule(
            id: widget.editingRule!.id,
            type: _type,
            amount: amount!,
            accountId: _accountId!,
            categoryId: categoryId,
            transferToAccountId: toId,
            note: _noteCtrl.text,
            endDate: _endDate,
            reminderEnabled: _reminderEnabled,
            reminderDaysBefore: _reminderDaysBefore,
          );
          message = 'Perubahan disimpan';
        case _Mode.executeAgenda:
          final txId = await db.executeAgenda(
            agendaId: widget.fromAgenda!.id,
            amount: amount!,
            accountId: _accountId!,
            categoryId: categoryId,
            date: _date,
            note: _noteCtrl.text,
          );
          await db.setTransactionTags(txId, _tagIds);
          message = 'Transaksi dicatat dari agenda';
        case _Mode.payDebt:
          final txId = await db.recordDebtPayment(
            debtId: widget.fromDebtPayment!.id,
            amount: amount!,
            accountId: _accountId!,
            categoryId: categoryId,
            date: _date,
            note: _noteCtrl.text,
          );
          await db.setTransactionTags(txId, _tagIds);
          message = widget.fromDebtPayment!.type == DebtType.debt
              ? 'Pembayaran dicatat'
              : 'Penerimaan dicatat';
        case _Mode.create when _frequency != null:
          await db.addRecurringRule(
            type: _type,
            amount: amount!,
            accountId: _accountId!,
            categoryId: categoryId,
            transferToAccountId: toId,
            frequency: _frequency!,
            startDate: _date,
            endDate: _endDate,
            note: _noteCtrl.text,
            reminderEnabled: _reminderEnabled,
            reminderDaysBefore: _reminderDaysBefore,
          );
          // Kejadian yang sudah jatuh tempo (mis. mulai hari ini) langsung dicatat.
          await ref.read(recurringGeneratorProvider)();
          message = 'Transaksi berulang dibuat';
        case _Mode.create:
          final txId = await db.addTransaction(
            type: _type,
            amount: amount!,
            accountId: _accountId!,
            categoryId: categoryId,
            transferToAccountId: toId,
            date: _date,
            note: _noteCtrl.text,
            receiptPath: _receiptPath,
          );
          await db.setTransactionTags(txId, _tagIds);
      }
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
      return;
    }
    if (!mounted) return;
    // Hanya transaksi baru (bukan ubah/berulang) yang dihitung sebagai momen
    // positif untuk permintaan ulasan. Layanan diambil sebelum pop karena
    // `ref` tidak boleh dipakai setelah widget dibuang.
    final review = _mode == _Mode.create && _frequency == null
        ? ref.read(reviewPromptServiceProvider)
        : null;
    Navigator.of(context).pop(message);
    if (review != null) unawaited(review.onTransactionSaved());
  }

  static String _accountLabel(AccountBalance a) =>
      a.archived ? '${a.name} (diarsipkan)' : a.name;

  @override
  Widget build(BuildContext context) {
    // Dompet yang diarsipkan hanya ikut tampil bila sedang dipilih oleh
    // transaksi/aturan yang diubah, agar tidak hilang diam-diam (dan agar nilai
    // dropdown selalu ada di daftarnya).
    final accounts =
        ref
            .watch(allAccountsProvider)
            .value
            ?.where(
              (a) => !a.archived || a.id == _accountId || a.id == _toAccountId,
            )
            .toList() ??
        const <AccountBalance>[];
    // Default ke dompet pertama begitu data termuat (hanya untuk transaksi baru).
    _accountId ??= accounts.isEmpty ? null : accounts.first.id;
    final isTransfer = _type == TxType.transfer;
    // Kategori yang diarsipkan hanya ikut tampil bila sedang dipilih oleh
    // transaksi yang diubah, agar tidak hilang diam-diam.
    final categories = isTransfer
        ? null
        : _orderedWithChildren(
            ref
                    .watch(allCategoriesProvider(_type))
                    .value
                    ?.where((c) => !c.archived || c.id == _categoryId)
                    .toList() ??
                const <Category>[],
          );
    // Tag hanya berlaku untuk transaksi nyata (bukan transfer, bukan
    // template aturan berulang — RecurringRules tidak punya tag sendiri).
    final showTags =
        !isTransfer &&
        _mode != _Mode.editRule &&
        !(_mode == _Mode.create && _frequency != null);
    final allTags = ref.watch(tagsProvider).value ?? const <Tag>[];
    if (_mode == _Mode.editTx && !_tagsLoaded) {
      final loaded = ref
          .watch(transactionTagsProvider(widget.editingTx!.id))
          .value;
      if (loaded != null) {
        _tagIds = loaded.map((t) => t.id).toList();
        _tagsLoaded = true;
      }
    }
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final mode = _mode;
    final palette = context.palette;
    // Warna nominal mengikuti jenis: pemasukan, pengeluaran, atau transfer.
    final amountColor = switch (_type) {
      TxType.income => palette.income,
      TxType.expense => palette.expense,
      TxType.transfer => palette.transfer,
    };
    final amountStyle = Theme.of(context).textTheme.displaySmall!
        .copyWith(color: amountColor, fontSize: 40);

    final title = switch (mode) {
      _Mode.create => 'Catat Transaksi',
      _Mode.editTx => 'Ubah Transaksi',
      _Mode.editRule => 'Ubah Transaksi Berulang',
      _Mode.executeAgenda => 'Catat dari Agenda',
      _Mode.payDebt =>
        widget.fromDebtPayment!.type == DebtType.debt
            ? 'Catat Pembayaran'
            : 'Catat Penerimaan',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const RecordingInLedgerBanner(),
            if (mode == _Mode.editTx && widget.editingTx!.recurringId != null)
              const _InfoBanner(
                'Transaksi ini dibuat otomatis dari transaksi berulang. '
                'Perubahan hanya berlaku untuk transaksi ini.',
              ),
            if (mode == _Mode.editRule)
              const _InfoBanner(
                'Perubahan berlaku mulai transaksi berikutnya. '
                'Transaksi yang sudah tercatat tidak berubah.',
              ),
            if (mode == _Mode.executeAgenda)
              const _InfoBanner(
                'Nominal diisi dari estimasi agenda — boleh disesuaikan '
                'sebelum disimpan.',
              ),
            if (mode == _Mode.payDebt)
              _InfoBanner(
                'Nominal diisi dari sisa ${widget.fromDebtPayment!.type == DebtType.debt ? 'utang' : 'piutang'} '
                '— boleh disesuaikan untuk pembayaran sebagian.',
              ),
            if (mode == _Mode.create) ...[
              FieldTile(
                leading: Icons.document_scanner_rounded,
                title: 'Scan Struk',
                subtitle: !(ref.watch(isPremiumProvider).value ?? false)
                    ? 'Fitur Premium'
                    : _aiBusy
                    ? 'Mengisi otomatis dengan AI…'
                    : _receiptPath != null
                    ? 'Foto tersimpan'
                    : null,
                trailing: _receiptPath == null
                    ? null
                    : IconButton(
                        tooltip: 'Hapus foto',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _receiptPath = null),
                      ),
                onTap: _scanReceipt,
              ),
              // Pelanggan Premium yang baru scan struk: tawarkan Ultimate (isi
              // toko & kategori otomatis dengan AI). Hanya bila paket Ultimate
              // benar-benar dijual.
              if (_receiptPath != null &&
                  ref.watch(subscriptionTierProvider) == ActiveTier.premium &&
                  (ref.watch(ultimateAvailableProvider).value ?? false))
                const _UltimateUpsell(),
              const SizedBox(height: 16),
            ],
            if (mode != _Mode.executeAgenda && mode != _Mode.payDebt)
              SegmentedButton<TxType>(
                showSelectedIcon: false,
                segments: [
                  for (final t in TxType.values)
                    ButtonSegment(value: t, label: Text(txTypeLabel(t))),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                  _error = null;
                }),
              ),
            const SizedBox(height: 20),
            GlassCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  Text(
                    'Nominal',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Rp',
                        style: amountStyle.copyWith(
                          fontSize: 22,
                          color: amountColor.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // IntrinsicWidth: kolom selebar angkanya, sehingga "Rp"
                      // tetap menempel dan seluruhnya terpusat.
                      Flexible(
                        child: IntrinsicWidth(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 36),
                            child: TextField(
                              controller: _amountCtrl,
                              autofocus: mode == _Mode.create,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                RupiahInputFormatter(),
                              ],
                              style: amountStyle,
                              cursorColor: amountColor,
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: amountStyle.copyWith(
                                  color: scheme.outline,
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!isTransfer) ...[
              Text('Kategori', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in categories ?? const <Category>[])
                    ChoiceChip(
                      avatar: Icon(
                        categoryIcon(c.icon),
                        size: 18,
                        color: Color(c.color),
                      ),
                      // Sub-kategori diberi awalan agar terlihat bernaung di
                      // bawah induknya walau tampil sebaris (Wrap, bukan pohon).
                      label: Text(c.parentId != null ? '↳ ${c.name}' : c.name),
                      selected: _categoryId == c.id,
                      showCheckmark: false,
                      selectedColor: Color(c.color).withValues(alpha: 0.24),
                      side: BorderSide(
                        color: _categoryId == c.id
                            ? Color(c.color)
                            : scheme.outlineVariant,
                      ),
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (showTags) ...[
              Text(
                'Tag (opsional)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in allTags)
                    FilterChip(
                      label: Text(t.name),
                      selected: _tagIds.contains(t.id),
                      onSelected: (sel) => setState(() {
                        _tagIds = sel
                            ? [..._tagIds, t.id]
                            : _tagIds.where((id) => id != t.id).toList();
                      }),
                    ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _newTagCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Tag baru…',
                        prefixIcon: Icon(Icons.add, size: 18),
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: isTransfer ? 'Dari dompet' : 'Dompet',
              ),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(_accountLabel(a))),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            if (isTransfer) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _toAccountId,
                decoration: const InputDecoration(labelText: 'Ke dompet'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(_accountLabel(a)),
                    ),
                ],
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
            ],
            const SizedBox(height: 16),
            if (mode == _Mode.editRule)
              // Jadwal tidak bisa diubah: hanya ditampilkan.
              FieldTile(
                leading: Icons.repeat_rounded,
                title: scheduleDescription(
                  widget.editingRule!.frequency,
                  widget.editingRule!.startDate,
                ),
                subtitle:
                    'Mulai ${DateFormat('d MMM yyyy', 'id_ID').format(_date)}',
              )
            else
              FieldTile(
                leading: Icons.event_rounded,
                title: dateFmt.format(_date),
                subtitle: _frequency != null ? 'Tanggal mulai' : null,
                onTap: () async {
                  final picked = await _pickDate(_date);
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            if (mode == _Mode.create) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<Frequency?>(
                initialValue: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Ulangi',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tidak berulang'),
                  ),
                  // Frequency.once dikecualikan: "tidak berulang" di atas
                  // sudah mewakili transaksi sekali untuk form ini.
                  for (final f in Frequency.values.where(
                    (f) => f != Frequency.once,
                  ))
                    DropdownMenuItem(value: f, child: Text(frequencyLabel(f))),
                ],
                onChanged: (v) => setState(() {
                  _frequency = v;
                  if (v == null) _endDate = null;
                }),
              ),
            ],
            if (_frequency != null) ...[
              const SizedBox(height: 16),
              FieldTile(
                leading: Icons.event_busy_rounded,
                title: _endDate == null
                    ? 'Tanpa tanggal berakhir'
                    : 'Berakhir ${dateFmt.format(_endDate!)}',
                trailing: _endDate == null
                    ? null
                    : IconButton(
                        tooltip: 'Hapus tanggal berakhir',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _endDate = null),
                      ),
                onTap: () async {
                  final picked = await _pickDate(
                    _endDate ?? _date,
                    first: dateOnly(_date),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
              const SizedBox(height: 16),
              _ReminderPicker(
                enabled: _reminderEnabled,
                daysBefore: _reminderDaysBefore,
                onEnabledChanged: (v) => setState(() => _reminderEnabled = v),
                onDaysBeforeChanged: (v) =>
                    setState(() => _reminderDaysBefore = v),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Simpan')),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pengingat sebelum jatuh tempo untuk transaksi berulang (fitur premium).
/// Belum premium: baris upsell yang membuka [SubscriptionPage], bukan
/// disembunyikan total — pola sama tile-tile premium di Pengaturan.
class _ReminderPicker extends ConsumerWidget {
  const _ReminderPicker({
    required this.enabled,
    required this.daysBefore,
    required this.onEnabledChanged,
    required this.onDaysBeforeChanged,
  });

  final bool enabled;
  final int daysBefore;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onDaysBeforeChanged;

  static const _leadOptions = [1, 3, 7];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPremiumProvider).value ?? false;
    if (!premium) {
      return FieldTile(
        leading: Icons.notifications_active_rounded,
        title: 'Ingatkan saya',
        subtitle: 'Fitur Premium',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SubscriptionPage()),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: const Text('Ingatkan saya'),
            value: enabled,
            onChanged: onEnabledChanged,
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: daysBefore,
            decoration: const InputDecoration(
              labelText: 'Ingatkan berapa hari sebelumnya',
            ),
            items: [
              for (final d in _leadOptions)
                DropdownMenuItem(value: d, child: Text('H-$d')),
            ],
            onChanged: (v) {
              if (v != null) onDaysBeforeChanged(v);
            },
          ),
        ],
      ],
    );
  }
}

/// Ajakan halus ke Ultimate di bawah tile Scan Struk untuk pelanggan Premium.
/// Aturan agar tidak mengganggu: paling banyak sekali per sesi aplikasi, dan
/// berhenti tampil setelah ditutup [_maxDismissals] kali (tersimpan).
class _UltimateUpsell extends ConsumerStatefulWidget {
  const _UltimateUpsell();

  @override
  ConsumerState<_UltimateUpsell> createState() => _UltimateUpsellState();
}

class _UltimateUpsellState extends ConsumerState<_UltimateUpsell> {
  static const _dismissKey = 'ultimate_upsell_dismissals';
  static const _maxDismissals = 2;
  static var _shownThisSession = false;

  var _visible = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    if (_shownThisSession) return;
    final dismissed =
        int.tryParse(
          await ref.read(keyValueStoreProvider).read(_dismissKey) ?? '',
        ) ??
        0;
    if (dismissed >= _maxDismissals || !mounted) return;
    _shownThisSession = true;
    setState(() => _visible = true);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final store = ref.read(keyValueStoreProvider);
    final dismissed = int.tryParse(await store.read(_dismissKey) ?? '') ?? 0;
    await store.write(_dismissKey, '${dismissed + 1}');
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.tertiary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Isi toko & kategori otomatis dengan AI — Ultimate'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SubscriptionPage(upgradeOnly: true),
              ),
            ),
            child: const Text('Lihat'),
          ),
          IconButton(
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }
}

/// Untuk tes: melupakan bahwa ajakan Ultimate sudah tampil di sesi ini.
@visibleForTesting
void resetUltimateUpsellSession() {
  _UltimateUpsellState._shownThisSession = false;
  _aiQuotaNoticeShown = false;
}

/// Pesan "kuota AI habis" cukup sekali per sesi aplikasi: scan berikutnya tetap
/// jalan dengan hasil biasa, dan mengulang pesan yang sama tiap scan hanya
/// mengganggu.
bool _aiQuotaNoticeShown = false;
