import 'package:dompet_pintar/features/cloud_backup/cloud_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('galat konfigurasi (28444) tidak lagi disebut masalah koneksi', () {
    final msg = signInFailureMessage(
      GoogleSignInExceptionCode.clientConfigurationError,
      '[28444] Developer console is not set up correctly.',
    );
    expect(msg, contains('belum dikonfigurasi'));
    expect(msg, contains('kode: clientConfigurationError, 28444'));
    expect(msg, isNot(contains('koneksi internet')));
  });

  test('galat provider juga ditandai sebagai konfigurasi', () {
    final msg = signInFailureMessage(
      GoogleSignInExceptionCode.providerConfigurationError,
      null,
    );
    expect(msg, contains('support@hardan-ti.com'));
    expect(msg, contains('kode: providerConfigurationError)'));
  });

  test('UI tidak tersedia dan terputus punya pesan sendiri', () {
    expect(
      signInFailureMessage(GoogleSignInExceptionCode.uiUnavailable, null),
      contains('akun Google di perangkat'),
    );
    expect(
      signInFailureMessage(GoogleSignInExceptionCode.interrupted, null),
      contains('terputus'),
    );
  });

  test('galat lain: saran koneksi tetap ada, kode tetap disertakan', () {
    final msg = signInFailureMessage(
      GoogleSignInExceptionCode.unknownError,
      '[16] something',
    );
    expect(msg, contains('Periksa koneksi internet'));
    expect(msg, contains('kode: unknownError, 16'));
  });
}
