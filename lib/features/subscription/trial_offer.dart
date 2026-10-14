import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/glass.dart';
import '../../data/providers.dart';
import '../security/lock_providers.dart' show keyValueStoreProvider;
import 'subscription_page.dart';
import 'subscription_plans.dart';
import 'trial_service.dart';

/// Penawaran uji coba Ultimate 30 hari tanpa kartu, opt-in kontekstual
/// (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 10.3): tombol hanya muncul
/// bila server menyatakan perangkat ini layak, di titik yang relevan, dan tidak
/// pernah dimulai tanpa ketukan pengguna.

/// Kuota AI uji coba yang diumumkan di layar konfirmasi. Harus sama dengan
/// `TRIAL_MONTHLY_LIMIT` / `TRIAL_REPORT_MONTHLY_LIMIT` di Worker.
const kTrialScanQuota = 60;
const kTrialSummaryQuota = 6;

/// Titik masuk tunggal untuk fitur yang terkunci. Bila perangkat layak uji
/// coba, tawarkan lebih dulu; selain itu buka halaman langganan seperti biasa.
///
/// Status penawaran dibaca dari cache sesi ([trialStatusProvider]); bila belum
/// sempat dimuat (atau Worker tidak terjangkau) pengguna langsung ke halaman
/// langganan, tidak menunggu jaringan.
Future<void> openUpgradeOrTrial(
  BuildContext context,
  WidgetRef ref, {
  bool? upgradeOnly,
}) async {
  final onlyUltimate =
      upgradeOnly ?? ref.read(subscriptionTierProvider) == ActiveTier.premium;
  final status = ref.read(trialStatusProvider).value;
  if (status != null && status.canStart) {
    await showTrialOfferSheet(
      context,
      ref,
      status: status,
      upgradeOnly: onlyUltimate,
    );
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SubscriptionPage(upgradeOnly: onlyUltimate),
    ),
  );
}

Future<void> showTrialOfferSheet(
  BuildContext context,
  WidgetRef ref, {
  required TrialStatus status,
  bool upgradeOnly = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TrialOfferSheet(status: status, upgradeOnly: upgradeOnly),
  );
}

/// Pesan hasil klaim untuk ditampilkan ke pengguna.
String trialClaimMessage(TrialClaimResult r) {
  final date = r.endsAt == null
      ? null
      : DateFormat('d MMMM yyyy', 'id_ID').format(r.endsAt!);
  return switch (r.outcome) {
    TrialClaimOutcome.granted =>
      'Uji coba Ultimate aktif${date == null ? '' : ' sampai $date'}.',
    TrialClaimOutcome.resumed =>
      'Uji coba dilanjutkan${date == null ? '' : ' sampai $date'}.',
    TrialClaimOutcome.active => 'Uji coba Ultimate sudah aktif.',
    TrialClaimOutcome.alreadyUsed =>
      'Uji coba sudah pernah dipakai di perangkat ini.',
    TrialClaimOutcome.alreadyUltimate => 'Anda sudah berlangganan Ultimate.',
    TrialClaimOutcome.paused =>
      'Uji coba sedang dijeda karena banyak peminat. Coba lagi besok.',
    TrialClaimOutcome.budgetExhausted =>
      'Kuota uji coba bulan ini sudah penuh. Coba lagi bulan depan.',
    TrialClaimOutcome.disabled => 'Uji coba sedang tidak tersedia.',
    TrialClaimOutcome.integrityFailed =>
      'Perangkat ini tidak memenuhi syarat uji coba.',
    TrialClaimOutcome.notReady || TrialClaimOutcome.failed =>
      'Tidak bisa terhubung ke server. Coba lagi nanti.',
  };
}

class _TrialOfferSheet extends ConsumerStatefulWidget {
  const _TrialOfferSheet({required this.status, required this.upgradeOnly});

  final TrialStatus status;
  final bool upgradeOnly;

  @override
  ConsumerState<_TrialOfferSheet> createState() => _TrialOfferSheetState();
}

class _TrialOfferSheetState extends ConsumerState<_TrialOfferSheet> {
  var _busy = false;

  bool get _resume => widget.status.offer == TrialOffer.resumable;

  Future<void> _start() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final result = await ref.read(trialServiceProvider).claim();
    // Status penawaran berubah apa pun hasilnya (aktif, terpakai, dijeda).
    ref.invalidate(trialStatusProvider);
    if (!mounted) return;
    navigator.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(trialClaimMessage(result))));
  }

  void _seePlans() {
    final navigator = Navigator.of(context);
    final onlyUltimate = widget.upgradeOnly;
    navigator.pop();
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => SubscriptionPage(upgradeOnly: onlyUltimate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final endsAt = widget.status.endsAt;
    final remainingDays = endsAt
        ?.difference(DateTime.now())
        .inDays
        .clamp(0, 365);

    const benefits = [
      (Icons.menu_book_rounded, 'Buku kas tambahan untuk pembukuan terpisah'),
      (Icons.savings_outlined, 'Tabungan dengan saldo terpisah dari dompet'),
      (
        Icons.auto_awesome_rounded,
        'Scan struk dan ringkasan laporan dengan AI '
            '($kTrialScanQuota scan, $kTrialSummaryQuota ringkasan)',
      ),
      (
        Icons.grid_on_rounded,
        'Ekspor Excel, Laporan Bulanan, dan backup cloud',
      ),
      (Icons.block_rounded, 'Tanpa iklan'),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _resume
                  ? 'Lanjutkan uji coba Ultimate'
                  : 'Coba semua fitur Ultimate gratis 30 hari',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _resume
                  ? 'Perangkat ini masih punya uji coba yang berjalan'
                        '${remainingDays == null ? '' : ' ($remainingDays hari lagi)'}. '
                        'Lanjutkan di sini tanpa memulai dari awal.'
                  : 'Tanpa kartu dan tanpa ditagih.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final (icon, label) in benefits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Setelah 30 hari Anda kembali ke paket Gratis kecuali berlangganan. '
              'Data Anda tetap ada; buku kas tambahan hanya terkunci.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              // Pengenal perangkat sudah terkirim saat aplikasi dibuka (pemeriksaan
              // kelayakan, lihat trialStatusProvider), bukan baru setelah tombol
              // ditekan; kalimat ini harus jujur soal itu. Selaras dengan
              // kebijakan privasi bagian 6c.
              'Agar uji coba hanya diberikan sekali per perangkat, aplikasi '
              'memeriksa kelayakan dengan mengirim pengenal perangkat Anda '
              '(disimpan ber-hash di server, bukan nilai aslinya). Tidak ada '
              'data keuangan yang dikirim.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _start,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_resume ? 'Lanjutkan uji coba' : 'Mulai uji coba'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Nanti saja'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _busy ? null : _seePlans,
                    child: const Text('Lihat paket'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu ajakan di Dashboard. Tampil hanya bila perangkat layak, pengguna sudah
/// mencatat cukup transaksi (sudah melihat nilainya), dan belum ditutup.
class TrialOfferCard extends ConsumerStatefulWidget {
  const TrialOfferCard({super.key});

  @override
  ConsumerState<TrialOfferCard> createState() => _TrialOfferCardState();
}

const kTrialCardMinTransactions = 5;
const _kDismissedUntilKey = 'trial_card_dismissed_until';
const _kDismissDays = 3;

class _TrialOfferCardState extends ConsumerState<TrialOfferCard> {
  var _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    try {
      final raw = await ref
          .read(keyValueStoreProvider)
          .read(_kDismissedUntilKey);
      final until = raw == null ? null : DateTime.tryParse(raw);
      if (until != null && until.isAfter(DateTime.now()) && mounted) {
        setState(() => _dismissed = true);
      }
    } catch (_) {
      // Tanpa penyimpanan: kartu tetap tampil.
    }
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      await ref
          .read(keyValueStoreProvider)
          .write(
            _kDismissedUntilKey,
            DateTime.now()
                .add(const Duration(days: _kDismissDays))
                .toIso8601String(),
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final status = ref.watch(trialStatusProvider).value;
    final count = ref.watch(transactionCountProvider).value ?? 0;
    if (status == null ||
        !status.canStart ||
        count < kTrialCardMinTransactions) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      onTap: () => showTrialOfferSheet(
        context,
        ref,
        status: status,
        upgradeOnly: ref.read(subscriptionTierProvider) == ActiveTier.premium,
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.offer == TrialOffer.resumable
                      ? 'Lanjutkan uji coba Ultimate'
                      : 'Coba semua fitur Ultimate gratis 30 hari',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Tanpa kartu. Buku kas tambahan, Tabungan, dan AI.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }
}
