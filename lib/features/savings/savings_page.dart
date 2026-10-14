import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../subscription/trial_offer.dart';
import 'savings_detail_page.dart';
import 'savings_form_page.dart';

/// Membuka formulir tabungan dan menampilkan pesan hasilnya di halaman pemanggil.
Future<void> openSavingsForm(
  BuildContext context, {
  SavingsAccount? savings,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => SavingsFormPage(savings: savings)),
  );
  if (message != null) notify(messenger, message);
}

/// Membuka halaman langganan (Ultimate) dari fitur Tabungan yang terkunci.
/// Pelanggan Premium hanya diperlihatkan upgrade ke Ultimate.
void openSavingsUpgrade(BuildContext context, WidgetRef ref) {
  // Menawarkan uji coba lebih dulu bila perangkat layak.
  openUpgradeOrTrial(context, ref);
}

/// Daftar tabungan (fitur Ultimate). Saldonya terpisah dari dompet: setoran
/// dari dompet dibukukan sebagai pengeluaran, penarikan ke dompet sebagai
/// pemasukan. Tanpa Ultimate, tabungan yang sudah ada tetap bisa dilihat dan
/// ditarik, tetapi tidak bisa ditambah atau disetori.
class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savings = ref.watch(savingsProvider);
    final ultimate = ref.watch(isUltimateProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Tabungan')),
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        tooltip: 'Tabungan Baru',
        onPressed: () => ultimate
            ? openSavingsForm(context)
            : openSavingsUpgrade(context, ref),
      ),
      body: AsyncBody<List<SavingsView>>(
        value: savings,
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.savings_outlined,
              message:
                  'Belum ada tabungan.\n'
                  'Saldonya terpisah dari dompet Anda.\n'
                  'Ketuk "Tabungan Baru" untuk mulai.',
            );
          }
          final active = list.where((s) => !s.savings.archived).toList();
          final archived = list.where((s) => s.savings.archived).toList();
          final total = active.fold<int>(0, (sum, s) => sum + s.balance);
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, kBottomPad),
            children: [
              GlassCard(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total tabungan',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    AnimatedAmount(
                      total,
                      style: Theme.of(context).textTheme.headlineMedium!,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tidak termasuk Total Saldo dompet. Setoran tercatat '
                      'sebagai pengeluaran, penarikan sebagai pemasukan.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (!ultimate)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tabungan adalah fitur Ultimate. Paket Anda saat ini tidak '
                    'bisa menyetor atau membuat tabungan baru, tetapi saldo '
                    'yang ada tetap bisa ditarik ke dompet.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.primary),
                  ),
                ),
              const SizedBox(height: 8),
              for (final s in active) _SavingsCard(s),
              if (archived.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
                  child: Text(
                    'Diarsipkan',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: scheme.outline),
                  ),
                ),
                for (final s in archived) _SavingsCard(s),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  const _SavingsCard(this.v);

  final SavingsView v;

  @override
  Widget build(BuildContext context) {
    final s = v.savings;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: s.archived ? 0.55 : 1,
      child: GlassCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SavingsDetailPage(savingsId: s.id),
          ),
        ),
        child: Row(
          children: [
            CategoryBadge(icon: categoryIcon(s.icon), color: Color(s.color)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: text.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Disetor ${rupiah(v.deposited)}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(rupiah(v.balance), style: text.titleMedium),
          ],
        ),
      ),
    );
  }
}
