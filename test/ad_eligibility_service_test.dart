import 'package:dompet_pintar/features/ads/ad_eligibility_service.dart';
import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryKeyValueStore store;
  late DateTime now;
  late AdEligibilityService service;

  setUp(() {
    store = MemoryKeyValueStore();
    now = DateTime(2026, 9, 23, 10);
    service = AdEligibilityService(store, clock: () => now);
  });

  test('belum layak sebelum first-use pernah dicatat', () async {
    expect(await service.shouldShowAds(), isFalse);
  });

  test('belum layak di hari ke-0 setelah dicatat', () async {
    await service.recordFirstUseIfAbsent();
    expect(await service.shouldShowAds(), isFalse);
  });

  test(
    'belum layak tepat sebelum masa tenggang habis, layak tepat saat habis',
    () async {
      await service.recordFirstUseIfAbsent();

      now = now.add(
        AdEligibilityService.gracePeriod - const Duration(seconds: 1),
      );
      expect(await service.shouldShowAds(), isFalse);

      now = now.add(const Duration(seconds: 1));
      expect(await service.shouldShowAds(), isTrue);
    },
  );

  test('tetap layak jauh setelah masa tenggang', () async {
    await service.recordFirstUseIfAbsent();
    now = now.add(AdEligibilityService.gracePeriod * 3);
    expect(await service.shouldShowAds(), isTrue);
  });

  test('recordFirstUseIfAbsent kedua kali tidak mereset patokan waktu', () async {
    await service.recordFirstUseIfAbsent();
    final firstUseAt = await store.read('first_use_at');

    final partway = AdEligibilityService.gracePeriod ~/ 2;
    now = now.add(partway);
    await service.recordFirstUseIfAbsent(); // dipanggil lagi, harus no-op

    expect(await store.read('first_use_at'), firstUseAt);
    // Total masa tenggang sudah lewat sejak first-use ASLI, bukan 0 dari sini.
    now = now.add(AdEligibilityService.gracePeriod - partway);
    expect(await service.shouldShowAds(), isTrue);
  });
}
