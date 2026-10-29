import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/glass.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../security/lock_providers.dart' show lockControllerProvider;
import 'subscription_page.dart';
import 'subscription_plans.dart';
import 'trial_countdown.dart';

/// Tampilan hitung mundur dan peringatan uji coba Ultimate
/// (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 10.4). Logika fase dan tonggak
/// ada di trial_countdown.dart.

Color _toneColor(BuildContext context, TrialPhase phase) {
  final scheme = Theme.of(context).colorScheme;
  return switch (phase) {
    TrialPhase.urgent => Colors.orange.shade700,
    TrialPhase.lastDay => scheme.error,
    _ => scheme.primary,
  };
}

String _remainingText(TrialCountdown c) {
  if (c.phase == TrialPhase.lastDay) {
    final end = c.endsAt;
    return end == null
        ? 'Uji coba Ultimate berakhir hari ini'
        : 'Uji coba Ultimate berakhir hari ini pukul '
              '${DateFormat('HH.mm').format(end)}';
  }
  return 'Uji coba Ultimate: ${c.daysLeft} hari lagi';
}

/// Kartu hitung mundur di Dashboard: sisa hari saat berjalan, atau penjelasan
/// singkat setelah berakhir. Tidak menampilkan apa pun bila tidak ada uji coba.
class TrialStatusCard extends ConsumerWidget {
  const TrialStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(trialCountdownProvider).value ?? TrialCountdown.none;
    if (c.phase == TrialPhase.none) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tone = _toneColor(context, c.phase);
    final ended = c.phase == TrialPhase.ended;
    final urgent =
        c.phase == TrialPhase.urgent || c.phase == TrialPhase.lastDay;

    return GlassCard(
      child: Row(
        children: [
          Icon(
            ended ? Icons.event_busy_rounded : Icons.hourglass_bottom_rounded,
            color: ended ? scheme.onSurfaceVariant : tone,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ended ? 'Uji coba Ultimate berakhir' : _remainingText(c),
                  style: text.titleSmall?.copyWith(color: ended ? null : tone),
                ),
                const SizedBox(height: 2),
                Text(
                  ended
                      ? 'Datamu aman. Berlangganan untuk membuka kembali fitur Ultimate.'
                      : 'Semua fitur Premium dan Ultimate terbuka sampai tanggal itu.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (ended || urgent)
            TextButton(
              onPressed: () => _openPlans(context, ref),
              child: Text(ended ? 'Lihat paket' : 'Lanjutkan'),
            ),
        ],
      ),
    );
  }
}

void _openPlans(BuildContext context, WidgetRef ref) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SubscriptionPage(
        upgradeOnly: ref.read(subscriptionTierProvider) == ActiveTier.premium,
      ),
    ),
  );
}

/// Banner tipis di atas halaman utama pada 3 hari terakhir. Bisa ditutup per
/// hari, kecuali pada hari terakhir.
class TrialBanner extends ConsumerStatefulWidget {
  const TrialBanner({super.key});

  @override
  ConsumerState<TrialBanner> createState() => _TrialBannerState();
}

class _TrialBannerState extends ConsumerState<TrialBanner> {
  bool _dismissed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = ref.read(trialClockProvider)();
    final dismissed = await ref
        .read(trialMemoryProvider)
        .bannerDismissedOn(now);
    if (mounted) {
      setState(() {
        _dismissed = dismissed;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(trialCountdownProvider).value ?? TrialCountdown.none;
    final show = c.phase == TrialPhase.urgent || c.phase == TrialPhase.lastDay;
    if (!show || !_loaded) return const SizedBox.shrink();
    final lastDay = c.phase == TrialPhase.lastDay;
    if (_dismissed && !lastDay) return const SizedBox.shrink();
    final tone = _toneColor(context, c.phase);
    return Material(
      color: tone.withValues(alpha: 0.14),
      child: InkWell(
        onTap: () => _openPlans(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.hourglass_bottom_rounded, size: 18, color: tone),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _remainingText(c),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: tone, fontWeight: FontWeight.w600),
                ),
              ),
              if (!lastDay)
                IconButton(
                  tooltip: 'Tutup peringatan',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () async {
                    setState(() => _dismissed = true);
                    await ref
                        .read(trialMemoryProvider)
                        .dismissBanner(ref.read(trialClockProvider)());
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Penjaga dialog tonggak (hari ke-23, ke-28, hari terakhir, dan akhir). Tidak
/// menampilkan apa pun; menunggu kondisi aman lalu membuka dialog.
///
/// Aturan agar tidak mengganggu: paling banyak satu dialog per sesi dan satu per
/// tonggak (tersimpan); tidak saat aplikasi terkunci PIN; tidak di atas halaman
/// lain (mis. formulir transaksi yang sedang terbuka).
class TrialPromptHost extends ConsumerStatefulWidget {
  const TrialPromptHost({super.key});

  @override
  ConsumerState<TrialPromptHost> createState() => _TrialPromptHostState();
}

class _TrialPromptHostState extends ConsumerState<TrialPromptHost> {
  var _shownThisSession = false;
  var _checking = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  /// Notifikasi penguat dijadwalkan ulang mengikuti kedaluwarsa terbaru.
  Future<void> _syncReminders(TrialCountdown c) async {
    try {
      await ref
          .read(trialReminderServiceProvider)
          .reschedule(c.running ? c.endsAt : null);
    } catch (_) {}
  }

  Future<void> _maybeShow() async {
    if (!mounted || _shownThisSession || _checking) return;
    final c = ref.read(trialCountdownProvider).value;
    if (c == null) return;
    _syncReminders(c);
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (ref.read(lockControllerProvider).value?.locked ?? false) return;

    _checking = true;
    try {
      final memory = ref.read(trialMemoryProvider);
      final milestone = dueMilestone(c, await memory.shown());
      if (milestone == null || !mounted) return;
      _shownThisSession = true;
      await memory.markShown(milestone);
      final impact = await ref.read(databaseProvider).trialImpact();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            TrialMilestoneDialog(milestone: milestone, c: c, impact: impact),
      );
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(trialCountdownProvider, (_, _) => _schedule());
    ref.listen(lockControllerProvider, (_, _) => _schedule());
    return const SizedBox.shrink();
  }
}

/// Dialog "Yang akan berubah". Isinya dihitung dari data pengguna, bukan teks
/// generik, supaya terasa nyata dan jujur.
class TrialMilestoneDialog extends ConsumerWidget {
  const TrialMilestoneDialog({
    super.key,
    required this.milestone,
    required this.c,
    required this.impact,
  });

  final TrialMilestone milestone;
  final TrialCountdown c;
  final TrialImpact impact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ended = milestone == TrialMilestone.end;
    final title = switch (milestone) {
      TrialMilestone.d23 =>
        'Uji coba Ultimate berakhir ${c.daysLeft} hari lagi',
      TrialMilestone.d28 => 'Tinggal ${c.daysLeft} hari lagi',
      TrialMilestone.d30 => 'Uji coba Ultimate berakhir hari ini',
      TrialMilestone.end => 'Uji coba Ultimate berakhir',
    };

    final changes = <String>[
      if (impact.extraLedgers > 0)
        '${impact.extraLedgers} buku kas tambahan '
            '${ended ? 'terkunci' : 'akan terkunci'} (datanya tetap aman)'
            '${impact.pausedRules > 0 ? ', ${impact.pausedRules} transaksi berulang di dalamnya dijeda' : ''}',
      if (impact.savingsCount > 0)
        '${impact.savingsCount} tabungan (${rupiah(impact.savingsTotal)}) '
            'hanya bisa ditarik',
      'Scan dan ringkasan AI, Excel, dan backup cloud '
          '${ended ? 'berhenti' : 'berhenti'}',
      'Iklan ${ended ? 'kembali tampil' : 'akan kembali tampil'}',
    ];
    const stays = ['Seluruh datamu', 'Pencatatan di Buku Utama', 'Ekspor CSV'];

    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ended ? 'Yang berubah:' : 'Yang akan berubah:',
              style: text.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final line in changes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $line'),
              ),
            const SizedBox(height: 12),
            Text('Tetap ada:', style: text.titleSmall),
            const SizedBox(height: 6),
            for (final line in stays)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $line'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ended ? 'Tutup' : 'Ingatkan nanti'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            _openPlans(context, ref);
          },
          child: const Text('Lihat paket'),
        ),
      ],
    );
  }
}
