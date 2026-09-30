import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/app.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/providers.dart';
import 'package:dompet_pintar/core/notification_sender.dart';
import 'package:dompet_pintar/features/ai/ai_extraction_service.dart';
import 'package:dompet_pintar/features/cloud_backup/cloud_backup_service.dart';
import 'package:dompet_pintar/features/onboarding/onboarding_providers.dart';
import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:dompet_pintar/features/security/lock_providers.dart';
import 'package:dompet_pintar/features/subscription/subscription_plans.dart';
import 'package:dompet_pintar/features/subscription/subscription_status.dart';
import 'package:dompet_pintar/features/transactions/receipt_scanner.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drift bekerja dengan async sungguhan, sementara testWidgets memakai jam
/// palsu. Beri database waktu nyata untuk menjawab dan majukan jam palsu agar
/// timer/animasi berjalan. (pumpAndSettle tidak dipakai: ia menunggu selamanya
/// karena stream DB.)
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class FakeBiometric implements BiometricAuthenticator {
  FakeBiometric({this.available = true, this.succeeds = true});
  final bool available;
  final bool succeeds;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return succeeds;
  }
}

/// Mencatat notifikasi yang "dikirim" tanpa menyentuh platform channel
/// sungguhan.
class FakeNotificationSender implements NotificationSender {
  final List<({int id, String title, String body})> sent = [];
  final List<({int id, String title, String body, DateTime at})> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    sent.add((id: id, title: title, body: body));
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    scheduled.removeWhere((s) => s.id == id);
    scheduled.add((id: id, title: title, body: body, at: at));
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.removeWhere((s) => s.id == id);
    cancelled.add(id);
  }
}

/// Status langganan palsu — default belum premium, sama seperti pengguna
/// baru sungguhan. Plugin `purchases_flutter` sungguhan tidak pernah
/// tersentuh di tes (pola sama AdMob).
class FakeSubscriptionStatus implements SubscriptionStatus {
  // Named param stays public (`premium`) while the backing field is
  // private (`_premium`), so an initializing formal doesn't fit here.
  // ignore: prefer_initializing_formals
  FakeSubscriptionStatus({bool premium = false, bool ultimate = false})
    : _premium = premium || ultimate,
      _ultimate = ultimate {
    // Nilai awal dikirim lewat generator async* (lihat watchIsPremium), BUKAN
    // onListen pada stream broadcast: Riverpod menjeda langganan saat rantai
    // provider baru dibuat, dan event broadcast yang datang saat dijeda hilang,
    // sehingga provider macet di loading. async* menahan nilai awalnya, sama
    // seperti implementasi produksi (RevenueCatSubscriptionStatus).
    _controller = StreamController<bool>.broadcast();
    _ultimateController = StreamController<bool>.broadcast();
  }

  bool _premium;
  bool _ultimate;
  late final StreamController<bool> _controller;
  late final StreamController<bool> _ultimateController;
  final List<SubscriptionPackage> packages = const [
    SubscriptionPackage(
      id: 'premium_monthly',
      tier: SubscriptionTier.premium,
      period: SubscriptionPeriod.monthly,
      priceLabel: 'Rp 7.500',
      amount: 7500,
    ),
    SubscriptionPackage(
      id: 'premium_yearly',
      tier: SubscriptionTier.premium,
      period: SubscriptionPeriod.yearly,
      priceLabel: 'Rp 75.000',
      amount: 75000,
    ),
    SubscriptionPackage(
      id: 'ultimate_monthly',
      tier: SubscriptionTier.ultimate,
      period: SubscriptionPeriod.monthly,
      priceLabel: 'Rp 12.500',
      amount: 12500,
    ),
    SubscriptionPackage(
      id: 'ultimate_yearly',
      tier: SubscriptionTier.ultimate,
      period: SubscriptionPeriod.yearly,
      priceLabel: 'Rp 125.000',
      amount: 125000,
    ),
  ];
  final purchased = <String>[];
  var restoreCalled = false;

  @override
  Stream<bool> watchIsPremium() async* {
    yield _premium;
    yield* _controller.stream;
  }

  @override
  Stream<bool> watchIsUltimate() async* {
    yield _ultimate;
    yield* _ultimateController.stream;
  }

  @override
  Future<String?> appUserId() async => 'test-user';

  @override
  Future<String?> activeSubscriptionProductId() async => _ultimate
      ? 'ultimate_monthly'
      : _premium
      ? 'premium_monthly'
      : null;

  @override
  Future<List<SubscriptionPackage>> fetchPackages() async => packages;

  @override
  Future<void> purchase(SubscriptionPackage package) async {
    purchased.add(package.id);
    _premium = true;
    _controller.add(true);
    if (package.tier == SubscriptionTier.ultimate) {
      _ultimate = true;
      _ultimateController.add(true);
    }
  }

  @override
  Future<void> restorePurchases() async => restoreCalled = true;
}

/// Backup cloud palsu — map di memori mensimulasikan penyimpanan, tanpa
/// menyentuh plugin `google_sign_in`/`googleapis` sungguhan sama sekali.
class FakeCloudBackupService implements CloudBackupService {
  FakeCloudBackupService({bool signedIn = false, DateTime? backupAt})
    : _signedIn = signedIn,
      _email = signedIn ? 'test@example.com' : null,
      _lastBackupAt = backupAt;

  bool _signedIn;
  String? _email;
  String? _storedJson;
  DateTime? _lastBackupAt;
  final Map<String, List<int>> _files = {};

  String? get storedJson => _storedJson;
  Map<String, List<int>> get storedFiles => _files;

  late final StreamController<bool> _controller =
      StreamController<bool>.broadcast(
        onListen: () => _controller.add(_signedIn),
      );

  @override
  Stream<bool> watchSignedIn() => _controller.stream;

  @override
  String? get currentEmail => _email;

  @override
  Future<bool> cachedSignedIn() async => _signedIn;

  @override
  Future<void> signIn() async {
    _email = 'test@example.com';
    _signedIn = true;
    _controller.add(true);
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _email = null;
    _controller.add(false);
  }

  @override
  Future<DateTime?> lastBackupAt() async => _lastBackupAt;

  @override
  Future<void> uploadBackup(String plainJson) async {
    _storedJson = plainJson;
    _lastBackupAt = DateTime.now();
  }

  @override
  Future<String> downloadBackup() async {
    final json = _storedJson;
    if (json == null) {
      throw const CloudBackupException('Belum ada backup cloud tersimpan.');
    }
    return json;
  }

  @override
  Future<void> uploadFile(String fileName, List<int> bytes) async {
    _files[fileName] = bytes;
  }

  @override
  Future<List<int>?> downloadFile(String fileName) async => _files[fileName];
}

/// Scanner struk palsu — mengembalikan [result] yang sudah ditentukan tes
/// tanpa menyentuh `image_picker`/ML Kit sungguhan sama sekali. Null (default)
/// mensimulasikan pengguna membatalkan pemilihan foto.
class FakeReceiptScanner implements ReceiptScanner {
  FakeReceiptScanner({this.result});

  ScannedReceipt? result;
  final List<ImageSource> requestedSources = [];

  @override
  Future<ScannedReceipt?> scan(ImageSource source) async {
    requestedSources.add(source);
    return result;
  }
}

/// Ekstraksi AI palsu — mengembalikan [result] tanpa jaringan. [quotaExceeded]
/// mensimulasikan server membalas 429.
class FakeAiExtractionService implements AiExtractionService {
  FakeAiExtractionService({this.result, this.quotaExceeded = false});

  AiReceiptExtraction? result;
  bool quotaExceeded;
  final List<({String rawText, List<AiCategoryOption> categories})> calls = [];

  @override
  Future<AiReceiptExtraction?> extract({
    required String rawText,
    required List<AiCategoryOption> categories,
  }) async {
    calls.add((rawText: rawText, categories: categories));
    if (quotaExceeded) throw const AiQuotaExceeded();
    return result;
  }
}

class AppHarness {
  AppHarness({
    required this.db,
    required this.store,
    required this.biometric,
    required this.notifications,
    required this.subscription,
    required this.cloudBackup,
    required this.receiptScanner,
    required this.aiExtraction,
  });
  final AppDatabase db;
  final MemoryKeyValueStore store;
  final FakeBiometric biometric;
  final FakeNotificationSender notifications;
  final FakeSubscriptionStatus subscription;
  final FakeCloudBackupService cloudBackup;
  final FakeReceiptScanner receiptScanner;
  final FakeAiExtractionService aiExtraction;
  AppLockService get lock => AppLockService(store);
}

/// Menjalankan aplikasi dengan database in-memory dan penyimpanan rahasia
/// palsu, lalu membersihkannya di dalam badan tes. Widget dilepas dulu agar
/// stream Drift berhenti dan timer penutupnya habis sebelum pemeriksaan
/// "pending timers" milik framework (addTearDown terlalu terlambat).
void appTest(
  String name,
  Future<void> Function(WidgetTester tester, AppHarness h) body, {
  Future<void> Function(AppLockService lock)? preset,
  Future<void> Function(AppDatabase db)? seed,
  FakeBiometric? biometric,
  FakeSubscriptionStatus? subscription,
  FakeCloudBackupService? cloudBackup,
  FakeReceiptScanner? receiptScanner,
  FakeAiExtractionService? aiExtraction,
  Duration grace = const Duration(seconds: 30),
  // Kebanyakan tes tidak menguji alur onboarding itu sendiri, jadi lewati
  // begitu saja (langsung ke HomeShell) kecuali diminta lain lewat `false`.
  bool seenOnboarding = true,
}) {
  testWidgets(name, (tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    // Layar tinggi agar seluruh form terbangun tanpa perlu scroll.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    final store = MemoryKeyValueStore();
    final bio = biometric ?? FakeBiometric();
    final notifications = FakeNotificationSender();
    final sub = subscription ?? FakeSubscriptionStatus();
    final cloud = cloudBackup ?? FakeCloudBackupService();
    final scanner = receiptScanner ?? FakeReceiptScanner();
    final ai = aiExtraction ?? FakeAiExtractionService();
    if (seenOnboarding) await store.write(onboardingSeenKey, '1');
    if (preset != null) await preset(AppLockService(store));
    // Drift butuh async sungguhan: jalankan di luar jam palsu.
    if (seed != null) await tester.runAsync(() => seed(db));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          keyValueStoreProvider.overrideWithValue(store),
          biometricProvider.overrideWithValue(bio),
          lockGraceProvider.overrideWithValue(grace),
          notificationSenderProvider.overrideWithValue(notifications),
          subscriptionStatusProvider.overrideWithValue(sub),
          cloudBackupServiceProvider.overrideWithValue(cloud),
          receiptScannerProvider.overrideWithValue(scanner),
          aiExtractionServiceProvider.overrideWithValue(ai),
        ],
        child: const DompetPintarApp(),
      ),
    );
    await settle(tester);
    try {
      await body(
        tester,
        AppHarness(
          db: db,
          store: store,
          biometric: bio,
          notifications: notifications,
          subscription: sub,
          cloudBackup: cloud,
          receiptScanner: scanner,
          aiExtraction: ai,
        ),
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(db.close);
    }
  });
}

/// Mengetik PIN lewat keypad di layar.
Future<void> typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
  await settle(tester);
}
