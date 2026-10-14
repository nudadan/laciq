import 'dart:convert';

import 'package:dompet_pintar/features/ai/ai_config.dart' show workerUrlFrom;
import 'package:dompet_pintar/features/subscription/trial_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/harness.dart';

class _Device implements DeviceIdSource {
  _Device(this.id);
  final String? id;
  @override
  Future<String?> deviceId() async => id;
}

class _NoUser extends FakeSubscriptionStatus {
  @override
  Future<String?> appUserId() async => null;
}

void main() {
  const claimUrl = 'https://w.example/trial/claim';
  const statusUrl = 'https://w.example/trial/status';

  ({
    HttpTrialService service,
    FakeSubscriptionStatus sub,
    List<http.Request> sent,
  })
  make(
    http.Response Function(http.Request) reply, {
    String? deviceId = '99a02f40aeffec01',
    FakeSubscriptionStatus? sub,
    String claim = claimUrl,
    String status = statusUrl,
  }) {
    final sent = <http.Request>[];
    final subscription = sub ?? FakeSubscriptionStatus();
    final service = HttpTrialService(
      subscription,
      _Device(deviceId),
      client: MockClient((req) async {
        sent.add(req);
        return reply(req);
      }),
      claimUrl: claim,
      statusUrl: status,
    );
    return (service: service, sub: subscription, sent: sent);
  }

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  group('status', () {
    test('memetakan state server ke penawaran', () async {
      const cases = {
        'available': TrialOffer.available,
        'resumable': TrialOffer.resumable,
        'active': TrialOffer.active,
        'used': TrialOffer.used,
        'ultimate': TrialOffer.ultimate,
        'paused': TrialOffer.paused,
        'disabled': TrialOffer.hidden,
        'aneh': TrialOffer.hidden,
      };
      for (final e in cases.entries) {
        final t = make((_) => json({'state': e.key}));
        expect((await t.service.status()).offer, e.value, reason: e.key);
      }
    });

    test(
      'mengirim ID RevenueCat dan pengenal perangkat, dan membaca endsAt',
      () async {
        final t = make(
          (_) => json({'state': 'used', 'endsAt': '2026-11-13T04:00:00.000Z'}),
        );
        final s = await t.service.status();
        expect(s.offer, TrialOffer.used);
        expect(s.endsAt?.toUtc(), DateTime.utc(2026, 11, 13, 4));
        expect(t.sent.single.url.toString(), statusUrl);
        final body = jsonDecode(t.sent.single.body) as Map<String, dynamic>;
        expect(body, {
          'appUserId': 'test-user',
          'deviceId': '99a02f40aeffec01',
        });
      },
    );

    test('canStart hanya untuk available dan resumable', () {
      expect(const TrialStatus(TrialOffer.available).canStart, isTrue);
      expect(const TrialStatus(TrialOffer.resumable).canStart, isTrue);
      for (final o in [
        TrialOffer.hidden,
        TrialOffer.active,
        TrialOffer.used,
        TrialOffer.ultimate,
        TrialOffer.paused,
      ]) {
        expect(TrialStatus(o).canStart, isFalse, reason: o.name);
      }
    });

    test(
      'tidak pasti = hidden: galat server, jaringan, tanpa ID, tanpa URL',
      () async {
        expect(
          (await make((_) => json({}, 500)).service.status()).offer,
          TrialOffer.hidden,
        );
        expect(
          (await make(
            (_) => throw Exception('offline'),
          ).service.status()).offer,
          TrialOffer.hidden,
        );
        final noDevice = make(
          (_) => json({'state': 'available'}),
          deviceId: null,
        );
        expect((await noDevice.service.status()).offer, TrialOffer.hidden);
        expect(noDevice.sent, isEmpty);
        final noUser = make(
          (_) => json({'state': 'available'}),
          sub: _NoUser(),
        );
        expect((await noUser.service.status()).offer, TrialOffer.hidden);
        final noUrl = make((_) => json({'state': 'available'}), status: '');
        expect((await noUrl.service.status()).offer, TrialOffer.hidden);
        expect(noUrl.sent, isEmpty);
      },
    );
  });

  group('claim', () {
    test(
      'berhasil: granted, endsAt terbaca, dan hak akses dimuat ulang',
      () async {
        final t = make(
          (_) => json({
            'status': 'granted',
            'endsAt': '2026-11-13T04:00:00.000Z',
          }, 201),
        );
        final r = await t.service.claim();
        expect(r.outcome, TrialClaimOutcome.granted);
        expect(r.ok, isTrue);
        expect(r.endsAt?.toUtc(), DateTime.utc(2026, 11, 13, 4));
        expect(t.sub.refreshCount, 1);
        expect(t.sent.single.url.toString(), claimUrl);
      },
    );

    test('resumed dan active juga ok dan memuat ulang', () async {
      for (final s in ['resumed', 'active']) {
        final t = make(
          (_) => json({'status': s, 'endsAt': '2026-11-13T04:00:00Z'}),
        );
        final r = await t.service.claim();
        expect(r.ok, isTrue, reason: s);
        expect(t.sub.refreshCount, 1);
      }
    });

    test('penolakan server dipetakan dan TIDAK memuat ulang', () async {
      final cases = <(int, Map<String, Object>), TrialClaimOutcome>{
        (409, {'error': 'already_used'}): TrialClaimOutcome.alreadyUsed,
        (409, {'error': 'already_ultimate'}): TrialClaimOutcome.alreadyUltimate,
        (429, {'error': 'trial_paused'}): TrialClaimOutcome.paused,
        (429, {'error': 'promo_budget_exhausted'}):
            TrialClaimOutcome.budgetExhausted,
        (429, {'error': 'rate_limited'}): TrialClaimOutcome.failed,
        (503, {'error': 'trial_disabled'}): TrialClaimOutcome.disabled,
        (503, {'error': 'integrity_unavailable'}): TrialClaimOutcome.failed,
        (403, {'error': 'integrity_failed'}): TrialClaimOutcome.integrityFailed,
        (502, {'error': 'grant_failed'}): TrialClaimOutcome.failed,
        (500, <String, Object>{}): TrialClaimOutcome.failed,
      };
      for (final e in cases.entries) {
        final t = make((_) => json(e.key.$2, e.key.$1));
        final r = await t.service.claim();
        expect(r.outcome, e.value, reason: '${e.key}');
        expect(r.ok, isFalse);
        expect(t.sub.refreshCount, 0);
      }
    });

    test('belum siap (tanpa pengenal perangkat atau URL) tanpa permintaan jaringan', () async {
      final noDevice = make((_) => json({}), deviceId: null);
      expect(
        (await noDevice.service.claim()).outcome,
        TrialClaimOutcome.notReady,
      );
      expect(noDevice.sent, isEmpty);
      final noUrl = make((_) => json({}), claim: '');
      expect((await noUrl.service.claim()).outcome, TrialClaimOutcome.notReady);
    });

    test('jaringan gagal atau badan rusak: failed, tidak melempar', () async {
      final offline = make((_) => throw Exception('offline'));
      expect((await offline.service.claim()).outcome, TrialClaimOutcome.failed);
      final garbage = make((_) => http.Response('bukan json', 200));
      expect((await garbage.service.claim()).outcome, TrialClaimOutcome.failed);
    });
  });

  test('URL trial diturunkan dari URL ekstraksi', () {
    expect(
      workerUrlFrom('https://x.example/extract', '/trial/claim'),
      'https://x.example/trial/claim',
    );
    expect(workerUrlFrom('', '/trial/claim'), '');
    expect(workerUrlFrom('https://x.example/lain', '/trial/claim'), '');
  });
}
