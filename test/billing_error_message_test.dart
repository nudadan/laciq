import 'package:dompet_pintar/features/subscription/subscription_status.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Galat SDK RevenueCat sampai ke Dart sebagai PlatformException dengan `code`
/// berisi indeks [PurchasesErrorCode].
PlatformException _sdkError(PurchasesErrorCode code) =>
    PlatformException(code: code.index.toString(), message: 'galat uji');

void main() {
  group('classifyBillingError', () {
    test('galat jaringan dan waktu habis dikelompokkan sebagai network', () {
      for (final code in [
        PurchasesErrorCode.networkError,
        PurchasesErrorCode.offlineConnectionError,
        PurchasesErrorCode.productRequestTimeout,
        PurchasesErrorCode.apiEndpointBlocked,
      ]) {
        expect(
          classifyBillingError(_sdkError(code)),
          BillingFailure.network,
          reason: '$code',
        );
      }
    });

    test(
      'Google Play tidak bisa dipakai dikelompokkan sebagai storeUnavailable',
      () {
        // BILLING_UNAVAILABLE di Android (mis. emulator tanpa Play Store)
        // dilaporkan RevenueCat sebagai purchaseNotAllowedError.
        for (final code in [
          PurchasesErrorCode.purchaseNotAllowedError,
          PurchasesErrorCode.storeProblemError,
        ]) {
          expect(
            classifyBillingError(_sdkError(code)),
            BillingFailure.storeUnavailable,
            reason: '$code',
          );
        }
      },
    );

    test('galat lain dikelompokkan sebagai other', () {
      for (final code in [
        PurchasesErrorCode.configurationError,
        PurchasesErrorCode.unexpectedBackendResponseError,
        PurchasesErrorCode.unknownError,
      ]) {
        expect(
          classifyBillingError(_sdkError(code)),
          BillingFailure.other,
          reason: '$code',
        );
      }
    });

    test('masukan tak terduga tidak melempar dan jatuh ke other', () {
      expect(classifyBillingError(StateError('x')), BillingFailure.other);
      expect(classifyBillingError('teks biasa'), BillingFailure.other);
      // Kode non-numerik (num.parse gagal) dan kode di luar rentang enum.
      expect(
        classifyBillingError(PlatformException(code: 'bukan-angka')),
        BillingFailure.other,
      );
      expect(
        classifyBillingError(PlatformException(code: '9999')),
        BillingFailure.other,
      );
    });
  });

  group('billingErrorMessage', () {
    test('network: tetap menyuruh memeriksa koneksi internet', () {
      final msg = billingErrorMessage(
        'memuat paket langganan',
        _sdkError(PurchasesErrorCode.networkError),
      );
      expect(msg, 'Gagal memuat paket langganan. Periksa koneksi internetmu.');
    });

    test('storeUnavailable: menyebut Google Play, bukan koneksi internet', () {
      final msg = billingErrorMessage(
        'memulihkan pembelian',
        _sdkError(PurchasesErrorCode.purchaseNotAllowedError),
      );
      expect(msg, startsWith('Gagal memulihkan pembelian.'));
      expect(msg, contains('Google Play'));
      expect(msg, contains('akun Google'));
      expect(msg, isNot(contains('koneksi internet')));
    });

    test('other: pesan umum tanpa menuduh koneksi', () {
      final msg = billingErrorMessage(
        'memuat paket langganan',
        _sdkError(PurchasesErrorCode.configurationError),
      );
      expect(msg, 'Gagal memuat paket langganan. Coba lagi nanti.');
    });
  });
}
