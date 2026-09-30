import 'package:flutter/material.dart';
import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

const _pin = '123456';

Future<void> _setPin(AppLockService lock) => lock.setPin(_pin);

Future<void> _background(WidgetTester tester) async {
  final b = tester.binding;
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    b.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

Future<void> _foreground(WidgetTester tester) async {
  final b = tester.binding;
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    b.handleAppLifecycleStateChanged(s);
  }
  await settle(tester);
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('membuka aplikasi', () {
    appTest('tanpa PIN, aplikasi langsung terbuka', (tester, h) async {
      expect(find.text('Total Saldo'), findsOneWidget);
      expect(find.text('Masukkan PIN'), findsNothing);
    });

    appTest('dengan PIN, aplikasi terkunci dan isinya tidak terlihat', (
      tester,
      h,
    ) async {
      expect(find.text('Masukkan PIN'), findsOneWidget);
      expect(find.text('Total Saldo'), findsNothing);
    }, preset: _setPin);

    appTest('PIN benar membuka kunci', (tester, h) async {
      await typePin(tester, _pin);
      expect(find.text('Masukkan PIN'), findsNothing);
      expect(find.text('Total Saldo'), findsOneWidget);
    }, preset: _setPin);

    appTest('PIN salah menampilkan sisa percobaan dan tetap terkunci', (
      tester,
      h,
    ) async {
      await typePin(tester, '000000');
      expect(find.text('PIN salah. Sisa percobaan: 4'), findsOneWidget);
      expect(find.text('Total Saldo'), findsNothing);
    }, preset: _setPin);

    appTest(
      'lima kali salah mengunci input sementara, bahkan untuk PIN benar',
      (tester, h) async {
        for (var i = 0; i < 5; i++) {
          await typePin(tester, '000000');
        }
        expect(find.textContaining('Terlalu banyak percobaan'), findsOneWidget);

        await typePin(tester, _pin); // keypad nonaktif: tidak berpengaruh
        expect(find.text('Total Saldo'), findsNothing);
        expect(find.textContaining('Terlalu banyak percobaan'), findsOneWidget);
      },
      preset: _setPin,
    );

    appTest(
      'biometrik berhasil membuka kunci tanpa PIN',
      (tester, h) async {
        expect(h.biometric.prompts, 1);
        expect(find.text('Total Saldo'), findsOneWidget);
      },
      preset: (lock) async {
        await lock.setPin(_pin);
        await lock.setBiometricEnabled(true);
      },
    );

    appTest(
      'biometrik gagal: tetap terkunci dan PIN masih bisa dipakai',
      (tester, h) async {
        expect(find.text('Total Saldo'), findsNothing);
        expect(find.byIcon(Icons.fingerprint), findsOneWidget);
        await typePin(tester, _pin);
        expect(find.text('Total Saldo'), findsOneWidget);
      },
      biometric: FakeBiometric(succeeds: false),
      preset: (lock) async {
        await lock.setPin(_pin);
        await lock.setBiometricEnabled(true);
      },
    );
  });

  group('pengaturan PIN', () {
    appTest('membuat PIN lewat Pengaturan', (tester, h) async {
      await _openSettings(tester);
      expect(find.text('Ubah PIN'), findsNothing);

      await tester.tap(find.text('Kunci aplikasi dengan PIN'));
      await settle(tester);
      expect(find.text('Masukkan 6 digit PIN'), findsOneWidget);
      await typePin(tester, _pin);
      expect(find.text('Ulangi PIN untuk konfirmasi'), findsOneWidget);
      await typePin(tester, _pin);

      expect(await h.lock.hasPin, isTrue);
      expect(find.text('Ubah PIN'), findsOneWidget); // kembali ke Pengaturan
      expect(find.text('Masukkan PIN'), findsNothing); // tidak terkunci sendiri
    });

    appTest('konfirmasi tidak cocok mengulang dari awal dan tidak menyimpan', (
      tester,
      h,
    ) async {
      await _openSettings(tester);
      await tester.tap(find.text('Kunci aplikasi dengan PIN'));
      await settle(tester);
      await typePin(tester, _pin);
      await typePin(tester, '654321');

      expect(find.text('PIN tidak cocok. Ulangi dari awal.'), findsOneWidget);
      expect(find.text('Masukkan 6 digit PIN'), findsOneWidget);
      expect(await h.lock.hasPin, isFalse);
    });

    appTest('menonaktifkan PIN meminta PIN saat ini', (tester, h) async {
      await typePin(tester, _pin); // buka kunci
      await _openSettings(tester);
      await tester.tap(find.text('Kunci aplikasi dengan PIN'));
      await settle(tester);

      await typePin(tester, '000000'); // salah: PIN tetap aktif
      expect(await h.lock.hasPin, isTrue);
      // Membuka kunci tadi (PIN benar) sudah mereset hitungan gagal.
      expect(find.text('PIN salah. Sisa percobaan: 4'), findsOneWidget);

      await typePin(tester, _pin);
      expect(await h.lock.hasPin, isFalse);
      expect(find.text('Ubah PIN'), findsNothing);
    }, preset: _setPin);
  });

  group('penguncian ulang dari latar belakang', () {
    appTest(
      'terkunci lagi bila di latar belakang melewati masa tenggang',
      (tester, h) async {
        await typePin(tester, _pin);
        expect(find.text('Total Saldo'), findsOneWidget);

        await _background(tester);
        // Selama di latar belakang isi ditutup (thumbnail app switcher).
        expect(find.byIcon(Icons.lock_outline), findsWidgets);
        await _foreground(tester);

        expect(find.text('Masukkan PIN'), findsOneWidget);
        expect(find.text('Total Saldo'), findsNothing);
      },
      preset: _setPin,
      grace: Duration.zero,
    );

    appTest('tidak terkunci bila hanya sebentar di latar belakang', (
      tester,
      h,
    ) async {
      await typePin(tester, _pin);
      await _background(tester);
      await _foreground(tester);

      expect(find.text('Total Saldo'), findsOneWidget);
      expect(find.text('Masukkan PIN'), findsNothing);
    }, preset: _setPin); // masa tenggang bawaan 30 detik

    appTest('tanpa PIN, latar belakang tidak pernah mengunci', (
      tester,
      h,
    ) async {
      await _background(tester);
      await _foreground(tester);
      expect(find.text('Total Saldo'), findsOneWidget);
    }, grace: Duration.zero);
  });
}
