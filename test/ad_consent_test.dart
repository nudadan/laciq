import 'package:dompet_pintar/data/providers.dart';
import 'package:dompet_pintar/features/ads/ad_consent_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Persetujuan iklan (UMP): urutan panggilan, kegagalan yang tidak boleh melumpuhkan
/// aplikasi, dan tombol "Pilihan privasi iklan" di Pengaturan.
class FakeUmp implements UmpGateway {
  FakeUmp({
    this.canRequest = true,
    this.optionsRequired = false,
    this.failUpdate = false,
    this.failForm = false,
    this.failCanRequest = false,
    this.failOptions = false,
  });

  bool canRequest;
  bool optionsRequired;
  bool failUpdate;
  bool failForm;
  bool failCanRequest;
  bool failOptions;
  final calls = <String>[];

  @override
  Future<void> requestInfoUpdate() async {
    calls.add('update');
    if (failUpdate) throw StateError('tanpa jaringan');
  }

  @override
  Future<void> loadAndShowFormIfRequired() async {
    calls.add('form');
    if (failForm) throw StateError('formulir gagal');
  }

  @override
  Future<bool> canRequestAds() async {
    calls.add('can');
    if (failCanRequest) throw StateError('x');
    return canRequest;
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    calls.add('options?');
    if (failOptions) throw StateError('x');
    return optionsRequired;
  }

  @override
  Future<void> showPrivacyOptionsForm() async => calls.add('showOptions');
}

/// Layanan palsu untuk uji UI Pengaturan.
class FakeAdConsent implements AdConsentService {
  FakeAdConsent({this.optionsRequired = false});
  final bool optionsRequired;
  int checks = 0;
  int shown = 0;
  int gathered = 0;

  /// Persetujuan belum diberikan: banner TIDAK boleh menyentuh SDK iklan (di tes, plugin
  /// tidak ada, jadi bila banner memuat iklan tes akan gagal dengan MissingPluginException).
  @override
  Future<bool> gatherConsent() async {
    gathered++;
    return false;
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    checks++;
    return optionsRequired;
  }

  @override
  Future<void> showPrivacyOptions() async => shown++;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('UmpAdConsentService', () {
    test('urutan: perbarui info, tampilkan formulir bila perlu, lalu tanya boleh iklan', () async {
      final gw = FakeUmp(canRequest: true);
      expect(await UmpAdConsentService(gw).gatherConsent(), isTrue);
      expect(gw.calls, ['update', 'form', 'can']);
    });

    test('belum ada persetujuan: iklan tidak boleh diminta', () async {
      final gw = FakeUmp(canRequest: false);
      expect(await UmpAdConsentService(gw).gatherConsent(), isFalse);
    });

    test('tanpa jaringan: jatuh ke status tersimpan, tidak melempar', () async {
      final gw = FakeUmp(failUpdate: true, canRequest: true);
      expect(await UmpAdConsentService(gw).gatherConsent(), isTrue);
      // Gagal memperbarui: tidak mencoba formulir, langsung memeriksa status.
      expect(gw.calls, ['update', 'can']);
    });

    test(
      'formulir gagal dimuat: tetap menjawab dari status tersimpan',
      () async {
        final gw = FakeUmp(failForm: true, canRequest: false);
        expect(await UmpAdConsentService(gw).gatherConsent(), isFalse);
        expect(gw.calls, ['update', 'form', 'can']);
      },
    );

    test(
      'status tidak terbaca: false (iklan tidak dimuat), tidak melempar',
      () async {
        final gw = FakeUmp(failCanRequest: true);
        expect(await UmpAdConsentService(gw).gatherConsent(), isFalse);
      },
    );

    test(
      'satu proses per sesi: pemanggilan berulang memakai hasil yang sama',
      () async {
        final gw = FakeUmp();
        final s = UmpAdConsentService(gw);
        final results = await Future.wait([
          s.gatherConsent(),
          s.gatherConsent(),
        ]);
        expect(results, [true, true]);
        await s.gatherConsent();
        expect(gw.calls.where((c) => c == 'update').length, 1);
        expect(gw.calls.where((c) => c == 'form').length, 1);
      },
    );

    test(
      'pilihan privasi: menyegarkan info lalu membaca status; gagal = false',
      () async {
        final yes = FakeUmp(optionsRequired: true);
        expect(await UmpAdConsentService(yes).privacyOptionsRequired(), isTrue);
        expect(yes.calls, ['update', 'options?']);

        expect(
          await UmpAdConsentService(
            FakeUmp(optionsRequired: true, failUpdate: true),
          ).privacyOptionsRequired(),
          isTrue,
          reason: 'gagal memperbarui memakai status tersimpan',
        );
        expect(
          await UmpAdConsentService(FakeUmp(failOptions: true))
              .privacyOptionsRequired(),
          isFalse,
        );
      },
    );

    test('showPrivacyOptions membuka formulir pilihan privasi', () async {
      final gw = FakeUmp();
      await UmpAdConsentService(gw).showPrivacyOptions();
      expect(gw.calls, ['showOptions']);
    });
  });

  group('Pengaturan: Pilihan privasi iklan', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Pengaturan'));
      await settle(tester);
    }

    final consent = FakeAdConsent(optionsRequired: true);
    appTest(
      'pengguna yang melihat iklan di wilayah wajib: tombol tampil dan membuka formulir',
      (tester, h) async {
        await openSettings(tester);
        expect(find.text('Pilihan privasi iklan'), findsOneWidget);
        await tester.tap(find.text('Pilihan privasi iklan'));
        await settle(tester);
        expect(consent.shown, 1);
        // Banner meminta persetujuan lebih dulu; tanpa persetujuan tidak ada iklan.
        expect(consent.gathered, greaterThan(0));
      },
      extraOverrides: [
        shouldShowAdsProvider.overrideWith((ref) async => true),
        adConsentServiceProvider.overrideWithValue(consent),
      ],
    );

    final notRequired = FakeAdConsent(optionsRequired: false);
    appTest(
      'wilayah tanpa kewajiban: tombol tidak tampil',
      (tester, h) async {
        await openSettings(tester);
        expect(find.text('Pilihan privasi iklan'), findsNothing);
        expect(notRequired.checks, greaterThan(0));
      },
      extraOverrides: [
        shouldShowAdsProvider.overrideWith((ref) async => true),
        adConsentServiceProvider.overrideWithValue(notRequired),
      ],
    );

    final untouched = FakeAdConsent(optionsRequired: true);
    appTest(
      'pengguna yang tidak melihat iklan (premium/masa tenggang): UMP tidak disentuh sama sekali',
      (tester, h) async {
        await openSettings(tester);
        expect(find.text('Pilihan privasi iklan'), findsNothing);
        expect(untouched.checks, 0);
      },
      extraOverrides: [
        shouldShowAdsProvider.overrideWith((ref) async => false),
        adConsentServiceProvider.overrideWithValue(untouched),
      ],
    );
  });
}
