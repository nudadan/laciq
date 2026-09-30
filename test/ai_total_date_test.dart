import 'dart:async';
import 'dart:convert';

import 'package:dompet_pintar/features/ai/ai_extraction_service.dart';
import 'package:dompet_pintar/features/transactions/receipt_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

const _rawText = 'PERTAMINA\nDibayar Konsumen : 244.850\nCASH : 250.000';

// Heuristik on-device SALAH (kasus SPBU): nominal 250.000 dan tanggal 23 Sep.
FakeReceiptScanner _scanner() => FakeReceiptScanner(
  result: ScannedReceipt(
    amount: 250000,
    date: DateTime(2026, 9, 23),
    noteGuess: 'Shift',
    photoPath: 'receipts/fake.jpg',
    rawText: _rawText,
  ),
);

Future<void> _scan(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Catat'));
  await settle(tester);
  await tester.tap(find.text('Scan Struk'));
  await settle(tester);
  await tester.tap(find.text('Kamera'));
  await settle(tester);
  await tester.tap(find.text('Izinkan'));
  await settle(tester);
}

/// Menahan jawaban AI sampai tes memintanya, untuk mensimulasikan pengguna
/// yang mengetik saat menunggu.
class _HoldingAi extends FakeAiExtractionService {
  _HoldingAi(AiReceiptExtraction result) : super(result: result);
  final release = Completer<void>();

  @override
  Future<AiReceiptExtraction?> extract({
    required String rawText,
    required List<AiCategoryOption> categories,
  }) async {
    await release.future;
    return result;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('form Catat — total dan tanggal dari AI', () {
    appTest(
      'menimpa nominal dan tanggal heuristik yang salah',
      (tester, h) async {
        await _scan(tester);
        expect(find.text('244.850'), findsOneWidget);
        expect(find.text('250.000'), findsNothing);
        expect(find.text('Senin, 28 September 2026'), findsOneWidget);
        expect(find.text('Rabu, 23 September 2026'), findsNothing);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
      aiExtraction: FakeAiExtractionService(
        result: AiReceiptExtraction(
          merchant: 'Pertamina',
          categoryId: 'cat-exp-transport',
          total: 244850,
          date: DateTime(2026, 9, 28),
        ),
      ),
    );

    appTest(
      'total/tanggal null dari AI: hasil heuristik tetap',
      (tester, h) async {
        await _scan(tester);
        expect(find.text('250.000'), findsOneWidget);
        expect(find.text('Rabu, 23 September 2026'), findsOneWidget);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
      aiExtraction: FakeAiExtractionService(
        result: const AiReceiptExtraction(merchant: 'Pertamina'),
      ),
    );

    final holding = _HoldingAi(
      AiReceiptExtraction(total: 244850, date: DateTime(2026, 9, 28)),
    );
    appTest(
      'pengguna mengetik nominal sendiri saat menunggu: tidak ditimpa',
      (tester, h) async {
        await tester.tap(find.byTooltip('Catat'));
        await settle(tester);
        await tester.tap(find.text('Scan Struk'));
        await settle(tester);
        await tester.tap(find.text('Kamera'));
        await settle(tester);
        await tester.tap(find.text('Izinkan'));
        await settle(tester);
        expect(find.text('Mengisi otomatis dengan AI…'), findsOneWidget);

        // Nominal diubah pengguna sendiri selagi AI belum menjawab.
        final amountField = find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == '250.000',
        );
        await tester.enterText(amountField, '199.000');
        await settle(tester);

        holding.release.complete();
        await settle(tester);
        // Nominal buatan pengguna dipertahankan; tanggal (tak disentuh) diperbarui.
        expect(find.text('199.000'), findsOneWidget);
        expect(find.text('244.850'), findsNothing);
        expect(find.text('Senin, 28 September 2026'), findsOneWidget);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
      aiExtraction: holding,
    );
  });

  group('HttpAiExtractionService — total, tanggal, dan batas', () {
    final categories = [
      const AiCategoryOption(id: 'cat-exp-makan', label: 'Makanan'),
    ];

    HttpAiExtractionService service(http.Client client) =>
        HttpAiExtractionService(
          FakeSubscriptionStatus(ultimate: true),
          client: client,
          url: 'https://ai.example/extract',
          timeout: const Duration(seconds: 5),
        );

    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    Future<AiReceiptExtraction?> ask(Object body) =>
        service(MockClient((_) async => json(body)))
            .extract(rawText: 'x', categories: categories);

    test('total bulat positif dan tanggal valid dipetakan', () async {
      final r = await ask({'total': 244850, 'date': '2026-09-28'});
      expect(r?.total, 244850);
      expect(r?.date, DateTime(2026, 9, 28));
    });

    test('total dan tanggal tidak valid menjadi null', () async {
      for (final bad in [
        {'total': '244850'},
        {'total': 0},
        {'total': -5},
        {'total': 12.5},
        {'total': null},
        {'date': '28/09/2026'},
        {'date': '2026-02-31'},
        {'date': '2026-9-8'},
        {'date': 20260928},
      ]) {
        final r = await ask(bad);
        expect(r?.total, isNull, reason: '$bad');
        expect(r?.date, isNull, reason: '$bad');
      }
    });

    Future<Object?> quotaError(String? code) async {
      final s = service(
        MockClient(
          (_) async => code == null
              ? http.Response('', 429)
              : json({'error': code}, 429),
        ),
      );
      try {
        return await s.extract(rawText: 'x', categories: categories);
      } on AiQuotaExceeded catch (e) {
        return e;
      }
    }

    test(
      '429 quota_exceeded/tanpa kode = bulanan; daily_limit_exceeded = harian; '
      'rate_limited = diam',
      () async {
        expect(
          ((await quotaError('quota_exceeded')) as AiQuotaExceeded).daily,
          isFalse,
        );
        expect(((await quotaError(null)) as AiQuotaExceeded).daily, isFalse);
        expect(
          ((await quotaError('daily_limit_exceeded')) as AiQuotaExceeded).daily,
          isTrue,
        );
        expect(await quotaError('rate_limited'), isNull);
      },
    );
  });
}
