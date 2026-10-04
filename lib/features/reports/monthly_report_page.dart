import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/insights.dart';
import '../../data/providers.dart';
import '../ai/ai_extraction_service.dart' show AiQuotaExceeded;
import '../security/lock_providers.dart' show keyValueStoreProvider;
import '../subscription/subscription_page.dart';
import '../subscription/subscription_plans.dart' show ActiveTier;

/// Laporan bulanan berbasis aturan (fitur Premium). Semua angka dan kalimat
/// dihitung di perangkat dari data yang sudah ada; tidak ada AI dan tidak ada
/// data yang dikirim ke mana pun.
class MonthlyReportPage extends ConsumerWidget {
  const MonthlyReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(monthlyReportProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Bulanan')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            const MonthSelector(),
            const SizedBox(height: 12),
            AsyncBody<MonthlyReport>(
              value: report,
              builder: (r) => r.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: EmptyState(
                        icon: Icons.insights_rounded,
                        message:
                            'Belum ada transaksi di bulan ini. Catat beberapa '
                            'transaksi untuk melihat laporan.',
                      ),
                    )
                  : _ReportBody(r),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody(this.r);
  final MonthlyReport r;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final rate = r.savingsRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pengeluaran', style: text.labelLarge),
              const SizedBox(height: 2),
              Text(
                rupiah(r.expense),
                key: const Key('report-expense'),
                style: text.headlineMedium?.copyWith(color: palette.expense),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Figure(
                      label: 'Pemasukan',
                      value: rupiah(r.income),
                      color: palette.income,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: r.net >= 0 ? 'Sisa' : 'Defisit',
                      value: rupiah(r.net.abs()),
                      color: r.net >= 0 ? palette.income : palette.expense,
                    ),
                  ),
                  if (rate != null && rate >= 0)
                    Expanded(
                      child: _Figure(
                        label: 'Tersisa',
                        value: '${(rate * 100).round()}%',
                        color: palette.income,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (r.insights.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text('Sorotan', style: text.titleMedium),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              children: [for (final i in r.insights) _InsightRow(i)],
            ),
          ),
        ],
        _AiSummaryCard(r),
        if (r.categories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text('Pengeluaran per kategori', style: text.titleMedium),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              children: [
                for (final c in r.categories.take(6)) _CategoryRow(c, r),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          child: Text(
            'Ringkasan ini dihitung otomatis di perangkat Anda dari catatan '
            'transaksi. Tidak ada data yang dikirim ke mana pun. Ini gambaran '
            'kebiasaan belanja, bukan nasihat keuangan.',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: text.titleSmall?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow(this.insight);
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, color) = switch (insight.tone) {
      InsightTone.good => (Icons.trending_down_rounded, palette.income),
      InsightTone.warning => (Icons.warning_amber_rounded, palette.warning),
      InsightTone.info => (
        Icons.info_outline_rounded,
        Theme.of(context).colorScheme.primary,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(insight.text)),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow(this.line, this.report);
  final CategoryLine line;
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = Color(line.color);
    final delta = line.previousTotal > 0
        ? line.total - line.previousTotal
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(categoryIcon(line.icon), size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(rupiah(line.total), style: text.titleSmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: line.share.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${(line.share * 100).round()}% dari pengeluaran',
              if (delta != null && delta != 0)
                '${delta > 0 ? 'naik' : 'turun'} ${rupiah(delta.abs())} '
                    'dibanding ${report.comparisonLabel}',
            ].join(' · '),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

const aiReportConsentKey = 'ai_report_consent';
const reportAbuseEmail = 'support@hardan-ti.com';

/// Ringkasan AI (Ultimate). Opt-in terpisah dari Scan AI, hanya angka agregat
/// yang dikirim, hasil bisa dilaporkan lewat email (kebijakan konten AI Play).
class _AiSummaryCard extends ConsumerStatefulWidget {
  const _AiSummaryCard(this.report);
  final MonthlyReport report;

  @override
  ConsumerState<_AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends ConsumerState<_AiSummaryCard> {
  bool _busy = false;
  String? _message;

  String get _cacheKey {
    final r = widget.report;
    return '${ref.read(activeLedgerIdProvider)}|'
        '${DateFormat('yyyy-MM').format(r.month)}|'
        '${r.income}|${r.expense}|${r.transactionCount}';
  }

  Future<bool> _ensureConsent() async {
    final store = ref.read(keyValueStoreProvider);
    if (await store.read(aiReportConsentKey) == 'granted') return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buat ringkasan dengan AI?'),
        content: const Text(
          'Yang dikirim ke server AI kami hanya angka bulan ini: total '
          'pemasukan dan pengeluaran, nama kategori beserta totalnya, dan '
          'persen pemakaian anggaran.\n\n'
          'Tidak dikirim: catatan transaksi, nama toko, tanggal transaksi, '
          'dan foto struk. Data diproses oleh Google Gemini lewat server '
          'LaciQ dan tidak disimpan.\n\n'
          'Ringkasan dibuat oleh AI dan bisa keliru. Ini bukan nasihat '
          'keuangan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Izinkan'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await store.write(aiReportConsentKey, 'granted');
    return true;
  }

  Future<void> _generate() async {
    if (_busy || !await _ensureConsent() || !mounted) return;
    final key = _cacheKey;
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      final result = await ref
          .read(aiReportServiceProvider)
          .narrate(widget.report);
      if (result == null) {
        message = 'Ringkasan AI sedang tidak tersedia. Coba lagi nanti.';
      } else {
        ref.read(aiNarrativeCacheProvider.notifier).put(key, result);
        if (result.remaining == 5) {
          message = 'Sisa ringkasan AI bulan ini: 5.';
        }
      }
    } on AiQuotaExceeded catch (e) {
      message = e.daily
          ? 'Batas ringkasan AI hari ini tercapai. Coba lagi besok.'
          : 'Kuota ringkasan AI bulan ini habis.';
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = message;
        });
      }
    }
  }

  /// Membuka draf email ke dukungan berisi ringkasan yang dipermasalahkan.
  /// Pengguna sendiri yang menekan kirim; aplikasi tidak mengirim apa pun.
  Future<void> _reportProblem(String summary) async {
    final messenger = ScaffoldMessenger.of(context);
    final subject = Uri.encodeComponent('Laporan ringkasan AI LaciQ');
    final body = Uri.encodeComponent(
      'Ringkasan AI berikut bermasalah (jelaskan masalahnya di sini):\n\n'
      '$summary',
    );
    final uri = Uri.parse(
      'mailto:$reportAbuseEmail?subject=$subject&body=$body',
    );
    var opened = false;
    try {
      opened = await ref.read(externalLinkLauncherProvider)(uri);
    } catch (_) {}
    if (!opened && mounted) {
      notify(
        messenger,
        'Tidak ada aplikasi email. Kirim laporan ke $reportAbuseEmail.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final ultimate = ref.watch(isUltimateProvider).value ?? false;
    final onSale = ref.watch(ultimateAvailableProvider).value ?? false;
    if (r.daysElapsed < 1) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (!ultimate) {
      if (!onSale) return const SizedBox.shrink();
      return GlassCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SubscriptionPage(
              upgradeOnly:
                  ref.read(subscriptionTierProvider) == ActiveTier.premium,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ringkasan AI', style: text.titleSmall),
                  Text(
                    'Fitur Ultimate: rangkuman bulan ini dalam beberapa '
                    'kalimat.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
    }

    final cached = ref.watch(aiNarrativeCacheProvider)[_cacheKey];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: scheme.primary),
              const SizedBox(width: 12),
              Text('Ringkasan AI', style: text.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          if (cached != null) ...[
            Text(cached.summary, key: const Key('ai-summary')),
            const SizedBox(height: 8),
            Text(
              'Dibuat oleh AI dari angka di atas dan bisa keliru. Bukan '
              'nasihat keuangan.',
              style: text.bodySmall,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _reportProblem(cached.summary),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Laporkan'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _generate,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Buat ulang'),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Rangkuman bulan ini dalam beberapa kalimat. Hanya angka total '
              'dan nama kategori yang dikirim, bukan catatan atau foto.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : _generate,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_busy ? 'Membuat…' : 'Buat ringkasan AI'),
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              key: const Key('ai-summary-message'),
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
