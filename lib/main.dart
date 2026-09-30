import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/theme_mode.dart';
import 'features/subscription/subscription_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initializeDateFormatting('id_ID');
  // Status premium perlu siap sebelum frame pertama (beda dengan SDK iklan
  // yang sengaja lazy) — supaya pelanggan tidak sempat melihat iklan.
  await RevenueCatSubscriptionStatus.configureOnce();
  // Dibaca sebelum frame pertama agar tema tersimpan tidak berkedip.
  final themeMode = await loadSavedThemeMode();
  runApp(
    ProviderScope(
      overrides: [initialThemeModeProvider.overrideWithValue(themeMode)],
      child: const DompetPintarApp(),
    ),
  );
}
