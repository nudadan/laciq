import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/excel_export.dart';
import '../../data/profit_loss.dart';
import '../../data/profit_loss_pdf.dart';
import '../../data/profit_loss_statement.dart';
import '../../data/providers.dart';
import 'profit_loss_providers.dart';

/// Laporan Laba Rugi sederhana berbasis kas (fitur Premium). Semua angka
/// dihitung di perangkat; tidak ada data yang dikirim ke mana pun. Lihat
/// docs/RENCANA-IMPLEMENTASI-UMKM.md §4.3-§4.4.
class ProfitLossPage extends ConsumerWidget {
  const ProfitLossPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(profitLossProvider);
    final ledger = ref.watch(activeLedgerProvider);
    final business = ledger?.kind == LedgerKind.business;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laba Rugi'),
        actions: [
          // Bagikan hanya bila ada isi yang layak dibagikan.
          if (report.value case final r? when !r.current.isEmpty) _ShareMenu(r),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            const _RangePicker(),
            const SizedBox(height: 12),
            if (ledger != null && !business) _BusinessModePrompt(ledger),
            AsyncBody<ProfitLossReport>(
              value: report,
              builder: (r) => r.current.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: EmptyState(
                        icon: Icons.assessment_outlined,
                        message:
                            'Belum ada transaksi pada periode ini. Catat '
                            'penjualan dan biaya untuk melihat untung-rugi.',
                      ),
                    )
                  : _Body(r, business: business),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- bagikan

/// Bagikan laporan yang sedang tampil sebagai PDF atau Excel lewat lembar bagikan
/// Android. Berkas dibuat di perangkat; tidak ada data yang dikirim ke server.
class _ShareMenu extends ConsumerWidget {
  const _ShareMenu(this.report);

  final ProfitLossReport report;

  Future<void> _sharePdf(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = report.current;
      final bookName = ref.read(activeLedgerProvider)?.name ?? 'Buku Utama';
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/PlusJakartaSans.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/pdf/PlusJakartaSans-Bold.ttf'),
      );
      final bytes = await buildProfitLossPdf(
        report: r,
        previous: report.previous,
        bookName: bookName,
        periodLabel: rangeLabel(r.from, r.to),
        regular: regular,
        bold: bold,
      );
      await ref.read(binaryShareProvider)(
        fileName: 'laciq-laba-rugi-${profitLossFileSuffix(r.from, r.to)}.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        subject: 'Laporan Laba Rugi - $bookName',
      );
    } catch (e) {
      notify(messenger, 'Gagal membuat PDF: $e');
    }
  }

  Future<void> _shareExcel(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = report.current;
      final bookName = ref.read(activeLedgerProvider)?.name ?? 'Buku Utama';
      final items = await ref
          .read(databaseProvider)
          .getTransactions(
            from: r.from,
            to: r.to,
            ledgerId: ref.read(activeLedgerIdProvider),
          );
      final bytes = buildTransactionsXlsx(
        items,
        bookName: bookName,
        periodLabel: rangeLabel(r.from, r.to),
        profitLoss: r,
      );
      await ref.read(binaryShareProvider)(
        fileName: 'laciq-laba-rugi-${profitLossFileSuffix(r.from, r.to)}.xlsx',
        bytes: bytes,
        mimeType: xlsxMimeType,
        subject: 'Laporan Laba Rugi - $bookName',
      );
    } catch (e) {
      notify(messenger, 'Ekspor gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Bagikan laporan',
      icon: const Icon(Icons.ios_share_rounded),
      onSelected: (v) =>
          v == 'pdf' ? _sharePdf(context, ref) : _shareExcel(context, ref),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'pdf', child: Text('Bagikan PDF')),
        PopupMenuItem(value: 'xlsx', child: Text('Ekspor Excel')),
      ],
    );
  }
}

// ---------------------------------------------------------------- periode

String _dayLabel(DateTime d) => DateFormat('d MMM yyyy', 'id_ID').format(d);

String rangeLabel(DateTime from, DateTime to) {
  // `to` tidak termasuk; tampilkan hari terakhir yang masuk.
  final last = DateTime(to.year, to.month, to.day - 1);
  return '${_dayLabel(from)} - ${_dayLabel(last)}';
}

String _kindLabel(ProfitLossRangeKind k) => switch (k) {
  ProfitLossRangeKind.month => 'Bulan',
  ProfitLossRangeKind.quarter => '3 Bulan',
  ProfitLossRangeKind.year => 'Tahun',
  ProfitLossRangeKind.custom => 'Kustom',
};

class _RangePicker extends ConsumerWidget {
  const _RangePicker();

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final current = ref.read(profitLossRangeProvider);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: current.from,
        end: DateTime(current.to.year, current.to.month, current.to.day - 1),
      ),
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
    );
    if (picked == null) return;
    ref.read(profitLossCustomRangeProvider.notifier).set((
      from: DateTime(picked.start.year, picked.start.month, picked.start.day),
      to: DateTime(picked.end.year, picked.end.month, picked.end.day + 1),
    ));
    ref
        .read(profitLossRangeKindProvider.notifier)
        .select(ProfitLossRangeKind.custom);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(profitLossRangeKindProvider);
    final range = ref.watch(profitLossRangeProvider);
    final month = ref.watch(selectedMonthProvider);
    final notifier = ref.read(selectedMonthProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final k in ProfitLossRangeKind.values)
              ChoiceChip(
                label: Text(_kindLabel(k)),
                selected: kind == k,
                onSelected: (_) {
                  if (k == ProfitLossRangeKind.custom) {
                    _pickCustom(context, ref);
                  } else {
                    ref.read(profitLossRangeKindProvider.notifier).select(k);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (kind == ProfitLossRangeKind.month ||
            kind == ProfitLossRangeKind.quarter)
          const MonthSelector()
        else if (kind == ProfitLossRangeKind.year)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Tahun sebelumnya',
                onPressed: () => notifier.shift(-12),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  '${month.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Tahun berikutnya',
                onPressed: () => notifier.shift(12),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          )
        else
          TextButton.icon(
            onPressed: () => _pickCustom(context, ref),
            icon: const Icon(Icons.date_range_rounded),
            label: const Text('Ubah rentang'),
          ),
        const SizedBox(height: 4),
        Text(
          rangeLabel(range.from, range.to),
          key: const Key('pl-range'),
          style: TextStyle(color: scheme.outline, fontSize: 12),
        ),
      ],
    );
  }
}

/// Ajakan menyalakan Mode usaha di buku pribadi; laporan tetap bisa dibaca dengan
/// pengelompokan bawaan (semua pemasukan = pendapatan, semua pengeluaran = beban).
class _BusinessModePrompt extends ConsumerWidget {
  const _BusinessModePrompt(this.ledger);

  final Ledger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buku ini belum Mode usaha',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Laporan memakai pengelompokan bawaan: semua pemasukan dianggap '
            'pendapatan dan semua pengeluaran dianggap beban, termasuk modal, '
            'cicilan, atau tabungan. Nyalakan Mode usaha agar kategori bisa '
            'dikelompokkan dengan benar.',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => ref
                  .read(databaseProvider)
                  .setLedgerKind(ledger.id, LedgerKind.business),
              child: const Text('Nyalakan Mode usaha'),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- isi

String _percent(double? v) =>
    v == null ? '-' : '${NumberFormat('0.0', 'id_ID').format(v)}%';

class _Body extends StatelessWidget {
  const _Body(this.report, {required this.business});

  final ProfitLossReport report;
  final bool business;

  @override
  Widget build(BuildContext context) {
    final r = report.current;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final defaults = r.defaultGroupLines.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(report),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text('Rincian', style: text.titleMedium),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: _Statement(r),
        ),
        if (business && defaults > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Text(
              '$defaults kategori memakai pengelompokan otomatis. Ubah di '
              'Kategori bila ada yang keliru (mis. modal atau pembelian '
              'peralatan).',
              key: const Key('pl-default-note'),
              style: TextStyle(color: scheme.outline, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text('Dari laba ke kas', style: text.titleMedium),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: _Reconciliation(r),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          child: Text(
            'Catatan manajemen berbasis kas, bukan laporan resmi atau laporan '
            'pajak. Penjualan secara kredit baru terhitung saat uangnya '
            'diterima.',
            style: TextStyle(color: scheme.outline, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero(this.report);

  final ProfitLossReport report;

  @override
  Widget build(BuildContext context) {
    final r = report.current;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final net = r.netProfit;
    final color = net >= 0 ? palette.income : palette.expense;
    final change = changePercent(net, report.previous.netProfit);
    final trend = change == null ? Trend.flat : trendOf(change);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            net >= 0 ? 'Laba bersih' : 'Rugi bersih',
            style: text.labelLarge,
          ),
          const SizedBox(height: 2),
          Text(
            rupiah(net.abs()),
            key: const Key('pl-net'),
            style: text.headlineMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          Text(
            r.netMarginPercent == null
                ? 'Belum ada pendapatan usaha pada periode ini'
                : '${_percent(r.netMarginPercent)} dari pendapatan usaha',
            key: const Key('pl-margin'),
          ),
          if (change != null && !report.previous.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              switch (trend) {
                Trend.flat =>
                  'Sama dengan periode sebelumnya '
                      '(${rupiah(report.previous.netProfit)})',
                Trend.up || Trend.down =>
                  '${trend == Trend.up ? '▲' : '▼'} '
                      '${_percent(change.abs())} dibanding periode '
                      'sebelumnya (${rupiah(report.previous.netProfit)})',
              },
              key: const Key('pl-change'),
              style: TextStyle(
                color: switch (trend) {
                  Trend.up => palette.income,
                  Trend.down => palette.expense,
                  Trend.flat => null,
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                // Total pendapatan - total biaya = laba bersih, supaya kedua angka ini
                // dan angka besar di atasnya selalu cocok (pendapatan lain ikut di sini,
                // bukan dikurangkan dari biaya).
                child: _Figure(
                  label: 'Total pendapatan',
                  value: rupiah(r.revenue.total + r.otherIncome.total),
                  color: palette.income,
                  valueKey: const Key('pl-total-income'),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Total biaya',
                  value: rupiah(
                    r.cogs.total + r.opex.total + r.otherExpense.total,
                  ),
                  color: palette.expense,
                  valueKey: const Key('pl-total-cost'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
    this.valueKey,
  });

  final String label;
  final String value;
  final Color color;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelMedium),
        Text(
          value,
          key: valueKey,
          style: text.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Satu baris tabel: [label] di kiri, [amount] di kanan.
class _Row extends StatelessWidget {
  const _Row(
    this.label,
    this.amount, {
    this.bold = false,
    this.indent = false,
    this.sign = '',
    this.color,
    this.note,
    super.key,
  });

  final String label;
  final int amount;
  final bool bold;
  final bool indent;

  /// Awalan tampilan, mis. "- " untuk pengurang.
  final String sign;
  final Color? color;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final style = bold
        ? base?.copyWith(fontWeight: FontWeight.w700, color: color)
        : base?.copyWith(color: color);
    return Padding(
      padding: EdgeInsets.only(left: indent ? 16 : 0, top: 5, bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (note != null)
                  Text(
                    note!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('$sign${rupiah(amount)}', style: style),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 8, color: Theme.of(context).colorScheme.outlineVariant);
}

List<Widget> _lines(ProfitLossSection s, {String sign = ''}) => [
  for (final l in s.lines)
    _Row(
      l.name,
      l.amount,
      indent: true,
      sign: sign,
      note: l.isDefaultGroup ? 'otomatis' : null,
    ),
];

/// Tabel bertingkat: pendapatan, HPP, laba kotor, beban, laba operasional,
/// pendapatan/beban lain, laba bersih. Bagian kosong disembunyikan agar tidak
/// ramai, kecuali pendapatan, beban operasional, dan laba bersih.
class _Statement extends StatelessWidget {
  const _Statement(this.r);

  final ProfitLoss r;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Color tone(int v) => v >= 0 ? palette.income : palette.expense;
    return Column(
      children: [
        _Row('Pendapatan usaha', r.revenue.total, bold: true),
        ..._lines(r.revenue),
        if (r.cogs.total > 0) ...[
          _Row(
            'Harga pokok penjualan (HPP)',
            r.cogs.total,
            bold: true,
            sign: '- ',
          ),
          ..._lines(r.cogs, sign: '- '),
          const _Divider(),
          _Row(
            'Laba kotor',
            r.grossProfit,
            bold: true,
            color: tone(r.grossProfit),
            note: r.grossMarginPercent == null
                ? null
                : _percent(r.grossMarginPercent),
            key: const Key('pl-gross'),
          ),
        ],
        _Row('Beban operasional', r.opex.total, bold: true, sign: '- '),
        ..._lines(r.opex, sign: '- '),
        if (r.otherIncome.total > 0 || r.otherExpense.total > 0) ...[
          const _Divider(),
          _Row(
            'Laba operasional',
            r.operatingProfit,
            bold: true,
            color: tone(r.operatingProfit),
          ),
          if (r.otherIncome.total > 0) ...[
            _Row(
              'Pendapatan lain',
              r.otherIncome.total,
              bold: true,
              sign: '+ ',
            ),
            ..._lines(r.otherIncome, sign: '+ '),
          ],
          if (r.otherExpense.total > 0) ...[
            _Row('Beban lain', r.otherExpense.total, bold: true, sign: '- '),
            ..._lines(r.otherExpense, sign: '- '),
          ],
        ],
        const _Divider(),
        _Row(
          r.netProfit >= 0 ? 'Laba bersih' : 'Rugi bersih',
          r.netProfit,
          bold: true,
          color: tone(r.netProfit),
          key: const Key('pl-net-row'),
        ),
      ],
    );
  }
}

/// Menjembatani laba bersih ke perubahan kas: selisihnya adalah arus yang tidak
/// termasuk laba rugi (modal, prive, aset, utang, tabungan, penyesuaian saldo).
class _Reconciliation extends StatelessWidget {
  const _Reconciliation(this.r);

  final ProfitLoss r;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final none = r.nonPnlIncome.lines.isEmpty && r.nonPnlExpense.lines.isEmpty;
    return Column(
      children: [
        _Row(r.netProfit >= 0 ? 'Laba bersih' : 'Rugi bersih', r.netProfit),
        if (none)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tidak ada arus kas di luar laba rugi pada periode ini.',
              ),
            ),
          )
        else ...[
          for (final l in r.nonPnlIncome.lines)
            _Row(l.name, l.amount, indent: true, sign: '+ '),
          for (final l in r.nonPnlExpense.lines)
            _Row(l.name, l.amount, indent: true, sign: '- '),
        ],
        const _Divider(),
        _Row(
          'Perubahan kas',
          r.cashChange,
          bold: true,
          color: r.cashChange >= 0 ? palette.income : palette.expense,
          key: const Key('pl-cash'),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sama dengan total pemasukan dikurangi total pengeluaran pada '
              'periode ini (tanpa transfer antar dompet).',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
