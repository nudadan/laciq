import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/lock_providers.dart';

/// Kunci di [KeyValueStore] yang sama dipakai PIN/tema (lihat
/// lib/features/onboarding/onboarding_providers.dart untuk presedennya).
const trendWindowMonthsKey = 'trend_window_months';

const trendWindowOptions = [3, 6, 12];

/// Jendela waktu (dalam bulan) untuk halaman Analisa Tren. Bawaan 6 bulan.
class TrendWindowController extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final raw = await ref
        .read(keyValueStoreProvider)
        .read(trendWindowMonthsKey);
    final months = int.tryParse(raw ?? '');
    return trendWindowOptions.contains(months) ? months! : 6;
  }

  Future<void> set(int months) async {
    await ref
        .read(keyValueStoreProvider)
        .write(trendWindowMonthsKey, '$months');
    state = AsyncData(months);
  }
}

final trendWindowMonthsProvider =
    AsyncNotifierProvider<TrendWindowController, int>(
      TrendWindowController.new,
    );
