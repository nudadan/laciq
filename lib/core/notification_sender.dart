import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Pengirim notifikasi sistem, dipisah dari pemanggil-pemanggilnya (anggaran,
/// pengingat transaksi berulang, pengingat agenda) agar bisa diganti dengan
/// palsu di tes (pola sama `FakeBiometric` untuk `BiometricAuthenticator`).
abstract interface class NotificationSender {
  Future<void> init();
  Future<void> show({
    required int id,
    required String title,
    required String body,
  });

  /// Notifikasi terjadwal, dikirim OS pada waktu [at] walau app tertutup.
  /// Mode inexact (lihat implementasi) — tidak butuh izin alarm presisi.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  });

  /// Batalkan notifikasi terjadwal dengan [id] ini, kalau ada.
  Future<void> cancel(int id);
}

/// Notifikasi Android sungguhan lewat `flutter_local_notifications`.
class LocalNotificationSender implements NotificationSender {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _immediateChannelId = 'budget_alerts';
  static const _scheduledChannelId = 'reminders';

  @override
  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    tz.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    _initialized = true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _immediateChannelId,
        'Peringatan Anggaran',
        channelDescription:
            'Pemberitahuan saat pemakaian kategori mendekati atau '
            'melebihi anggaran bulanan.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _scheduledChannelId,
        'Pengingat',
        channelDescription: 'Pengingat transaksi berulang dan agenda pribadi.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    // Tidak butuh izin SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM — cukup akurat
    // untuk pengingat H-1/H-3/H-7 (boleh meleset beberapa menit-jam).
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
