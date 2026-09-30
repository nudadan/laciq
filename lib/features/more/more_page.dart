import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../data/providers.dart';
import '../agenda/agenda_page.dart';
import '../categories/categories_page.dart';
import '../debts/debts_page.dart';
import '../goals/goals_page.dart';
import '../ledgers/ledgers_page.dart';
import '../recurring/recurring_page.dart';
import '../subscription/subscription_page.dart';
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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ultimate || ledgerCount > 1
                      ? const LedgersPage()
                      : SubscriptionPage(upgradeOnly: isPremiumTier),
                ),
              ),
            ),
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    premium ? const DebtsPage() : const SubscriptionPage(),
              ),
            ),
          ),
          _MoreTile(
            icon: Icons.flag_outlined,
            title: 'Target',
            subtitle: 'Target tabungan: dana darurat, liburan, HP baru',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _GoalsPageScaffold(),
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
class _GoalsPageScaffold extends StatelessWidget {
  const _GoalsPageScaffold();

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
