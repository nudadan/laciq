import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/lock_providers.dart';

/// Kunci di [KeyValueStore] yang sama dipakai PIN/tema — tidak ada mekanisme
/// penyimpanan terpisah di app ini (lihat lib/core/theme_mode.dart untuk
/// presedennya pada setting non-sensitif).
const onboardingSeenKey = 'onboarding_seen';

/// Sudah lihat onboarding atau belum. Gagal baca (mis. storage error) TIDAK
/// boleh mengunci pengguna dari aplikasi — ini bukan fitur keamanan seperti
/// PIN, jadi pemanggil sebaiknya anggap error sebagai "sudah dilihat".
class OnboardingController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      await ref.read(keyValueStoreProvider).read(onboardingSeenKey) == '1';

  Future<void> complete() async {
    await ref.read(keyValueStoreProvider).write(onboardingSeenKey, '1');
    state = const AsyncData(true);
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, bool>(OnboardingController.new);
