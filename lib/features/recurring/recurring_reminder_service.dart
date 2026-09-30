import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/notification_sender.dart';
import '../../data/database.dart';

/// Menjadwalkan/membatalkan notifikasi pengingat untuk aturan transaksi
/// berulang (fitur premium) — dipanggil ulang setiap app dibuka/resume
/// (lihat `_rescheduleReminders` di lib/app.dart), bukan sekali saat dibuat,
/// supaya jadwal selalu mengikuti `nextDue` terbaru.
class RecurringReminderService {
  RecurringReminderService(this._sender);

  final NotificationSender _sender;
  static const _hour = 8;

  /// [ledgerNames] (id buku -> nama) diisi hanya bila ada lebih dari satu buku
  /// aktif; nama buku lalu ditambahkan ke judul notifikasi.
  Future<void> reschedule(
    List<RuleView> rules, {
    Map<String, String> ledgerNames = const {},
  }) async {
    await _sender.init();
    final now = DateTime.now();
    for (final v in rules) {
      final id = _notificationId(v.rule.id);
      if (!v.rule.active || !v.rule.reminderEnabled || v.finished) {
        await _sender.cancel(id);
        continue;
      }
      final due = v.nextDue;
      final notifyAt = DateTime(
        due.year,
        due.month,
        due.day - v.rule.reminderDaysBefore,
        _hour,
      );
      if (notifyAt.isBefore(now)) {
        await _sender.cancel(id);
        continue;
      }
      await _sender.schedule(
        id: id,
        title: ledgerNames[v.account.ledgerId] == null
            ? 'Pengingat transaksi berulang'
            : 'Pengingat transaksi berulang · ${ledgerNames[v.account.ledgerId]}',
        body:
            '${v.category?.name ?? v.account.name}: ${rupiah(v.rule.amount)} '
            'pada ${DateFormat('d MMM', 'id_ID').format(due)}.',
        at: notifyAt,
      );
    }
  }

  /// Batalkan pengingat aturan [ruleId] segera — dipanggil saat aturan
  /// dihapus. `reschedule()` sendiri TIDAK bisa menangkap ini: begitu baris
  /// dihapus dari database, aturan itu tidak lagi muncul di `rules` yang
  /// diberikan ke `reschedule()`, jadi alarm yang sudah terlanjur dijadwalkan
  /// tidak akan pernah dibatalkan tanpa pemanggilan eksplisit ini.
  Future<void> cancelFor(String ruleId) =>
      _sender.cancel(_notificationId(ruleId));

  static int _notificationId(String ruleId) =>
      Object.hash('recurring_reminder', ruleId).abs() % 2147483647;
}
