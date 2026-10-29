import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../data/database.dart' show LedgerKind;
import '../../data/providers.dart';
import '../agenda/agenda_page.dart';
import '../categories/categories_page.dart';
import '../debts/debts_page.dart';
import '../goals/goals_page.dart';
import '../ledgers/ledgers_page.dart';
import '../recurring/recurring_page.dart';
import '../reports/monthly_report_page.dart';
import '../reports/profit_loss_page.dart';
import '../savings/savings_page.dart';
import '../subscription/trial_offer.dart';
import '../subscription/subscription_plans.dart' show ActiveTier;
import '../tags/tags_page.dart';
import '../trends/trend_page.dart';

/// Hub untuk semua fitur yang dulunya cuma bisa ditemukan lewat
/// Pengaturan > Kelola — dijadikan tab navbar utama ("Lainnya", menggantikan
/// Target) supaya lebih mudah diakses. Bagian "Kelola" di Pengaturan sengaja
/// DIHAPUS (bukan didua-tempatkan) di sini, jadi ini satu-satunya jalur
/// masuk sekarang.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPremiumProvider).value ?? false;
    final ultimate = ref.watch(isUltimateProvider).value ?? false;
    final isPremiumTier =
        ref.watch(subscriptionTierProvider) == ActiveTier.premium;
    final ledgerCount = ref.watch(ledgersProvider).value?.length ?? 1;
    final hasSavings = ref.watch(savingsProvider).value?.isNotEmpty ?? false;
    // Jangan menawarkan Buku Kas bila Ultimate belum dijual dan belum ada buku tambahan.
    final ultimateOnSale = ref.watch(ultimateAvailableProvider).value ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, kBottomPad),
      children: [
        _MoreGroup([
          if (ultimate || ledgerCount > 1 || ultimateOnSale)
            _MoreTile(
              icon: Icons.menu_book_rounded,
              title: 'Buku Kas',
              subtitle: ultimate
                  ? 'Pisahkan pembukuan pribadi dan bisnis · $ledgerCount buku'
                  : ledgerCount > 1
                  ? '${ledgerCount - 1} buku terkunci · Fitur Ultimate'
                  : 'Fitur Ultimate',
              onTap: () => ultimate || ledgerCount > 1
                  ? Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LedgersPage(),
                      ),
                    )
                  : openUpgradeOrTrial(
                      context,
                      ref,
                      upgradeOnly: isPremiumTier,
                    ),
            ),
          const _BusinessModeTile(),
          _MoreTile(
            icon: Icons.category_rounded,
            title: 'Kategori',
            subtitle: 'Tambah, ubah nama, ikon, dan warna',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CategoriesPage()),
            ),
          ),
          _MoreTile(
            icon: Icons.repeat_rounded,
            title: 'Transaksi berulang',
            subtitle: 'Gaji, sewa, cicilan, langganan',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RecurringPage()),
            ),
          ),
          _MoreTile(
            icon: Icons.sell_outlined,
            title: 'Tag',
            subtitle: 'Label bebas untuk menandai transaksi',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const TagsPage())),
          ),
          _MoreTile(
            icon: Icons.insights_rounded,
            title: 'Analisa Tren',
            subtitle: premium
                ? 'Pengeluaran per kategori dari waktu ke waktu'
                : 'Pengeluaran per kategori · gratis 3 bulan terakhir',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const TrendPage())),
          ),
          _MoreTile(
            icon: Icons.summarize_rounded,
            title: 'Laporan Bulanan',
            subtitle: premium
                ? 'Sorotan otomatis: kategori, anggaran, dan perbandingan'
                : 'Fitur Premium',
            onTap: () => premium
                ? Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MonthlyReportPage(),
                    ),
                  )
                : openUpgradeOrTrial(context, ref),
          ),
          _MoreTile(
            icon: Icons.assessment_outlined,
            title: 'Laba Rugi',
            subtitle: premium
                ? 'Untung-rugi usaha: pendapatan, HPP, beban, laba bersih'
                : 'Fitur Premium',
            onTap: () => premium
                ? Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfitLossPage(),
                    ),
                  )
                : openUpgradeOrTrial(context, ref),
          ),
          _MoreTile(
            icon: Icons.event_note_rounded,
            title: 'Agenda',
            subtitle: premium
                ? 'Servis kendaraan, servis AC, biaya pendidikan'
                : 'Servis kendaraan, servis AC, biaya pendidikan · '
                      'gratis 3 item',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AgendaPage())),
          ),
          _MoreTile(
            icon: Icons.handshake_rounded,
            title: 'Utang & Piutang',
            subtitle: premium
                ? 'Catat siapa berutang ke siapa, lunas sebagian atau penuh'
                : 'Fitur Premium',
            onTap: () => premium
                ? Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const DebtsPage()),
                  )
                : openUpgradeOrTrial(context, ref),
          ),
          // Fitur Ultimate. Pengguna yang sudah punya tabungan (lalu turun
          // paket) tetap bisa membukanya untuk melihat dan menarik saldo;
          // membuat tabungan baru dan menyetor dikunci di dalam halamannya.
          if (ultimate || hasSavings || ultimateOnSale)
            _MoreTile(
              icon: Icons.savings_outlined,
              title: 'Tabungan',
              subtitle: ultimate
                  ? 'Saldo terpisah dari dompet · setor dan tarik kapan saja'
                  : hasSavings
                  ? 'Hanya bisa menarik saldo · Setor butuh Ultimate'
                  : 'Fitur Ultimate',
              onTap: () => ultimate || hasSavings
                  ? Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SavingsPage(),
                      ),
                    )
                  : openUpgradeOrTrial(
                      context,
                      ref,
                      upgradeOnly: isPremiumTier,
                    ),
            ),
          _MoreTile(
            icon: Icons.flag_outlined,
            title: 'Target',
            subtitle: 'Target tabungan: dana darurat, liburan, HP baru',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GoalsPageScaffold(),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

/// Sekelompok tile "Lainnya" dalam satu kartu kaca, dipisah garis tipis.
/// Pola sama `_Group` di settings_page.dart, disalin (bukan dipakai
/// bersama) supaya kedua halaman tetap independen.
class _MoreGroup extends StatelessWidget {
  const _MoreGroup(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      indent: 60,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return GlassCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) divider,
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Saklar "Mode usaha" untuk buku aktif. Tersedia untuk semua paket supaya
/// pelaku usaha yang hanya memakai Buku Utama juga bisa mengelompokkan kategori
/// untuk laporan Laba Rugi (docs/RENCANA-IMPLEMENTASI-UMKM.md §4.2). Hanya
/// mengubah istilah dan laporan, bukan data, jadi boleh dibolak-balik.
class _BusinessModeTile extends ConsumerWidget {
  const _BusinessModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(activeLedgerProvider);
    if (ledger == null) return const SizedBox.shrink();
    final multi = ref.watch(multiLedgerEnabledProvider);
    final on = ledger.kind == LedgerKind.business;
    return SwitchListTile(
      secondary: const Icon(Icons.storefront_rounded),
      title: Text(multi ? 'Mode usaha · ${ledger.name}' : 'Mode usaha'),
      subtitle: Text(
        on
            ? 'Kategori dikelompokkan untuk laporan Laba Rugi.'
            : 'Nyalakan bila buku ini untuk usaha: kategori bisa '
                  'dikelompokkan (HPP, beban, dll.).',
      ),
      value: on,
      onChanged: (v) => ref
          .read(databaseProvider)
          .setLedgerKind(
            ledger.id,
            v ? LedgerKind.business : LedgerKind.personal,
          ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
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
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// [GoalsPage] dulu ditampilkan langsung di dalam Scaffold [HomeShell]
/// (tanpa AppBar/FAB sendiri, karena dulu jadi salah satu tab navbar utama).
/// Sekarang dibuka lewat [Navigator.push] dari [MorePage], jadi butuh
/// Scaffold sendiri di sini.
class GoalsPageScaffold extends StatelessWidget {
  const GoalsPageScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Target')),
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        tooltip: 'Target Baru',
        onPressed: () => openGoalForm(context),
      ),
      body: const GoalsPage(),
    );
  }
}
