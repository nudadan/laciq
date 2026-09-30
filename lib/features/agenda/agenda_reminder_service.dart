import 'package:intl/intl.dart';

import '../../core/notification_sender.dart';
import '../../data/database.dart';

/// Agenda gratis dibatasi ke [kFreeAgendaLimit] item aktif — dipakai baik
/// untuk menggerbang pembuatan item baru (`agenda_page.dart`) maupun untuk
/// menentukan item mana yang masih berhak dapat pengingat di sini.
const kFreeAgendaLimit = 3;

/// Menjadwalkan/membatalkan notifikasi pengingat agenda pribadi — pola sama
/// persis `RecurringReminderService`, tanpa nominal/akun/kategori karena
/// agenda tidak terkait transaksi. Agenda sendiri gratis (lihat
/// `kFreeAgendaLimit`), jadi berbeda dari pengingat recurring: fungsi ini
/// TIDAK pernah membatalkan semua item cuma karena `premium == false` —
/// yang dibatasi hanya item DI LUAR kuota gratis.
class AgendaReminderService {
  AgendaReminderService(this._sender);

  final NotificationSender _sender;
  static const _hour = 8;

  /// [premium] menentukan berapa banyak item yang masih dapat pengingat:
  /// semua item kalau premium, atau [kFreeAgendaLimit] item TERTUA (berdasar
  /// `createdAt`) kalau tidak — deterministik untuk pengguna yang memang
  /// selalu gratis maupun yang baru berhenti berlangganan dengan >3 item.
  ///
  /// [ledgerNames] (id buku -> nama) diisi hanya bila ada lebih dari satu buku
  /// aktif; nama buku lalu ditambahkan ke judul notifikasi.
  Future<void> reschedule(
    List<AgendaView> items, {
    required bool premium,
    Map<String, String> ledgerNames = const {},
  }) async {
    await _sender.init();
    final now = DateTime.now();
    final sorted = [...items]
      ..sort((a, b) => a.item.createdAt.compareTo(b.item.createdAt));
    for (final (i, v) in sorted.indexed) {
      final id = _notificationId(v.item.id);
      final withinFreeQuota = premium || i < kFreeAgendaLimit;
      if (!withinFreeQuota || !v.item.active || v.finished) {
        await _sender.cancel(id);
        continue;
      }
      final due = v.nextDue;
      final notifyAt = DateTime(
        due.year,
        due.month,
        due.day - v.item.reminderDaysBefore,
        _hour,
      );
      if (notifyAt.isBefore(now)) {
        await _sender.cancel(id);
        continue;
      }
      await _sender.schedule(
        id: id,
        title: _withLedger(v.item.title, ledgerNames[v.item.ledgerId]),
        body:
            v.item.note ??
            'Jadwal ${DateFormat('d MMM', 'id_ID').format(due)}.',
        at: notifyAt,
      );
    }
  }

  /// Batalkan pengingat item [itemId] segera — dipanggil saat item dihapus.
  /// Sama alasannya dengan `RecurringReminderService.cancelFor`.
  Future<void> cancelFor(String itemId) =>
      _sender.cancel(_notificationId(itemId));

  static String _withLedger(String title, String? ledgerName) =>
      ledgerName == null ? title : '$title · $ledgerName';

  static int _notificationId(String itemId) =>
      Object.hash('agenda_reminder', itemId).abs() % 2147483647;
}
