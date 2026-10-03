import 'package:dompet_pintar/features/ai/ai_extraction_service.dart';
import 'package:dompet_pintar/features/subscription/subscription_plans.dart';
import 'package:dompet_pintar/features/subscription/subscription_status.dart';
import 'package:dompet_pintar/features/transactions/receipt_scanner.dart';
import 'package:dompet_pintar/features/transactions/transaction_form_page.dart'
    show resetUltimateUpsellSession;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Premium yang belum melihat paket Ultimate di toko (offering hanya Premium).
class _PremiumOnlyStatus extends FakeSubscriptionStatus {
  _PremiumOnlyStatus() : super(premium: true);

  @override
  Future<List<SubscriptionPackage>> fetchPackages() async => [
    for (final p in await super.fetchPackages())
      if (p.tier == SubscriptionTier.premium) p,
  ];
}

FakeReceiptScanner _scanner() => FakeReceiptScanner(
  result: ScannedReceipt(
    amount: 23500,
    date: DateTime(2026, 9, 23),
    noteGuess: 'INDOMARET',
    photoPath: 'receipts/fake.jpg',
    rawText: 'INDOMARET\nTOTAL 23.500',
  ),
);

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await settle(tester);
}

Future<void> _scan(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Catat'));
  await settle(tester);
  await tester.tap(find.text('Scan Struk'));
  await settle(tester);
  await tester.tap(find.text('Kamera'));
  await settle(tester);
}

const _upsellText = 'Isi toko & kategori otomatis dengan AI — Ultimate';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(resetUltimateUpsellSession);

  group('keputusan penggantian produk', () {
    test('hanya Premium -> Ultimate yang menggantikan langganan', () {
      bool replace(ActiveTier a, SubscriptionTier t) =>
          shouldReplaceProduct(active: a, target: t);
      expect(replace(ActiveTier.premium, SubscriptionTier.ultimate), isTrue);
      expect(replace(ActiveTier.free, SubscriptionTier.ultimate), isFalse);
      expect(replace(ActiveTier.free, SubscriptionTier.premium), isFalse);
      expect(replace(ActiveTier.premium, SubscriptionTier.premium), isFalse);
      expect(replace(ActiveTier.ultimate, SubscriptionTier.ultimate), isFalse);
      expect(replace(ActiveTier.ultimate, SubscriptionTier.premium), isFalse);
    });

    test(
      'ActiveTier.of memeriksa Ultimate lebih dulu (Ultimate juga premium)',
      () {
        expect(ActiveTier.of(premium: false, ultimate: false), ActiveTier.free);
        expect(
          ActiveTier.of(premium: true, ultimate: false),
          ActiveTier.premium,
        );
        expect(
          ActiveTier.of(premium: true, ultimate: true),
          ActiveTier.ultimate,
        );
      },
    );
  });

  group('tile langganan di Pengaturan', () {
    appTest('gratis: ajakan Premium', (tester, h) async {
      await _openSettings(tester);
      expect(find.text('Upgrade ke Premium'), findsOneWidget);
      expect(find.text('Upgrade'), findsNothing);
    }, subscription: FakeSubscriptionStatus());

    appTest(
      'Premium + Ultimate dijual: tombol Upgrade membuka halaman Ultimate '
      'saja',
      (tester, h) async {
        await _openSettings(tester);
        expect(find.text('LaciQ Premium aktif'), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
        expect(find.text('Kelola'), findsOneWidget);

        await tester.tap(find.text('Upgrade'));
        await settle(tester);
        expect(find.text('Upgrade ke Ultimate'), findsOneWidget);
        // Hanya kartu Ultimate; kartu Premium tidak ditawarkan lagi.
        expect(find.text('Ultimate'), findsOneWidget);
        expect(find.text('Premium'), findsNothing);
        expect(find.text('Rp 12.500'), findsOneWidget);
        expect(find.textContaining('Multi buku kas'), findsOneWidget);
      },
      subscription: FakeSubscriptionStatus(premium: true),
    );

    appTest('Premium tetapi Ultimate belum dijual: tanpa tombol Upgrade', (
      tester,
      h,
    ) async {
      await _openSettings(tester);
      expect(find.text('LaciQ Premium aktif'), findsOneWidget);
      expect(find.text('Upgrade'), findsNothing);
      expect(find.textContaining('Upgrade ke Ultimate'), findsNothing);
    }, subscription: _PremiumOnlyStatus());

    appTest('tombol kartu berada di bawah judul, bukan di sampingnya (judul '
        'tidak ikut menyempit di layar sempit)', (tester, h) async {
      await _openSettings(tester);

      final title = find.text('LaciQ Premium aktif');
      final subtitle = find.textContaining('Upgrade ke Ultimate untuk AI');
      expect(title, findsOneWidget);
      final textBottom = tester.getBottomLeft(subtitle).dy;
      expect(
        tester.getTopLeft(find.text('Upgrade')).dy,
        greaterThan(textBottom),
      );
      expect(
        tester.getTopLeft(find.text('Kelola')).dy,
        greaterThan(textBottom),
      );
      // Judul dan keterangan memakai lebar yang sama (kolom penuh).
      expect(tester.getTopLeft(title).dx, tester.getTopLeft(subtitle).dx);
    }, subscription: FakeSubscriptionStatus(premium: true));

    appTest('Ultimate: penanda Ultimate, tanpa tombol Upgrade', (
      tester,
      h,
    ) async {
      await _openSettings(tester);
      expect(find.text('LaciQ Ultimate aktif'), findsOneWidget);
      expect(find.text('LaciQ Premium aktif'), findsNothing);
      expect(find.text('Upgrade'), findsNothing);
      expect(find.text('Kelola'), findsOneWidget);
    }, subscription: FakeSubscriptionStatus(ultimate: true));
  });

  group('ajakan Ultimate di alur Scan struk', () {
    appTest(
      'Premium: tampil setelah scan; Lihat membuka halaman Ultimate',
      (tester, h) async {
        await _scan(tester);
        expect(find.text(_upsellText), findsOneWidget);
        await tester.tap(find.text('Lihat'));
        await settle(tester);
        expect(find.text('Upgrade ke Ultimate'), findsOneWidget);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      receiptScanner: _scanner(),
    );

    appTest(
      'ditutup dua kali lalu tidak muncul lagi (tersimpan)',
      (tester, h) async {
        await _scan(tester);
        expect(find.text(_upsellText), findsOneWidget);
        await tester.tap(find.byTooltip('Tutup'));
        await settle(tester);
        expect(find.text(_upsellText), findsNothing);
        expect(
          await tester.runAsync(
            () => h.store.read('ultimate_upsell_dismissals'),
          ),
          '1',
        );

        // Sesi berikutnya: masih muncul (baru ditutup 1x); ditutup lagi -> 2x.
        await tester.tap(find.byType(BackButton));
        await settle(tester);
        resetUltimateUpsellSession();
        await _scan(tester);
        expect(find.text(_upsellText), findsOneWidget);
        await tester.tap(find.byTooltip('Tutup'));
        await settle(tester);
        expect(
          await tester.runAsync(
            () => h.store.read('ultimate_upsell_dismissals'),
          ),
          '2',
        );

        // Sesi berikutnya lagi: sudah 2x, tidak tampil.
        await tester.tap(find.byType(BackButton));
        await settle(tester);
        resetUltimateUpsellSession();
        await _scan(tester);
        expect(find.text(_upsellText), findsNothing);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      receiptScanner: _scanner(),
    );

    appTest(
      'sudah ditutup 2x: tidak tampil',
      (tester, h) async {
        await tester.runAsync(
          () => h.store.write('ultimate_upsell_dismissals', '2'),
        );
        await _scan(tester);
        expect(find.text(_upsellText), findsNothing);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      receiptScanner: _scanner(),
    );

    appTest(
      'Ultimate dijual tetapi pengguna sudah Ultimate: tidak tampil',
      (tester, h) async {
        await _scan(tester);
        expect(find.text(_upsellText), findsNothing);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
    );

    appTest(
      'Ultimate belum dijual: tidak tampil',
      (tester, h) async {
        await _scan(tester);
        expect(find.text(_upsellText), findsNothing);
      },
      subscription: _PremiumOnlyStatus(),
      receiptScanner: _scanner(),
    );

    appTest(
      'paling banyak sekali per sesi',
      (tester, h) async {
        await _scan(tester);
        expect(find.text(_upsellText), findsOneWidget);
        // Buka form Catat kedua dalam sesi yang sama.
        await tester.tap(find.byType(BackButton));
        await settle(tester);
        await _scan(tester);
        expect(find.text(_upsellText), findsNothing);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      receiptScanner: _scanner(),
    );
  });

  group('sisa kuota scan AI', () {
    AiReceiptExtraction result(int? remaining) => AiReceiptExtraction(
      merchant: 'Indomaret',
      categoryId: 'cat-exp-makan',
      remaining: remaining,
    );

    Future<void> scanAndAllow(WidgetTester tester) async {
      await _scan(tester);
      await tester.tap(find.text('Izinkan'));
      await settle(tester);
    }

    appTest(
      'sisa tepat 10: pengguna diberi tahu sekali',
      (tester, h) async {
        await scanAndAllow(tester);
        expect(find.text('Sisa scan AI bulan ini: 10'), findsOneWidget);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
      aiExtraction: FakeAiExtractionService(
        result: AiReceiptExtraction(
          merchant: 'Indomaret',
          categoryId: 'cat-exp-makan',
          remaining: 10,
        ),
      ),
    );

    appTest(
      'sisa di bawah 10: tidak diulang tiap scan',
      (tester, h) async {
        await scanAndAllow(tester);
        expect(find.textContaining('Sisa scan AI'), findsNothing);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
      aiExtraction: FakeAiExtractionService(
        result: AiReceiptExtraction(
          merchant: 'Indomaret',
          categoryId: 'cat-exp-makan',
          remaining: 7,
        ),
      ),
    );

    appTest(
      'sisa masih banyak: tidak berisik',
      (tester, h) async {
        await scanAndAllow(tester);
        expect(find.textContaining('Sisa scan AI'), findsNothing);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
      aiExtraction: FakeAiExtractionService(
        result: AiReceiptExtraction(
          merchant: 'Indomaret',
          categoryId: 'cat-exp-makan',
          remaining: 40,
        ),
      ),
    );

    test('AiReceiptExtraction.remaining bisa null (server lama)', () {
      expect(result(null).remaining, isNull);
    });
  });
}
