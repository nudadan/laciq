import 'dart:async';
import 'dart:convert';

import 'package:android_id/android_id.dart';
import 'package:http/http.dart' as http;

import '../ai/ai_config.dart';
import 'subscription_status.dart';

/// Layanan uji coba Ultimate 30 hari tanpa kartu
/// (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md). Server (Worker) yang
/// memutuskan kelayakan dan memberi hibah; aplikasi hanya meminta dan menampilkan.

/// Apakah dan bagaimana penawaran uji coba ditampilkan.
enum TrialOffer {
  /// Jangan tampilkan apa pun: trial mati, Worker tidak terjangkau, atau tidak pasti.
  hidden,

  /// Perangkat ini boleh memulai trial baru.
  available,

  /// Perangkat punya trial yang masih berjalan; ID baru melanjutkan SISA hari.
  resumable,

  /// Hibah uji coba sedang berjalan.
  active,

  /// Perangkat sudah memakai trial dan sudah habis.
  used,

  /// Sudah berlangganan Ultimate.
  ultimate,

  /// Pagar global (klaim harian/anggaran promo) sedang penuh; coba lagi nanti.
  paused,
}

class TrialStatus {
  const TrialStatus(this.offer, {this.endsAt});

  static const hidden = TrialStatus(TrialOffer.hidden);

  final TrialOffer offer;

  /// Kedaluwarsa trial (untuk active, resumable, dan used).
  final DateTime? endsAt;

  /// Tombol "Coba gratis" boleh tampil.
  bool get canStart =>
      offer == TrialOffer.available || offer == TrialOffer.resumable;
}

enum TrialClaimOutcome {
  /// Trial baru diberikan.
  granted,

  /// Pasang ulang di masa trial: ID baru mendapat sisa hari.
  resumed,

  /// Hibah sudah aktif (idempoten).
  active,
  alreadyUsed,
  alreadyUltimate,
  paused,
  budgetExhausted,
  disabled,
  integrityFailed,

  /// ID RevenueCat, pengenal perangkat, atau URL belum siap.
  notReady,

  /// Jaringan atau galat server; boleh dicoba lagi.
  failed,
}

class TrialClaimResult {
  const TrialClaimResult(this.outcome, {this.endsAt});

  final TrialClaimOutcome outcome;
  final DateTime? endsAt;

  /// Trial aktif setelah klaim (baru, dilanjutkan, atau sudah berjalan).
  bool get ok =>
      outcome == TrialClaimOutcome.granted ||
      outcome == TrialClaimOutcome.resumed ||
      outcome == TrialClaimOutcome.active;
}

abstract interface class TrialService {
  /// Status penawaran untuk perangkat ini. Tidak pernah melempar: tidak pasti
  /// sama dengan [TrialStatus.hidden].
  Future<TrialStatus> status();

  /// Memulai (atau melanjutkan) trial. Tidak pernah melempar.
  Future<TrialClaimResult> claim();
}

/// Pengenal perangkat yang bertahan pasang ulang. Disembunyikan di balik
/// antarmuka supaya tes memakai nilai palsu.
abstract interface class DeviceIdSource {
  Future<String?> deviceId();
}

/// `ANDROID_ID` (dibatasi per kunci tanda tangan aplikasi). Terbukti bertahan
/// setelah copot-pasang pada perangkat uji (Fase 0). Server hanya menyimpan
/// HMAC-nya; nilai mentah tidak disimpan.
class AndroidDeviceIdSource implements DeviceIdSource {
  @override
  Future<String?> deviceId() async {
    try {
      final id = await const AndroidId().getId();
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }
}

class HttpTrialService implements TrialService {
  HttpTrialService(
    this._subscription,
    this._device, {
    http.Client? client,
    String? claimUrl,
    String? statusUrl,
    this._timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _claimUrl = claimUrl ?? kTrialClaimUrl,
       _statusUrl = statusUrl ?? kTrialStatusUrl;

  final SubscriptionStatus _subscription;
  final DeviceIdSource _device;
  final http.Client _client;
  final String _claimUrl;
  final String _statusUrl;
  final Duration _timeout;

  Future<({http.Response response, Map<String, dynamic> body})?> _post(
    String url,
  ) async {
    if (url.isEmpty) return null;
    final userId = await _subscription.appUserId();
    final deviceId = await _device.deviceId();
    if (userId == null || deviceId == null) return null;
    final response = await _client
        .post(
          Uri.parse(url),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'appUserId': userId, 'deviceId': deviceId}),
        )
        .timeout(_timeout);
    var body = const <String, dynamic>{};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // Tubuh bukan JSON: ditangani lewat kode status.
    }
    return (response: response, body: body);
  }

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  @override
  Future<TrialStatus> status() async {
    try {
      final r = await _post(_statusUrl);
      if (r == null || r.response.statusCode != 200) return TrialStatus.hidden;
      final offer = switch (r.body['state']) {
        'available' => TrialOffer.available,
        'resumable' => TrialOffer.resumable,
        'active' => TrialOffer.active,
        'used' => TrialOffer.used,
        'ultimate' => TrialOffer.ultimate,
        'paused' => TrialOffer.paused,
        _ => TrialOffer.hidden, // 'disabled' dan nilai tak dikenal
      };
      return TrialStatus(offer, endsAt: _date(r.body['endsAt']));
    } catch (_) {
      return TrialStatus.hidden;
    }
  }

  @override
  Future<TrialClaimResult> claim() async {
    try {
      final r = await _post(_claimUrl);
      if (r == null) return const TrialClaimResult(TrialClaimOutcome.notReady);
      final endsAt = _date(r.body['endsAt']);
      final error = r.body['error'];
      final TrialClaimOutcome outcome;
      switch (r.response.statusCode) {
        case 200 || 201:
          outcome = switch (r.body['status']) {
            'granted' => TrialClaimOutcome.granted,
            'resumed' => TrialClaimOutcome.resumed,
            'active' => TrialClaimOutcome.active,
            _ => TrialClaimOutcome.failed,
          };
        case 409:
          outcome = error == 'already_ultimate'
              ? TrialClaimOutcome.alreadyUltimate
              : error == 'already_used'
              ? TrialClaimOutcome.alreadyUsed
              : TrialClaimOutcome.failed;
        case 429:
          outcome = switch (error) {
            'trial_paused' => TrialClaimOutcome.paused,
            'promo_budget_exhausted' => TrialClaimOutcome.budgetExhausted,
            _ => TrialClaimOutcome.failed,
          };
        case 503:
          outcome = error == 'trial_disabled'
              ? TrialClaimOutcome.disabled
              : TrialClaimOutcome.failed;
        case 403:
          outcome = TrialClaimOutcome.integrityFailed;
        default:
          outcome = TrialClaimOutcome.failed;
      }
      final result = TrialClaimResult(outcome, endsAt: endsAt);
      if (result.ok) {
        // Hibah baru harus langsung terlihat oleh hak akses aplikasi.
        await _subscription.refresh();
      }
      return result;
    } catch (_) {
      return const TrialClaimResult(TrialClaimOutcome.failed);
    }
  }
}
