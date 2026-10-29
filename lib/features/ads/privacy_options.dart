import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'ad_consent_service.dart';

/// Apakah Pengaturan perlu menampilkan "Pilihan privasi iklan". Hanya untuk
/// pengguna yang memang akan melihat iklan (gratis, lewat masa tenggang); yang lain
/// tidak pernah menyentuh UMP. Bila UMP menyatakan tombol itu wajib (sebagian wilayah),
/// tampilkan agar pengguna bisa mengubah atau mencabut persetujuan.
final privacyOptionsRequiredProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final showsAds = await ref.watch(shouldShowAdsProvider.future);
  if (!showsAds) return false;
  return ref.watch(adConsentServiceProvider).privacyOptionsRequired();
});
