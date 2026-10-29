import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/providers.dart';
import 'ad_consent_service.dart';
import 'ad_unit_ids.dart';

/// Gerbang tampil/tidaknya banner iklan di bawah navigasi utama. Hanya
/// membangun [_HomeBannerAd] (dan dengan itu, menyentuh plugin AdMob sama
/// sekali) kalau [shouldShowAdsProvider] sudah resolve true — selama masa
/// tenggang 30 hari (atau saat status belum diketahui), ini collapse ke
/// tinggi nol tanpa memuat apa pun.
class HomeAdSlot extends ConsumerWidget {
  const HomeAdSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(shouldShowAdsProvider).value ?? false;
    return show ? const _HomeBannerAd() : const SizedBox.shrink();
  }
}

class _HomeBannerAd extends ConsumerStatefulWidget {
  const _HomeBannerAd();

  @override
  ConsumerState<_HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends ConsumerState<_HomeBannerAd> {
  static bool _sdkInitialized = false;

  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Persetujuan (UMP) SEBELUM SDK iklan diinisialisasi atau iklan diminta. Di luar
    // wilayah yang mewajibkan, jawabannya langsung "boleh" tanpa formulir.
    final canRequest = await ref.read(adConsentServiceProvider).gatherConsent();
    if (!canRequest || !mounted) return;
    if (!_sdkInitialized) {
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
    }
    final ad = BannerAd(
      adUnitId: kBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _ad = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
