import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/recurrence.dart';
import '../subscription/subscription_page.dart';
import '../transactions/transaction_form_page.dart';
import 'agenda_form_page.dart';
import 'agenda_reminder_service.dart';

/// Daftar agenda/event pribadi — gratis sampai `kFreeAgendaLimit` item aktif
/// (lebih dari itu perlu premium untuk MEMBUAT, tapi item lama tidak pernah
/// dihapus paksa — lihat `_handleAdd` dan `_AgendaTile.locked`), pola UI
/// persis `RecurringPage`, tanpa akun/kategori/nominal.
class AgendaPage extends ConsumerWidget {
  const AgendaPage({super.key});

  Future<void> _handleAdd(
    BuildContext context,
    WidgetRef ref,
    int count,
    bool premium,
  ) async {
    if (!premium && count >= kFreeAgendaLimit) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionPage()));
      return;
    }
    await _open(context, const AgendaFormPage());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(agendaRemindersProvider);
    final premium = ref.watch(isPremiumProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _handleAdd(context, ref, items.value?.length ?? 0, premium),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        top: false,
        child: AsyncBody<List<AgendaReminder>>(
          value: items,
          builder: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.event_note_rounded,
                message:
                    'Belum ada agenda.\n'
                    'Cocok untuk servis kendaraan, servis AC, biaya '
                    'pendidikan: diingatkan otomatis sesuai jadwal.',
              );
            }
            final eligibleIds = premium
                ? null
                : ([...list]
                        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
                      .take(kFreeAgendaLimit)
                      .map((e) => e.id)
                      .toSet();
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: list.length,
              itemBuilder: (context, i) => _AgendaTile(
                AgendaView(list[i]),
                locked:
                    eligibleIds != null && !eligibleIds.contains(list[i].id),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _open(BuildContext context, Widget page) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => page));
  if (message != null) notify(messenger, message);
}

class _AgendaTile extends ConsumerWidget {
  const _AgendaTile(this.v, {required this.locked});

  final AgendaView v;

  /// Di luar kuota gratis (bukan premium, bukan salah satu dari
  /// `kFreeAgendaLimit` item tertua) — data tetap ada, cuma pengingatnya
  /// yang berhenti. Ditandai di sini supaya bukan disangka bug.
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = v.item;
    final dimmed = !item.active || v.finished;
    final status = !item.active
        ? 'Dijeda'
        : v.finished
        ? 'Selesai'
        : 'Berikutnya ${DateFormat('d MMM yyyy', 'id_ID').format(v.nextDue)}';
    final statusLine = locked ? '$status · Pengingat nonaktif' : status;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: GlassCard(
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: ListTile(
          onTap: () => _open(context, AgendaFormPage(editing: item)),
          leading: CategoryBadge(
            icon: Icons.event_note_rounded,
            color: context.palette.transfer,
          ),
          title: Text(
            item.note == null ? item.title : '${item.title} · ${item.note}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${scheduleDescription(item.frequency, item.startDate)}\n$statusLine',
          ),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            onSelected: (a) => _onAction(context, ref, a),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Ubah')),
              if (!v.finished)
                const PopupMenuItem(
                  value: 'execute',
                  child: Text('Catat transaksi'),
                ),
              if (!v.finished)
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(item.active ? 'Jeda' : 'Lanjutkan'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String a) async {
    final db = ref.read(databaseProvider);
    switch (a) {
      case 'edit':
        await _open(context, AgendaFormPage(editing: v.item));
      case 'execute':
        await _open(context, TransactionFormPage(fromAgenda: v.item));
      case 'toggle':
        await db.setAgendaActive(v.item.id, active: !v.item.active);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus agenda?'),
            content: const Text('Pengingat untuk agenda ini akan dihentikan.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await db.deleteAgenda(v.item.id);
          await ref.read(agendaReminderServiceProvider).cancelFor(v.item.id);
        }
    }
  }
}
