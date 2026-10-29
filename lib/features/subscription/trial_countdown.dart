import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notification_sender.dart';
import '../../data/providers.dart';
import '../security/app_lock_service.dart' show KeyValueStore;
import '../security/lock_providers.dart' show keyValueStoreProvider;
import 'subscription_plans.dart';

/// Hitung mundur uji coba Ultimate dan peringatan per tonggak
/// (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 10.4). Berkas ini murni logika
/// dan penyimpanan; tampilannya ada di trial_status.dart.

/// Fase hitung mundur menurut sisa waktu.
enum TrialPhase {
  /// Tidak ada uji coba (atau sudah berlangganan Ultimate).
  none,

  /// Lebih dari 7 hari.
  normal,

  /// 7 hari atau kurang (hari ke-23 dst.).
  approaching,

  /// 3 hari atau kurang (hari ke-27 dst.).
  urgent,

  /// Kurang dari 24 jam.
  lastDay,

  /// Baru berakhir (dalam [kTrialEndedWindow]).
  ended,
}

/// Tonggak yang memunculkan dialog sekali.
enum TrialMilestone {
  /// Hari ke-23: sisa 7 hari.
  d23,

  /// Hari ke-28: sisa 2 hari.
  d28,

  /// Hari terakhir (kurang dari 24 jam).
  d30,

  /// Uji coba baru berakhir.
  end,
}

/// Berapa lama kartu "uji coba berakhir" tetap tampil.
const kTrialEndedWindow = Duration(days: 7);

const _approaching = Duration(days: 7);
const _urgent = Duration(days: 3);
const _lastDay = Duration(hours: 24);

class TrialCountdown {
  const TrialCountdown({
    required this.phase,
    this.endsAt,
    this.remaining = Duration.zero,
  });

  static const none = TrialCountdown(phase: TrialPhase.none);

  final TrialPhase phase;

  /// Kedaluwarsa uji coba (untuk fase berjalan maupun [TrialPhase.ended]).
  final DateTime? endsAt;

  /// Sisa waktu; nol bila tidak berjalan.
  final Duration remaining;

  /// Sisa hari dibulatkan ke atas (30 hari penuh = 30; 1 jam lagi = 1).
  int get daysLeft =>
      remaining <= Duration.zero ? 0 : (remaining.inMinutes / (24 * 60)).ceil();

  bool get running =>
      phase == TrialPhase.normal ||
      phase == TrialPhase.approaching ||
      phase == TrialPhase.urgent ||
      phase == TrialPhase.lastDay;

  /// Menghitung fase pada waktu [now].
  ///
  /// [endsAt] = kedaluwarsa uji coba yang sedang berjalan (null bila tidak ada);
  /// [lastEnd] = kedaluwarsa yang terakhir terlihat (untuk fase `ended`);
  /// [paidUltimate] = pengguna sudah berlangganan Ultimate: tidak ada uji coba
  /// yang perlu diumumkan.
  factory TrialCountdown.at(
    DateTime now, {
    DateTime? endsAt,
    DateTime? lastEnd,
    bool paidUltimate = false,
  }) {
    if (paidUltimate) return none;
    if (endsAt != null && now.isBefore(endsAt)) {
      final left = endsAt.difference(now);
      final phase = left <= _lastDay
          ? TrialPhase.lastDay
          : left <= _urgent
          ? TrialPhase.urgent
          : left <= _approaching
          ? TrialPhase.approaching
          : TrialPhase.normal;
      return TrialCountdown(phase: phase, endsAt: endsAt, remaining: left);
    }
    final end = endsAt ?? lastEnd;
    if (end != null &&
        !now.isBefore(end) &&
        now.difference(end) < kTrialEndedWindow) {
      return TrialCountdown(phase: TrialPhase.ended, endsAt: end);
    }
    return none;
  }
}

/// Tonggak berikutnya yang pantas ditampilkan, atau null. Hanya satu per
/// pemanggilan: yang tertinggi yang jatuh tempo dan belum pernah ditampilkan.
TrialMilestone? dueMilestone(TrialCountdown c, Set<TrialMilestone> shown) {
  bool pending(TrialMilestone m) => !shown.contains(m);
  switch (c.phase) {
    case TrialPhase.ended:
      return pending(TrialMilestone.end) ? TrialMilestone.end : null;
    case TrialPhase.lastDay:
      return pending(TrialMilestone.d30) ? TrialMilestone.d30 : null;
    case TrialPhase.urgent:
      return pending(TrialMilestone.d28) ? TrialMilestone.d28 : null;
    case TrialPhase.approaching:
      return pending(TrialMilestone.d23) ? TrialMilestone.d23 : null;
    case TrialPhase.normal || TrialPhase.none:
      return null;
  }
}

/// Tonggak yang dianggap sudah lewat begitu [m] ditampilkan, supaya tonggak
/// yang terlewat (mis. aplikasi baru dibuka di hari ke-29) tidak muncul
/// berurutan di sesi-sesi berikutnya.
Set<TrialMilestone> impliedBy(TrialMilestone m) => switch (m) {
  TrialMilestone.d23 => {TrialMilestone.d23},
  TrialMilestone.d28 => {TrialMilestone.d23, TrialMilestone.d28},
  TrialMilestone.d30 => {
    TrialMilestone.d23,
    TrialMilestone.d28,
    TrialMilestone.d30,
  },
  TrialMilestone.end => TrialMilestone.values.toSet(),
};

/// Ingatan ringan (KeyValueStore) untuk tonggak yang sudah ditampilkan,
/// kedaluwarsa terakhir yang terlihat, dan banner yang ditutup.
class TrialMemory {
  TrialMemory(this._store);

  final KeyValueStore _store;

  static const _kLastEnd = 'trial_last_end';
  static const _kShown = 'trial_milestones_shown';
  static const _kBannerDay = 'trial_banner_dismissed_day';

  Future<DateTime?> lastEnd() async {
    try {
      final raw = await _store.read(_kLastEnd);
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> recordEnd(DateTime endsAt) async {
    try {
      await _store.write(_kLastEnd, endsAt.toIso8601String());
    } catch (_) {}
  }

  Future<Set<TrialMilestone>> shown() async {
    try {
      final raw = await _store.read(_kShown);
      if (raw == null || raw.isEmpty) return {};
      return {
        for (final name in raw.split(','))
          for (final m in TrialMilestone.values)
            if (m.name == name) m,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> markShown(TrialMilestone m) async {
    try {
      final all = {...await shown(), ...impliedBy(m)};
      await _store.write(_kShown, all.map((e) => e.name).join(','));
    } catch (_) {}
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<bool> bannerDismissedOn(DateTime now) async {
    try {
      return await _store.read(_kBannerDay) == _day(now);
    } catch (_) {
      return false;
    }
  }

  Future<void> dismissBanner(DateTime now) async {
    try {
      await _store.write(_kBannerDay, _day(now));
    } catch (_) {}
  }
}

final trialMemoryProvider = Provider<TrialMemory>(
  (ref) => TrialMemory(ref.watch(keyValueStoreProvider)),
);

/// Jam yang bisa diganti di tes.
final trialClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Hitung mundur uji coba. Panggil `ref.invalidate` saat aplikasi kembali ke
/// depan agar sisa hari diperbarui.
final trialCountdownProvider = FutureProvider<TrialCountdown>((ref) async {
  final endsAt = ref.watch(trialEndsAtProvider);
  final paid = ref.watch(subscriptionTierProvider);
  final memory = ref.watch(trialMemoryProvider);
  final now = ref.watch(trialClockProvider)();
  if (endsAt != null) await memory.recordEnd(endsAt);
  final lastEnd = endsAt ?? await memory.lastEnd();
  return TrialCountdown.at(
    now,
    endsAt: endsAt,
    lastEnd: lastEnd,
    paidUltimate: paid == ActiveTier.ultimate,
  );
});

/// Notifikasi pengingat akhir uji coba (hari ke-23 dan ke-28, pukul 10.00).
/// Hanya penguat: peringatan utama ada di dalam aplikasi dan tidak bergantung
/// izin notifikasi.
class TrialReminderService {
  TrialReminderService(this._sender);

  final NotificationSender _sender;

  static const idWeek = 810023;
  static const idLastDays = 810028;
  static const _hour = 10;

  /// Menjadwalkan untuk uji coba yang berakhir pada [endsAt], atau membatalkan
  /// semuanya bila [endsAt] null (tidak ada uji coba / sudah berlangganan).
  Future<void> reschedule(DateTime? endsAt, {DateTime? now}) async {
    await _sender.init();
    if (endsAt == null) {
      await cancelAll();
      return;
    }
    final current = now ?? DateTime.now();
    await _scheduleAt(
      idWeek,
      DateTime(endsAt.year, endsAt.month, endsAt.day - 7, _hour),
      current,
      'Uji coba Ultimate berakhir 7 hari lagi',
      'Lihat apa yang akan berubah dan pilih paket yang cocok. Datamu tetap aman.',
    );
    await _scheduleAt(
      idLastDays,
      DateTime(endsAt.year, endsAt.month, endsAt.day - 2, _hour),
      current,
      'Uji coba Ultimate berakhir 2 hari lagi',
      'Berlangganan untuk tetap memakai buku kas tambahan, Tabungan, dan AI.',
    );
  }

  Future<void> _scheduleAt(
    int id,
    DateTime at,
    DateTime now,
    String title,
    String body,
  ) async {
    if (at.isBefore(now)) {
      await _sender.cancel(id);
      return;
    }
    await _sender.schedule(id: id, title: title, body: body, at: at);
  }

  Future<void> cancelAll() async {
    await _sender.cancel(idWeek);
    await _sender.cancel(idLastDays);
  }
}

final trialReminderServiceProvider = Provider<TrialReminderService>(
  (ref) => TrialReminderService(ref.watch(notificationSenderProvider)),
);
