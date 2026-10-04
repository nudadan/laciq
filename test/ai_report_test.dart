import 'dart:convert';

import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/insights.dart';
import 'package:dompet_pintar/data/providers.dart';
import 'package:dompet_pintar/features/ai/ai_config.dart';
import 'package:dompet_pintar/features/ai/ai_extraction_service.dart'
    show AiQuotaExceeded;
import 'package:dompet_pintar/features/ai/ai_report_service.dart';
import 'package:dompet_pintar/features/reports/monthly_report_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

MonthlyReport _report({int daysElapsed = 10}) => MonthlyReport(
  month: DateTime(2026, 10),
  income: 5000000,
  expense: 1250000,
  previousExpense: 900000,
  transactionCount: 12,
  daysElapsed: daysElapsed,
  daysInMonth: 31,
  comparisonLabel: 'periode yang sama bulan lalu',
  categories: [
    for (var i = 0; i < 8; i++)
      CategoryLine(
        name: 'Kategori $i',
        icon: 'food',
        color: 0xFF112233,
        total: 100000 * (8 - i),
        share: 0.1,
        previousTotal: 50000,
      ),
  ],
  insights: const [Insight(InsightTone.info, 'Catatan rahasia: Dokter Budi')],
  budgets: const [
    BudgetUsage(name: 'Makan', spent: 540000, limit: 500000),
    BudgetUsage(name: 'Transport', spent: 100000, limit: 500000),
  ],
  projectedExpense: 3875000,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('alamat', () {
    test('alamat laporan diturunkan dari alamat ekstraksi', () {
      expect(
        aiReportUrlFrom('https://dompetku-api.hardan-ti.com/extract'),
        'https://dompetku-api.hardan-ti.com/report-insight',
      );
      expect(kAiReportUrl, 'https://dompetku-api.hardan-ti.com/report-insight');
    });

    test('alamat kosong atau aneh mematikan fitur', () {
      expect(aiReportUrlFrom(''), '');
      expect(aiReportUrlFrom('https://x.id/lain'), '');
    });
  });

  group('payload', () {
    test('hanya angka agregat: tanpa catatan, tanggal, atau ID', () {
      final payload = aiReportPayload(_report());
      final encoded = jsonEncode(payload);
      expect(encoded, isNot(contains('rahasia')));
      expect(encoded, isNot(contains('Dokter')));
      expect(payload['month'], '2026-10');
      expect(payload['income'], 5000000);
      expect(payload['expense'], 1250000);
      expect(payload['previousExpense'], 900000);
      expect(payload['projectedExpense'], 3875000);
      expect((payload['categories'] as List).length, 6);
      expect((payload['categories'] as List).first, {
        'name': 'Kategori 0',
        'total': 800000,
        'previousTotal': 50000,
      });
      expect(payload['budgets'], [
        {'name': 'Makan', 'percent': 108},
        {'name': 'Transport', 'percent': 20},
      ]);
      // Kunci yang boleh ada, tidak lebih.
      expect(payload.keys.toSet(), {
        'month',
        'daysElapsed',
        'daysInMonth',
        'income',
        'expense',
        'previousExpense',
        'projectedExpense',
        'categories',
        'budgets',
      });
    });
  });

  group('HttpAiReportService', () {
    HttpAiReportService service(
      http.Client client, {
      String url = 'https://w.example/report-insight',
    }) => HttpAiReportService(
      FakeSubscriptionStatus(ultimate: true),
      client: client,
      url: url,
    );

    test(
      'sukses: kirim appUserId + laporan, baca ringkasan dan sisa',
      () async {
        late http.Request seen;
        final s = service(
          MockClient((req) async {
            seen = req;
            return http.Response(
              jsonEncode({'summary': ' Ringkasan bulan ini. ', 'remaining': 7}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        final r = await s.narrate(_report());
        expect(r!.summary, 'Ringkasan bulan ini.');
        expect(r.remaining, 7);
        final body = jsonDecode(seen.body) as Map<String, dynamic>;
        expect(body['appUserId'], 'test-user');
        expect((body['report'] as Map)['expense'], 1250000);
        expect(seen.url.toString(), 'https://w.example/report-insight');
      },
    );

    test('429 kuota bulanan dan harian dilempar; rate_limited diam', () async {
      Future<Object?> run(String code) async {
        final s = service(
          MockClient(
            (_) async => http.Response(jsonEncode({'error': code}), 429),
          ),
        );
        try {
          return await s.narrate(_report());
        } on AiQuotaExceeded catch (e) {
          return e;
        }
      }

      expect(((await run('quota_exceeded')) as AiQuotaExceeded).daily, isFalse);
      expect(
        ((await run('daily_limit_exceeded')) as AiQuotaExceeded).daily,
        isTrue,
      );
      expect(await run('rate_limited'), isNull);
    });

    test('kegagalan lain menghasilkan null, bukan galat', () async {
      for (final status in [403, 500, 502]) {
        final s = service(MockClient((_) async => http.Response('{}', status)));
        expect(await s.narrate(_report()), isNull);
      }
      expect(
        await service(MockClient((_) async => http.Response('bukan json', 200)))
            .narrate(_report()),
        isNull,
      );
      expect(
        await service(
          MockClient(
            (_) async => http.Response(jsonEncode({'summary': 5}), 200),
          ),
        ).narrate(_report()),
        isNull,
      );
      expect(
        await service(
          MockClient((_) async => throw http.ClientException('offline')),
        ).narrate(_report()),
        isNull,
      );
    });

    test(
      'alamat kosong atau belum ada hari berjalan: tidak memanggil jaringan',
      () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        });
        expect(await service(client, url: '').narrate(_report()), isNull);
        expect(await service(client).narrate(_report(daysElapsed: 0)), isNull);
        expect(calls, 0);
      },
    );
  });

  group('kartu Ringkasan AI di Laporan Bulanan', () {
    final launched = <Uri>[];
    setUp(launched.clear);

    Override launcher({bool opens = true}) =>
        externalLinkLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return opens;
        });

    Future<void> seed(AppDatabase db) async {
      final now = DateTime.now();
      await db.addTransaction(
        type: TxType.income,
        amount: 5000000,
        accountId: 'acc-tunai',
        categoryId: 'cat-inc-gaji',
        date: DateTime(now.year, now.month, 1),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: 120000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime(now.year, now.month, 1),
        note: 'Makan siang',
      );
    }

    Future<void> openReport(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Lainnya'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Laporan Bulanan'));
      await settle(tester);
    }

    appTest(
      'Premium (bukan Ultimate), Ultimate dijual: ajakan upgrade, tanpa tombol AI',
      (tester, h) async {
        await openReport(tester);
        expect(find.text('Ringkasan AI'), findsOneWidget);
        expect(find.textContaining('Fitur Ultimate'), findsOneWidget);
        expect(find.text('Buat ringkasan AI'), findsNothing);
        expect(h.aiReport.calls, 0);
      },
      subscription: FakeSubscriptionStatus(premium: true),
      seed: seed,
    );

    appTest(
      'Ultimate: persetujuan dulu; menolak = tidak ada panggilan ke server',
      (tester, h) async {
        await openReport(tester);
        await tester.tap(find.text('Buat ringkasan AI'));
        await settle(tester);

        expect(find.text('Buat ringkasan dengan AI?'), findsOneWidget);
        expect(
          find.textContaining('Tidak dikirim: catatan transaksi'),
          findsOneWidget,
        );
        await tester.tap(find.text('Batal'));
        await settle(tester);

        expect(h.aiReport.calls, 0);
        expect(await h.store.read(aiReportConsentKey), isNull);
        expect(find.byKey(const Key('ai-summary')), findsNothing);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      seed: seed,
    );

    appTest(
      'Ultimate: izinkan -> ringkasan tampil dengan disclaimer; tidak dipanggil ulang saat dibuka lagi',
      (tester, h) async {
        await openReport(tester);
        await tester.tap(find.text('Buat ringkasan AI'));
        await settle(tester);
        await tester.tap(find.text('Izinkan'));
        await settle(tester);

        expect(h.aiReport.calls, 1);
        expect(await h.store.read(aiReportConsentKey), 'granted');
        expect(find.text('Ringkasan palsu bulan ini.'), findsOneWidget);
        expect(find.textContaining('bisa keliru'), findsOneWidget);
        expect(find.text('Laporkan'), findsOneWidget);

        // Keluar lalu masuk lagi: dari cache sesi, tanpa kuota baru.
        await tester.tap(find.byTooltip('Kembali'));
        await settle(tester);
        await tester.tap(find.text('Laporan Bulanan'));
        await settle(tester);
        expect(find.text('Ringkasan palsu bulan ini.'), findsOneWidget);
        expect(h.aiReport.calls, 1);

        // Payload yang dikirim hanya angka agregat.
        final sent = jsonEncode(aiReportPayload(h.aiReport.lastReport!));
        expect(sent, isNot(contains('Makan siang')));
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      seed: seed,
    );

    appTest(
      'Ultimate: "Buat ulang" memanggil lagi; "Laporkan" membuka draf email berisi ringkasan',
      (tester, h) async {
        await h.store.write(aiReportConsentKey, 'granted');
        await openReport(tester);
        await tester.tap(find.text('Buat ringkasan AI'));
        await settle(tester);
        await tester.tap(find.text('Buat ulang'));
        await settle(tester);
        expect(h.aiReport.calls, 2);

        await tester.tap(find.text('Laporkan'));
        await settle(tester);
        expect(launched, hasLength(1));
        expect(launched.single.scheme, 'mailto');
        expect(launched.single.path, 'support@hardan-ti.com');
        expect(
          Uri.decodeComponent(launched.single.toString()),
          contains('Ringkasan palsu bulan ini.'),
        );
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      seed: seed,
      extraOverrides: [launcher()],
    );

    appTest(
      'Laporkan tanpa aplikasi email: petunjuk alamat',
      (tester, h) async {
        await h.store.write(aiReportConsentKey, 'granted');
        await openReport(tester);
        await tester.tap(find.text('Buat ringkasan AI'));
        await settle(tester);
        await tester.tap(find.text('Laporkan'));
        await settle(tester);
        expect(
          find.textContaining('Kirim laporan ke support@hardan-ti.com'),
          findsOneWidget,
        );
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      seed: seed,
      extraOverrides: [launcher(opens: false)],
    );

    appTest(
      'kuota habis dan layanan tidak tersedia: pesan jujur, tanpa ringkasan',
      (tester, h) async {
        await h.store.write(aiReportConsentKey, 'granted');
        h.aiReport.quotaExceeded = true;
        await openReport(tester);
        await tester.tap(find.text('Buat ringkasan AI'));
        await settle(tester);
        expect(
          find.textContaining('Kuota ringkasan AI bulan ini habis'),
          findsOneWidget,
        );

        h.aiReport.quotaExceeded = false;
        h.aiReport.result = null;
        await tester.tap(find.text('Buat ringkasan AI'));
        await settle(tester);
        expect(find.textContaining('sedang tidak tersedia'), findsOneWidget);
        expect(find.byKey(const Key('ai-summary')), findsNothing);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
      seed: seed,
    );
  });
}
