import 'package:dompet_pintar/features/review/review_prompt_service.dart';
import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  late MemoryKeyValueStore store;
  late FakeReviewLauncher launcher;
  late DateTime now;

  ReviewPromptService build({FakeReviewLauncher? l}) {
    launcher = l ?? FakeReviewLauncher();
    return ReviewPromptService(
      store,
      launcher,
      clock: () => now,
      promptDelay: Duration.zero,
    );
  }

  setUp(() {
    store = MemoryKeyValueStore();
    now = DateTime(2026, 10, 1, 9);
  });

  Future<void> save(ReviewPromptService s, int times) async {
    for (var i = 0; i < times; i++) {
      await s.onTransactionSaved();
    }
  }

  test('belum cukup transaksi: tidak meminta ulasan', () async {
    final s = build();
    await save(s, 9);
    now = now.add(const Duration(days: 5));
    await save(s, 0);
    expect(launcher.requests, 0);
  });

  test('banyak transaksi tapi masih hari pertama: tidak meminta', () async {
    final s = build();
    await save(s, 12);
    expect(launcher.requests, 0);
  });

  test('cukup transaksi dan sudah beberapa hari: meminta sekali', () async {
    final s = build();
    await save(s, 5);
    now = now.add(const Duration(days: 3));
    await save(s, 5);
    expect(launcher.requests, 1);
    // Transaksi berikutnya tidak memicu lagi (jeda 120 hari).
    await save(s, 5);
    expect(launcher.requests, 1);
  });

  test('meminta lagi setelah jeda, tapi maksimal 3 kali', () async {
    final s = build();
    await save(s, 10);
    now = now.add(const Duration(days: 3));
    await save(s, 1);
    expect(launcher.requests, 1);
    for (var round = 2; round <= 5; round++) {
      now = now.add(const Duration(days: 121));
      await save(s, 1);
    }
    expect(launcher.requests, ReviewPromptService.maxPrompts);
  });

  test(
    'Play tidak tersedia (APK pasang manual): tidak meminta dan tidak mencatat',
    () async {
      final s = build(l: FakeReviewLauncher(available: false));
      await save(s, 10);
      now = now.add(const Duration(days: 3));
      await save(s, 1);
      expect(launcher.requests, 0);
      expect(await store.read('review_prompt_count'), isNull);
    },
  );

  test('kegagalan peluncur tidak melempar ke pemanggil', () async {
    final s = ReviewPromptService(store, _ThrowingLauncher(), clock: () => now);
    await save(s, 10);
    now = now.add(const Duration(days: 3));
    await s.onTransactionSaved();
  });

  test('openStoreListing meneruskan ke peluncur', () async {
    final s = build();
    await s.openStoreListing();
    expect(launcher.listingOpens, 1);
  });
}

class _ThrowingLauncher implements ReviewLauncher {
  @override
  Future<bool> isAvailable() async => throw StateError('boom');
  @override
  Future<void> requestReview() async {}
  @override
  Future<void> openStoreListing() async {}
}
