import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/security/app_lock_service.dart';
import '../features/security/lock_providers.dart';

const _key = 'theme_mode';

/// Mode tema awal (dibaca dari penyimpanan sebelum runApp agar tidak berkedip).
/// Bawaan gelap: itulah tampilan utama aplikasi.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.dark);

ThemeMode parseThemeMode(String? raw) => ThemeMode.values.firstWhere(
  (m) => m.name == raw,
  orElse: () => ThemeMode.dark,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(keyValueStoreProvider).write(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

Future<ThemeMode> loadSavedThemeMode() async {
  try {
    return parseThemeMode(await const SecureKeyValueStore().read(_key));
  } catch (_) {
    return ThemeMode.dark;
  }
}
