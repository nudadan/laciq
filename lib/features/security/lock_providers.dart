import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_service.dart';

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => const SecureKeyValueStore(),
);

final biometricProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthBiometric(),
);

/// Lama di latar belakang sebelum PIN diminta lagi. Provider agar bisa diuji.
final lockGraceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

final appLockServiceProvider = Provider<AppLockService>(
  (ref) => AppLockService(ref.watch(keyValueStoreProvider)),
);

class LockState {
  const LockState({
    required this.pinEnabled,
    required this.biometricEnabled,
    required this.locked,
  });

  final bool pinEnabled;
  final bool biometricEnabled;
  final bool locked;

  LockState copyWith({
    bool? pinEnabled,
    bool? biometricEnabled,
    bool? locked,
  }) => LockState(
    pinEnabled: pinEnabled ?? this.pinEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    locked: locked ?? this.locked,
  );
}

/// Sumber kebenaran status kunci. Saat pertama dimuat, aplikasi langsung
/// terkunci jika PIN aktif.
class LockController extends AsyncNotifier<LockState> {
  AppLockService get _service => ref.read(appLockServiceProvider);

  @override
  Future<LockState> build() async {
    final hasPin = await _service.hasPin;
    return LockState(
      pinEnabled: hasPin,
      biometricEnabled: hasPin && await _service.biometricEnabled,
      locked: hasPin,
    );
  }

  void lock() {
    final s = state.value;
    if (s != null && s.pinEnabled && !s.locked) {
      state = AsyncData(s.copyWith(locked: true));
    }
  }

  void unlock() {
    final s = state.value;
    if (s != null && s.locked) state = AsyncData(s.copyWith(locked: false));
  }

  Future<void> enablePin(String pin) async {
    await _service.setPin(pin);
    state = AsyncData(state.value!.copyWith(pinEnabled: true, locked: false));
  }

  Future<void> disablePin() async {
    await _service.removePin();
    state = const AsyncData(
      LockState(pinEnabled: false, biometricEnabled: false, locked: false),
    );
  }

  Future<void> setBiometric(bool enabled) async {
    await _service.setBiometricEnabled(enabled);
    state = AsyncData(state.value!.copyWith(biometricEnabled: enabled));
  }
}

final lockControllerProvider = AsyncNotifierProvider<LockController, LockState>(
  LockController.new,
);
