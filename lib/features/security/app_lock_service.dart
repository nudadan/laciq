import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Penyimpanan kunci-nilai untuk rahasia (hash PIN, hitungan gagal).
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Menghapus SEMUA kunci (PIN, biometrik, tema, status onboarding, dst.).
  /// Dipakai fitur "Hapus semua data" — bukan untuk operasi biasa.
  Future<void> clearAll();
}

/// Android Keystore / iOS Keychain.
class SecureKeyValueStore implements KeyValueStore {
  const SecureKeyValueStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
  @override
  Future<void> clearAll() => _storage.deleteAll();
}

class MemoryKeyValueStore implements KeyValueStore {
  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
  @override
  Future<void> clearAll() async => _data.clear();
}

abstract interface class BiometricAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometric implements BiometricAuthenticator {
  LocalAuthBiometric([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Hanya biometrik: fallback ke PIN/pola perangkat akan melewati PIN
        // aplikasi ini.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false; // dibatalkan, terkunci, atau tidak tersedia
    }
  }
}

sealed class PinCheck {
  const PinCheck();
}

class PinOk extends PinCheck {
  const PinOk();
}

class PinWrong extends PinCheck {
  const PinWrong(this.attemptsLeft);

  /// Sisa percobaan sebelum penguncian sementara.
  final int attemptsLeft;
}

class PinLockedOut extends PinCheck {
  const PinLockedOut(this.remaining);
  final Duration remaining;
}

/// PIN 6 digit, di-hash dengan PBKDF2-HMAC-SHA256 + salt acak, disimpan di
/// penyimpanan aman. Setelah [attemptsPerRound] kesalahan beruntun, input
/// dikunci sementara dengan durasi yang berlipat ganda.
///
/// Ini kunci di level aplikasi (UI lock): ia menghalangi orang yang meminjam
/// HP Anda, BUKAN enkripsi database. Data tetap tersimpan tanpa enkripsi di
/// penyimpanan privat aplikasi.
class AppLockService {
  AppLockService(this._store, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _now;

  static const pinLength = 6;
  static const attemptsPerRound = 5;
  static const baseLockout = Duration(seconds: 30);
  static const maxLockout = Duration(minutes: 15);
  static const _iterations = 10000;

  static const _kHash = 'pin_hash';
  static const _kFails = 'pin_fails';
  static const _kLockedUntil = 'pin_locked_until';
  static const _kBiometric = 'biometric_enabled';

  static bool isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  Future<bool> get hasPin async => await _store.read(_kHash) != null;

  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN harus $pinLength digit.');
    final salt = Uint8List.fromList(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final hash = _pbkdf2(utf8.encode(pin), salt, _iterations);
    await _store.write(
      _kHash,
      'pbkdf2:$_iterations:${base64.encode(salt)}:${base64.encode(hash)}',
    );
    await _resetFailures();
  }

  Future<void> removePin() async {
    for (final k in [_kHash, _kFails, _kLockedUntil, _kBiometric]) {
      await _store.delete(k);
    }
  }

  Future<Duration?> lockoutRemaining() async {
    final ms = int.tryParse(await _store.read(_kLockedUntil) ?? '');
    if (ms == null) return null;
    final left = DateTime.fromMillisecondsSinceEpoch(ms).difference(_now());
    return left > Duration.zero ? left : null;
  }

  Future<PinCheck> verifyPin(String pin) async {
    final locked = await lockoutRemaining();
    if (locked != null) return PinLockedOut(locked);

    final stored = (await _store.read(_kHash))?.split(':');
    if (stored == null || stored.length != 4 || stored[0] != 'pbkdf2') {
      return const PinWrong(0);
    }
    final expected = base64.decode(stored[3]);
    final actual = _pbkdf2(
      utf8.encode(pin),
      base64.decode(stored[2]),
      int.parse(stored[1]),
    );
    if (_constantTimeEquals(expected, actual)) {
      await _resetFailures();
      return const PinOk();
    }

    final fails = (int.tryParse(await _store.read(_kFails) ?? '') ?? 0) + 1;
    await _store.write(_kFails, '$fails');
    if (fails % attemptsPerRound == 0) {
      final round = fails ~/ attemptsPerRound; // 1, 2, 3, ...
      final duration = Duration(
        seconds: min(
          baseLockout.inSeconds * (1 << min(round - 1, 10)),
          maxLockout.inSeconds,
        ),
      );
      await _store.write(
        _kLockedUntil,
        '${_now().add(duration).millisecondsSinceEpoch}',
      );
      return PinLockedOut(duration);
    }
    return PinWrong(attemptsPerRound - fails % attemptsPerRound);
  }

  Future<bool> get biometricEnabled async =>
      await hasPin && await _store.read(_kBiometric) == '1';

  Future<void> setBiometricEnabled(bool enabled) =>
      enabled ? _store.write(_kBiometric, '1') : _store.delete(_kBiometric);

  Future<void> _resetFailures() async {
    await _store.delete(_kFails);
    await _store.delete(_kLockedUntil);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// PBKDF2-HMAC-SHA256 dengan satu blok keluaran (32 byte).
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return Uint8List.fromList(t);
  }
}
