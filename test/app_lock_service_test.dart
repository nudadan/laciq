import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryKeyValueStore store;
  late DateTime now;
  late AppLockService service;

  setUp(() {
    store = MemoryKeyValueStore();
    now = DateTime(2026, 9, 21, 10);
    service = AppLockService(store, clock: () => now);
  });

  Future<PinCheck> wrong() => service.verifyPin('000000');

  test('PIN valid hanya 6 digit angka', () {
    expect(AppLockService.isValidPin('123456'), isTrue);
    for (final bad in ['12345', '1234567', 'abcdef', '12 456', '']) {
      expect(AppLockService.isValidPin(bad), isFalse, reason: bad);
    }
    expect(() => service.setPin('123'), throwsArgumentError);
  });

  test(
    'PIN tidak disimpan sebagai teks biasa dan salt berbeda tiap kali',
    () async {
      await service.setPin('123456');
      final first = await store.read('pin_hash');
      expect(first, isNot(contains('123456')));
      expect(first, startsWith('pbkdf2:'));

      await service.setPin('123456');
      expect(await store.read('pin_hash'), isNot(first));
    },
  );

  test('PIN benar diterima, PIN salah ditolak dengan sisa percobaan', () async {
    await service.setPin('123456');
    expect(await service.verifyPin('123456'), isA<PinOk>());
    final r = await wrong();
    expect(r, isA<PinWrong>());
    expect((r as PinWrong).attemptsLeft, 4);
  });

  test(
    'lima kesalahan beruntun mengunci 30 detik, lalu berlipat ganda',
    () async {
      await service.setPin('123456');
      for (var i = 0; i < 4; i++) {
        expect(await wrong(), isA<PinWrong>());
      }
      final fifth = await wrong();
      expect(fifth, isA<PinLockedOut>());
      expect((fifth as PinLockedOut).remaining, const Duration(seconds: 30));

      // Selama terkunci, bahkan PIN yang benar pun ditolak.
      expect(await service.verifyPin('123456'), isA<PinLockedOut>());

      // Setelah masa kunci lewat, PIN benar diterima kembali.
      now = now.add(const Duration(seconds: 31));
      expect(await service.lockoutRemaining(), isNull);
      // Salah lagi 5x -> putaran kedua = 60 detik.
      for (var i = 0; i < 4; i++) {
        await wrong();
      }
      final second = await wrong();
      expect((second as PinLockedOut).remaining, const Duration(seconds: 60));
    },
  );

  test('penguncian dibatasi maksimum 15 menit', () async {
    await service.setPin('123456');
    Duration? last;
    for (var round = 0; round < 12; round++) {
      for (var i = 0; i < 5; i++) {
        final r = await wrong();
        if (r is PinLockedOut) last = r.remaining;
      }
      now = now.add(const Duration(hours: 1));
    }
    expect(last, const Duration(minutes: 15));
  });

  test(
    'hitungan gagal dan kunci bertahan meski service dibuat ulang',
    () async {
      await service.setPin('123456');
      for (var i = 0; i < 5; i++) {
        await wrong();
      }
      final restarted = AppLockService(store, clock: () => now);
      expect(await restarted.verifyPin('123456'), isA<PinLockedOut>());
    },
  );

  test('PIN benar mereset hitungan gagal', () async {
    await service.setPin('123456');
    await wrong();
    await wrong();
    await service.verifyPin('123456');
    final r = await wrong();
    expect((r as PinWrong).attemptsLeft, 4);
  });

  test(
    'biometrik hanya aktif bila PIN ada; removePin menghapus semuanya',
    () async {
      expect(await service.biometricEnabled, isFalse);
      await service.setBiometricEnabled(true);
      expect(await service.biometricEnabled, isFalse); // belum ada PIN

      await service.setPin('123456');
      expect(await service.biometricEnabled, isTrue);

      await service.removePin();
      expect(await service.hasPin, isFalse);
      expect(await service.biometricEnabled, isFalse);
      expect(await store.read('pin_hash'), isNull);
    },
  );

  test(
    'KeyValueStore.clearAll menghapus semua kunci, bukan hanya milik PIN',
    () async {
      await service.setPin('123456');
      await store.write('theme_mode', 'dark');
      await store.write('onboarding_seen', '1');

      await store.clearAll();

      expect(await store.read('pin_hash'), isNull);
      expect(await store.read('theme_mode'), isNull);
      expect(await store.read('onboarding_seen'), isNull);
      expect(await service.hasPin, isFalse);
    },
  );
}
