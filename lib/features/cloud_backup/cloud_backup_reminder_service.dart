import 'package:intl/intl.dart';

import '../../core/notification_sender.dart';
import '../../data/recurrence.dart' show dateOnly;
import '../security/app_lock_service.dart';
import 'cloud_backup_service.dart';

/// Mengingatkan pengguna yang sudah masuk Backup Cloud kalau backup terakhir
/// sudah melewati interval pilihan mereka (mingguan/bulanan). Dicek di
/// `_checkBackupReminder()` (lib/app.dart, initState + resumed) — TAPI
/// throttle sendiri (maks 1x/hari) karena `lastBackupAt()` memanggil Drive
/// API lewat jaringan, beda dari `BudgetNotificationService` yang murni baca
/// DB lokal.
class CloudBackupReminderService {
  CloudBackupReminderService(
    this._store,
    this._cloudBackup, [
    NotificationSender? sender,
  ]) : _sender = sender ?? LocalNotificationSender();

  final KeyValueStore _store;
  final CloudBackupService _cloudBackup;
  final NotificationSender _sender;

  static const defaultIntervalDays = 7;
  static const _kEnabled = 'backup_reminder_enabled';
  static const _kIntervalDays = 'backup_reminder_interval_days';
  static const _kLastChecked = 'backup_reminder_last_checked';
  static const _kLastShown = 'backup_reminder_last_shown';
  static const _notificationId = 1900001; // slot tetap, cuma satu status global

  Future<bool> enabled() async => (await _store.read(_kEnabled)) != '0';
  Future<void> setEnabled(bool v) => _store.write(_kEnabled, v ? '1' : '0');

  Future<int> intervalDays() async {
    final raw = await _store.read(_kIntervalDays);
    return raw == null ? defaultIntervalDays : int.parse(raw);
  }

  Future<void> setIntervalDays(int days) =>
      _store.write(_kIntervalDays, '$days');

  Future<void> checkAndNotify({DateTime? now}) async {
    final n = now ?? DateTime.now();
    if (!await enabled()) return;

    // Throttle panggilan jaringan: paling banyak sekali per hari kalender.
    final lastChecked = await _readDate(_kLastChecked);
    if (lastChecked != null && dateOnly(lastChecked) == dateOnly(n)) return;
    await _store.write(_kLastChecked, n.toIso8601String());

    // Throttle notifikasi: jangan ulang sebelum interval berlalu lagi,
    // TERLEPAS dari apakah masih basi (hindari spam tiap hari).
    final interval = await intervalDays();
    final lastShown = await _readDate(_kLastShown);
    if (lastShown != null &&
        n.difference(lastShown) < Duration(days: interval)) {
      return;
    }

    final lastBackup = await _cloudBackup.lastBackupAt();
    final stale =
        lastBackup == null ||
        n.difference(lastBackup) >= Duration(days: interval);
    if (!stale) return;

    await _sender.init();
    await _sender.show(
      id: _notificationId,
      title: 'Waktunya backup data Anda',
      body: lastBackup == null
          ? 'Anda belum pernah backup ke Google Drive. Cadangkan data sekarang.'
          : 'Backup terakhir ${DateFormat('d MMM yyyy', 'id_ID').format(lastBackup)}. '
                'Cadangkan data terbaru Anda.',
    );
    await _store.write(_kLastShown, n.toIso8601String());
  }

  Future<DateTime?> _readDate(String key) async {
    final raw = await _store.read(key);
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
