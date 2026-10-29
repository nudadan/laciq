import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Persetujuan iklan lewat Google UMP (User Messaging Platform), docs/
/// RENCANA-RILIS-BERIKUTNYA.md butir 1. Hanya berlaku untuk pengguna yang memang
/// akan melihat iklan (gratis, lewat masa tenggang 30 hari): pengguna berbayar dan
/// yang masih dalam masa tenggang tidak pernah menyentuh kode ini.
///
/// Pesan persetujuan dibuat di AdMob > Privasi & pesan. Selama pesan itu belum
/// dibuat atau pengguna di luar wilayah yang mewajibkan (mis. Indonesia), UMP
/// menjawab "tidak diperlukan" dan perilaku aplikasi tidak berubah.
abstract class AdConsentService {
  /// Memperbarui info persetujuan, menampilkan formulir bila diwajibkan, lalu
  /// menjawab apakah iklan BOLEH diminta. Aman dipanggil berulang (satu proses
  /// per sesi). Gagal/tanpa jaringan: jatuh ke status tersimpan; bila belum ada,
  /// jawabannya false dan iklan tidak dimuat sampai sesi berikutnya.
  Future<bool> gatherConsent();

  /// Apakah pengguna perlu diberi jalan membuka lagi pilihan privasi (wajib di
  /// sebagian wilayah). Menyegarkan info persetujuan lebih dulu; tidak menampilkan formulir.
  Future<bool> privacyOptionsRequired();

  /// Membuka formulir pilihan privasi (ubah atau cabut persetujuan).
  Future<void> showPrivacyOptions();
}

/// Lapisan tipis di atas plugin, supaya logika di [UmpAdConsentService] bisa diuji
/// tanpa platform channel.
abstract class UmpGateway {
  Future<void> requestInfoUpdate();
  Future<void> loadAndShowFormIfRequired();
  Future<bool> canRequestAds();
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptionsForm();
}

class PluginUmpGateway implements UmpGateway {
  ConsentInformation get _info => ConsentInformation.instance;

  @override
  Future<void> requestInfoUpdate() {
    final done = Completer<void>();
    _info.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      done.complete,
      (error) => done.completeError(StateError(error.message)),
    );
    return done.future;
  }

  @override
  Future<void> loadAndShowFormIfRequired() {
    final done = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error == null) {
        done.complete();
      } else {
        done.completeError(StateError(error.message));
      }
    });
    return done.future;
  }

  @override
  Future<bool> canRequestAds() => _info.canRequestAds();

  @override
  Future<bool> privacyOptionsRequired() async =>
      await _info.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptionsForm() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error == null) {
        done.complete();
      } else {
        done.completeError(StateError(error.message));
      }
    });
    return done.future;
  }
}

class UmpAdConsentService implements AdConsentService {
  UmpAdConsentService([UmpGateway? gateway])
    : _gw = gateway ?? PluginUmpGateway();

  final UmpGateway _gw;
  Future<bool>? _gather;

  @override
  Future<bool> gatherConsent() => _gather ??= _doGather();

  Future<bool> _doGather() async {
    try {
      await _gw.requestInfoUpdate();
      await _gw.loadAndShowFormIfRequired();
    } catch (_) {
      // Tanpa jaringan atau gagal memuat formulir: lanjut ke status tersimpan.
    }
    try {
      return await _gw.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    try {
      await _gw.requestInfoUpdate();
    } catch (_) {
      // Pakai status tersimpan.
    }
    try {
      return await _gw.privacyOptionsRequired();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptions() => _gw.showPrivacyOptionsForm();
}

final adConsentServiceProvider = Provider<AdConsentService>(
  (ref) => UmpAdConsentService(),
);
