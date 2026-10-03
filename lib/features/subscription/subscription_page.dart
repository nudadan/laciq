import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import 'subscription_plans.dart';
import 'subscription_status.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key, this.upgradeOnly = false});

  /// Hanya menampilkan Ultimate (untuk pelanggan Premium yang ingin upgrade).
  final bool upgradeOnly;

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  late Future<List<SubscriptionPackage>> _packages;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _packages = ref.read(subscriptionStatusProvider).fetchPackages();
  }

  Future<void> _purchase(SubscriptionPackage package) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(subscriptionStatusProvider).purchase(package);
      navigator.pop();
      notify(messenger, 'Langganan ${package.tier.label} aktif. Terima kasih!');
    } on SubscriptionCancelled {
      // Dibatalkan pengguna sendiri lewat dialog Play Store — tidak perlu pesan.
    } on SubscriptionException catch (e) {
      notify(messenger, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final found = await ref
          .read(subscriptionStatusProvider)
          .restorePurchases();
      notify(
        messenger,
        found
            ? 'Pembelian dipulihkan.'
            : 'Tidak ada langganan aktif yang ditemukan untuk akun ini. '
                  'Pastikan memakai akun Google Play yang sama dengan saat '
                  'berlangganan, lalu coba lagi.',
      );
    } on SubscriptionException catch (e) {
      notify(messenger, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.upgradeOnly ? 'Upgrade ke Ultimate' : 'DompetKu Premium',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.upgradeOnly
                  ? 'Buka ekstraksi struk dengan AI dan pembukuan terpisah.'
                  : 'Hilangkan iklan dan dukung pengembangan DompetKu.',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<SubscriptionPackage>>(
              future: _packages,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  final err = snapshot.error;
                  return Text(
                    err is SubscriptionException
                        ? err.message
                        : 'Gagal memuat paket langganan.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                final packages = snapshot.data!;
                if (packages.isEmpty) {
                  return const Text(
                    'Belum ada paket langganan tersedia saat ini.',
                  );
                }
                return Column(
                  children: [
                    for (final tier in SubscriptionTier.values)
                      if ((!widget.upgradeOnly ||
                              tier == SubscriptionTier.ultimate) &&
                          packages.any((p) => p.tier == tier))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _TierCard(
                            tier: tier,
                            packages: [
                              for (final period in SubscriptionPeriod.values)
                                ...packages.where(
                                  (p) => p.tier == tier && p.period == period,
                                ),
                            ],
                            busy: _busy,
                            onPurchase: _purchase,
                          ),
                        ),
                  ],
                );
              },
            ),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _restore,
                child: const Text('Pulihkan pembelian'),
              ),
            ),
            const SizedBox(height: 8),
            const _UserIdLine(),
            const SizedBox(height: 12),
            Text(
              'Langganan diperpanjang otomatis lewat Google Play. '
              'Batalkan kapan saja lewat Play Store > Langganan.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu kartu per tingkat: manfaat + pilihan bulanan/tahunan. Harga yang
/// tampil adalah harga dari toko (yang benar-benar ditagihkan), dalam Rupiah.
class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.packages,
    required this.busy,
    required this.onPurchase,
  });

  final SubscriptionTier tier;
  final List<SubscriptionPackage> packages;
  final bool busy;
  final Future<void> Function(SubscriptionPackage) onPurchase;

  static const _premiumBenefits = [
    (Icons.block_rounded, 'Tanpa iklan'),
    (
      Icons.insights_rounded,
      'Analisa Tren — histori penuh 6-12 bulan (gratis: 3 bulan terakhir)',
    ),
    (
      Icons.cloud_upload_rounded,
      'Backup cloud terenkripsi ke Google Drive Anda sendiri',
    ),
    (Icons.event_note_rounded, 'Agenda pengingat tanpa batas (gratis: 3 item)'),
    (
      Icons.query_stats_rounded,
      'Proyeksi kebutuhan anggaran bulanan dari Agenda & transaksi berulang',
    ),
    (Icons.handshake_rounded, 'Pencatatan Utang & Piutang beserta cicilannya'),
    (
      Icons.receipt_long_rounded,
      'Scan struk: nominal, toko, dan tanggal terisi otomatis, foto struk '
          'tersimpan',
    ),
  ];

  static const _ultimateBenefits = [
    (Icons.workspace_premium_rounded, 'Semua fitur Premium'),
    (
      Icons.menu_book_rounded,
      'Multi buku kas: pisahkan pembukuan pribadi dan bisnis '
          '(sampai 5 buku, masing-masing dompet, kategori, dan anggaran sendiri)',
    ),
    (
      Icons.auto_awesome_rounded,
      'Ekstraksi struk dengan AI: nama toko, kategori, total, dan tanggal '
          'terisi otomatis (300 scan/bulan)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final benefits = tier == SubscriptionTier.premium
        ? _premiumBenefits
        : _ultimateBenefits;
    final monthly = packages
        .where((p) => p.period == SubscriptionPeriod.monthly)
        .firstOrNull;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tier.label,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
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
          const Divider(height: 24),
          for (final p in packages)
            _PriceRow(
              package: p,
              savingsPercent:
                  p.period == SubscriptionPeriod.yearly &&
                      monthly?.amount != null &&
                      p.amount != null
                  ? yearlySavingsPercent(
                      monthly: monthly!.amount!,
                      yearly: p.amount!,
                    )
                  : 0,
              busy: busy,
              onPurchase: onPurchase,
            ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.package,
    required this.savingsPercent,
    required this.busy,
    required this.onPurchase,
  });

  final SubscriptionPackage package;
  final int savingsPercent;
  final bool busy;
  final Future<void> Function(SubscriptionPackage) onPurchase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(package.period.label, style: textTheme.labelLarge),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      package.priceLabel,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(' / ${package.period.unit}'),
                  ],
                ),
                if (savingsPercent > 0)
                  Text(
                    'Hemat $savingsPercent% dibanding bulanan',
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: busy ? null : () => onPurchase(package),
            child: const Text('Berlangganan'),
          ),
        ],
      ),
    );
  }
}

/// ID pengguna anonim (6 karakter terakhir) untuk membantu penelusuran bila
/// status langganan tidak sesuai. Sengaja dipotong: cukup untuk dicocokkan di
/// dashboard, tidak cukup untuk dipakai sebagai ID.
class _UserIdLine extends ConsumerWidget {
  const _UserIdLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(subscriptionStatusProvider).appUserId(),
      builder: (context, snapshot) {
        final id = snapshot.data;
        if (id == null || id.length < 6) return const SizedBox.shrink();
        return Text(
          'ID pengguna: …${id.substring(id.length - 6)}',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
