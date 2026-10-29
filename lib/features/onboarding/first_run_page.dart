import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../data/database.dart' show LedgerKind, kMainLedgerId;
import '../../data/providers.dart';
import '../transactions/open_transaction_form.dart';
import 'onboarding_providers.dart';

/// Alur awal instalasi baru: sapaan, pilihan tujuan (pribadi atau usaha), lalu
/// ajakan mencatat transaksi pertama (docs/RENCANA-IMPLEMENTASI-ONBOARDING.md
/// butir A). Daftar fitur dan paket yang dulu tampil di sini kini hanya
/// lewat Pengaturan > "Lihat panduan lagi" ([OnboardingPage]).
class FirstRunPage extends ConsumerStatefulWidget {
  const FirstRunPage({super.key});

  @override
  ConsumerState<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends ConsumerState<FirstRunPage> {
  static const _steps = 3;
  var _step = 0;
  var _busy = false;

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
  }

  /// Memilih "Usaha kecil" menyalakan Mode usaha di Buku Utama (hanya istilah
  /// dan laporan, bisa diubah lagi di Lainnya). "Pribadi" tidak mengubah apa pun.
  Future<void> _choose(LedgerKind kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (kind == LedgerKind.business) {
        await ref
            .read(databaseProvider)
            .setLedgerKind(kMainLedgerId, LedgerKind.business);
      }
    } catch (_) {
      // Gagal menyimpan pilihan tidak boleh menahan pemakaian; bisa diatur
      // lagi di Lainnya.
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = 2;
    });
  }

  Future<void> _recordFirst() async {
    await openTransactionForm(context);
    if (!mounted) return;
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Widget content = switch (_step) {
      0 => _Step(
        key: const ValueKey('step-welcome'),
        icon: Icons.account_balance_wallet_rounded,
        title: 'Selamat datang di LaciQ',
        body:
            'Catat uang masuk dan keluar tanpa ribet. Datamu tersimpan di '
            'HP-mu, tanpa perlu membuat akun.',
        actions: [
          FilledButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Mulai'),
          ),
        ],
      ),
      1 => _Step(
        key: const ValueKey('step-purpose'),
        icon: Icons.flag_rounded,
        title: 'Untuk apa kamu memakai LaciQ?',
        body: 'Pilih yang paling dekat. Bisa kamu ubah kapan saja.',
        extra: [
          _ChoiceCard(
            key: const Key('choice-personal'),
            icon: Icons.person_rounded,
            title: 'Keuangan pribadi',
            subtitle:
                'Catat pengeluaran harian, atur anggaran, dan pantau tabungan.',
            onTap: () => _choose(LedgerKind.personal),
          ),
          _ChoiceCard(
            key: const Key('choice-business'),
            icon: Icons.storefront_rounded,
            title: 'Usaha kecil',
            subtitle:
                'Catat penjualan dan biaya, lalu lihat untung-rugi usahamu.',
            onTap: () => _choose(LedgerKind.business),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pilihan ini bisa diganti di Lainnya > Mode usaha.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      _ => _Step(
        key: const ValueKey('step-first-transaction'),
        icon: Icons.edit_note_rounded,
        title: 'Catat transaksi pertamamu',
        body:
            'Mulai dari yang paling gampang: uang yang baru kamu pakai atau '
            'terima hari ini. Cuma butuh nominal dan kategori.',
        actions: [
          FilledButton(
            onPressed: _recordFirst,
            child: const Text('Catat sekarang'),
          ),
          TextButton(onPressed: _finish, child: const Text('Nanti saja')),
        ],
      ),
    };

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Lewati'),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: content,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _steps; i++)
                      Container(
                        width: i == _step ? 22 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: i == _step
                              ? scheme.primary
                              : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.extra = const [],
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> extra;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: context.palette.heroGradient,
                  ),
                ),
                child: Icon(icon, size: 44, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (extra.isNotEmpty) const SizedBox(height: 20),
            ...extra,
            if (actions.isNotEmpty) const SizedBox(height: 28),
            for (final a in actions) ...[a, const SizedBox(height: 4)],
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 32, color: scheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
