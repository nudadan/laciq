import 'dart:convert';

import 'package:dompet_pintar/features/ai/ai_extraction_service.dart';
import 'package:dompet_pintar/features/transactions/receipt_scanner.dart';
import 'package:dompet_pintar/features/transactions/transaction_form_page.dart'
    show resetUltimateUpsellSession;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

const _rawText = 'INDOMARET CIKINI\nSusu UHT 12.000\nTOTAL 23.500';

FakeReceiptScanner _scanner() => FakeReceiptScanner(
  result: ScannedReceipt(
    amount: 23500,
    date: DateTime(2026, 9, 23),
    noteGuess: 'INDOMARET CIKINI',
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
}

bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

String _note(WidgetTester tester) => tester
    .widget<TextField>(find.widgetWithText(TextField, 'Catatan (opsional)'))
    .controller!
    .text;

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(resetUltimateUpsellSession);

  group('form Catat — pengguna Ultimate', () {
    appTest(
      'minta izin sekali, lalu nama toko & kategori dari AI mengisi form',
      (tester, h) async {
        await _scan(tester);

        expect(find.text('Isi otomatis dengan AI?'), findsOneWidget);
        await tester.tap(find.text('Izinkan'));
        await settle(tester);

        expect(h.aiExtraction.calls, hasLength(1));
        expect(h.aiExtraction.calls.single.rawText, _rawText);
        final options = h.aiExtraction.calls.single.categories;
        expect(options.map((c) => c.id), contains('cat-exp-makan'));
        expect(
          options.firstWhere((c) => c.id == 'cat-exp-makan').label,
          'Makanan & Minuman',
        );
        expect(_note(tester), 'Indomaret');
        expect(_chipSelected(tester, 'Makanan & Minuman'), isTrue);
        expect(await h.store.read('ai_extraction_consent'), 'granted');

        // Pindai lagi: izin sudah ada, tidak bertanya ulang.
        await tester.tap(find.text('Scan Struk'));
        await settle(tester);
        await tester.tap(find.text('Kamera'));
        await settle(tester);
        expect(find.text('Isi otomatis dengan AI?'), findsNothing);
        expect(h.aiExtraction.calls, hasLength(2));
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
      aiExtraction: FakeAiExtractionService(
        result: const AiReceiptExtraction(
          merchant: 'Indomaret',
          categoryId: 'cat-exp-makan',
        ),
      ),
    );

    appTest(
      'menolak izin: AI tidak dipanggil, hasil heuristik tetap',
      (tester, h) async {
        await _scan(tester);
        await tester.tap(find.text('Lewati'));
        await settle(tester);

        expect(h.aiExtraction.calls, isEmpty);
        expect(_note(tester), 'INDOMARET CIKINI');
        expect(await h.store.read('ai_extraction_consent'), isNull);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
    );

    appTest(
      'AI gagal (null): hasil heuristik tetap utuh',
      (tester, h) async {
        await h.store.write('ai_extraction_consent', 'granted');
        await _scan(tester);

        expect(h.aiExtraction.calls, hasLength(1));
        expect(_note(tester), 'INDOMARET CIKINI');
        expect(_chipSelected(tester, 'Makanan & Minuman'), isFalse);
        expect(find.text('Foto tersimpan'), findsOneWidget);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
    );

    appTest(
      'kuota habis: pengguna diberi tahu, heuristik tetap dipakai',
      (tester, h) async {
        await h.store.write('ai_extraction_consent', 'granted');
        await _scan(tester);

        expect(
          find.textContaining('Kuota scan AI bulan ini habis'),
          findsOneWidget,
        );
        expect(_note(tester), 'INDOMARET CIKINI');
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
      aiExtraction: FakeAiExtractionService(quotaExceeded: true),
    );

    appTest(
      'kuota habis: pesan hanya sekali per sesi, scan berikutnya tetap '
      'jalan dengan hasil biasa',
      (tester, h) async {
        await h.store.write('ai_extraction_consent', 'granted');
        await _scan(tester);
        expect(
          find.textContaining('Kuota scan AI bulan ini habis'),
          findsOneWidget,
        );

        // Biarkan pesan pertama hilang, lalu scan lagi.
        await tester.pump(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.textContaining('Kuota scan AI bulan ini habis'),
          findsNothing,
        );

        await tester.tap(find.text('Scan Struk'));
        await settle(tester);
        await tester.tap(find.text('Kamera'));
        await settle(tester);

        expect(h.aiExtraction.calls, hasLength(2)); // AI tetap dicoba
        expect(
          find.textContaining('Kuota scan AI bulan ini habis'),
          findsNothing,
        );
        expect(_note(tester), 'INDOMARET CIKINI'); // hasil biasa dipakai
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      receiptScanner: _scanner(),
      aiExtraction: FakeAiExtractionService(quotaExceeded: true),
    );
  });

  appTest(
    'Premium biasa (bukan Ultimate): tidak ada dialog izin dan AI tidak dipanggil',
    (tester, h) async {
      await _scan(tester);

      expect(find.text('Isi otomatis dengan AI?'), findsNothing);
      expect(h.aiExtraction.calls, isEmpty);
      expect(_note(tester), 'INDOMARET CIKINI');
      expect(h.receiptScanner.requestedSources, [ImageSource.camera]);
    },
    subscription: FakeSubscriptionStatus(premium: true),
    receiptScanner: _scanner(),
  );

  appTest(
    'scan gagal (kamera/OCR melempar galat): pengguna diberi tahu, bukan diam',
    (tester, h) async {
      await _scan(tester);
      expect(
        find.textContaining('Scan struk gagal (camera_access_denied)'),
        findsOneWidget,
      );
      expect(h.aiExtraction.calls, isEmpty);
      expect(_note(tester), isEmpty); // form tidak berubah
    },
    subscription: FakeSubscriptionStatus(premium: true),
    receiptScanner: FakeReceiptScanner(
      error: PlatformException(code: 'camera_access_denied'),
    ),
  );

  group('HttpAiExtractionService', () {
    const categories = [
      AiCategoryOption(id: 'cat-exp-makan', label: 'Makanan & Minuman'),
      AiCategoryOption(id: 'cat-exp-transport', label: 'Transportasi'),
    ];

    HttpAiExtractionService service(
      http.Client client, {
      String url = 'https://ai.example/extract',
      Duration timeout = const Duration(seconds: 5),
    }) => HttpAiExtractionService(
      FakeSubscriptionStatus(ultimate: true),
      client: client,
      url: url,
      timeout: timeout,
    );

    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    test(
      'mengirim userId, teks, dan daftar kategori; memetakan balasan',
      () async {
        late http.Request sent;
        final s = service(
          MockClient((req) async {
            sent = req;
            return json({
              'merchant': ' Indomaret ',
              'categoryId': 'cat-exp-makan',
            });
          }),
        );
        final r = await s.extract(rawText: _rawText, categories: categories);

        expect(sent.url.toString(), 'https://ai.example/extract');
        final body = jsonDecode(sent.body) as Map<String, dynamic>;
        expect(body['appUserId'], 'test-user');
        expect(body['rawText'], _rawText);
        expect(body['categories'], [
          {'id': 'cat-exp-makan', 'name': 'Makanan & Minuman'},
          {'id': 'cat-exp-transport', 'name': 'Transportasi'},
        ]);
        expect(r?.merchant, 'Indomaret');
        expect(r?.categoryId, 'cat-exp-makan');
      },
    );

    test(
      'categoryId di luar daftar dibuang, merchant kosong jadi null',
      () async {
        final s = service(
          MockClient(
            (_) async =>
                json({'merchant': '  ', 'categoryId': 'cat-hasil-karangan'}),
          ),
        );
        final r = await s.extract(rawText: _rawText, categories: categories);
        expect(r?.merchant, isNull);
        expect(r?.categoryId, isNull);
      },
    );

    test('merchant kepanjangan dipotong 60 karakter', () async {
      final s = service(MockClient((_) async => json({'merchant': 'A' * 200})));
      final r = await s.extract(rawText: _rawText, categories: categories);
      expect(r?.merchant, hasLength(60));
    });

    test('429 -> AiQuotaExceeded', () async {
      final s = service(MockClient((_) async => json({'error': 'quota'}, 429)));
      expect(
        s.extract(rawText: _rawText, categories: categories),
        throwsA(isA<AiQuotaExceeded>()),
      );
    });

    test('status error, JSON rusak, dan exception jaringan -> null', () async {
      for (final client in [
        MockClient((_) async => json({'error': 'x'}, 500)),
        MockClient((_) async => json({'error': 'x'}, 403)),
        MockClient((_) async => http.Response('bukan json', 200)),
        MockClient((_) async => json([1, 2])),
        MockClient((_) async => throw http.ClientException('offline')),
      ]) {
        final r = await service(client)
            .extract(rawText: _rawText, categories: categories);
        expect(r, isNull);
      }
    });

    test('timeout -> null', () async {
      final s = service(
        MockClient(
          (_) => Future.delayed(
            const Duration(seconds: 2),
            () => json({'merchant': 'X'}),
          ),
        ),
        timeout: const Duration(milliseconds: 50),
      );
      expect(
        await s.extract(rawText: _rawText, categories: categories),
        isNull,
      );
    });

    test('URL belum dikonfigurasi -> null tanpa memanggil jaringan', () async {
      var called = false;
      final s = service(
        MockClient((_) async {
          called = true;
          return json({});
        }),
        url: '',
      );
      expect(
        await s.extract(rawText: _rawText, categories: categories),
        isNull,
      );
      expect(called, isFalse);
    });

    test('teks OCR dipotong 4000 karakter', () async {
      late Map<String, dynamic> body;
      final s = service(
        MockClient((req) async {
          body = jsonDecode(req.body) as Map<String, dynamic>;
          return json({});
        }),
      );
      await s.extract(rawText: 'x' * 9000, categories: categories);
      expect((body['rawText'] as String).length, 4000);
    });
  });
}
