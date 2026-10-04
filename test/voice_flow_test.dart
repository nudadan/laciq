import 'package:dompet_pintar/features/voice/voice_entry_sheet.dart';
import 'package:dompet_pintar/features/voice/voice_recognizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

const _tile = 'Catat dengan Suara';

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Catat'));
  await settle(tester);
}

Future<void> _openVoice(WidgetTester tester, {bool consent = true}) async {
  await tester.tap(find.text(_tile));
  await settle(tester);
  if (consent && find.text('Lanjut').evaluate().isNotEmpty) {
    await tester.tap(find.text('Lanjut'));
    await settle(tester);
  }
}

bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

FakeVoiceRecognizer _says(String text) => FakeVoiceRecognizer(
  updates: [
    VoiceUpdate(text.split(' ').first, isFinal: false),
    VoiceUpdate(text, isFinal: true),
  ],
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('belum Premium: tile menawarkan upgrade, mikrofon tidak disentuh', (
    tester,
    h,
  ) async {
    await _openForm(tester);
    await tester.tap(find.text(_tile));
    await settle(tester);
    expect(find.text('LaciQ Premium'), findsOneWidget);
    expect(find.text('Lanjut'), findsNothing);
    expect(h.voice.listens, 0);
  }, subscription: FakeSubscriptionStatus());

  appTest('Premium: dialog penjelasan dulu; menolak = tidak mendengarkan', (
    tester,
    h,
  ) async {
    await _openForm(tester);
    await tester.tap(find.text(_tile));
    await settle(tester);

    expect(find.text('Catat dengan suara'), findsOneWidget);
    expect(
      find.textContaining('tidak merekam, menyimpan, atau mengirim suara'),
      findsOneWidget,
    );
    await tester.tap(find.text('Batal'));
    await settle(tester);

    expect(h.voice.listens, 0);
    expect(await h.store.read(voiceConsentKey), isNull);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest(
    'Premium: setuju sekali, ucapan mengisi nominal, catatan, dan kategori',
    (tester, h) async {
      await _openForm(tester);
      await _openVoice(tester);

      expect(h.voice.listens, 1);
      expect(await h.store.read(voiceConsentKey), 'granted');
      expect(find.byKey(const Key('voice-amount')), findsOneWidget);
      expect(find.text('Rp 25.000'), findsOneWidget);
      expect(find.text('Kategori: Makanan & Minuman'), findsOneWidget);

      await tester.tap(find.text('Pakai'));
      await settle(tester);

      expect(find.widgetWithText(TextField, '25.000'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Makan siang'), findsOneWidget);
      expect(_chipSelected(tester, 'Makanan & Minuman'), isTrue);

      await tester.tap(find.text('Simpan'));
      await settle(tester);
      final tx = (await h.db.getTransactions()).single.tx;
      expect((tx.amount, tx.note), (25000, 'Makan siang'));
    },
    subscription: FakeSubscriptionStatus(premium: true),
    voice: _says('makan siang dua puluh lima ribu'),
  );

  appTest(
    'Premium: dialog tidak muncul lagi setelah disetujui',
    (tester, h) async {
      await h.store.write(voiceConsentKey, 'granted');
      await _openForm(tester);
      await tester.tap(find.text(_tile));
      await settle(tester);
      expect(find.text('Lanjut'), findsNothing);
      expect(h.voice.listens, 1);
    },
    subscription: FakeSubscriptionStatus(premium: true),
    voice: _says('kopi dua puluh ribu'),
  );

  appTest(
    'ucapan pemasukan mengganti jenis dan memilih kategori pemasukan',
    (tester, h) async {
      await _openForm(tester);
      await _openVoice(tester);
      expect(find.text('Pemasukan'), findsWidgets);
      await tester.tap(find.text('Pakai'));
      await settle(tester);

      expect(find.widgetWithText(TextField, '5.000.000'), findsOneWidget);
      expect(_chipSelected(tester, 'Gaji'), isTrue);
    },
    subscription: FakeSubscriptionStatus(premium: true),
    voice: _says('gajian lima juta'),
  );

  appTest(
    'Ulangi mendengarkan lagi; Batal tidak mengubah formulir',
    (tester, h) async {
      await _openForm(tester);
      await _openVoice(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Ulangi'));
      await settle(tester);
      expect(h.voice.listens, 2);

      // Hasil muncul lagi; tutup lewat geser/tap di luar lembar.
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(find.widgetWithText(TextField, '25.000'), findsNothing);
      expect(h.voice.cancels, greaterThan(0));
    },
    subscription: FakeSubscriptionStatus(premium: true),
    voice: _says('kopi dua puluh lima ribu'),
  );

  appTest(
    'tanpa nominal terdengar: tetap boleh dipakai, formulir tidak diisi nominal',
    (tester, h) async {
      await _openForm(tester);
      await _openVoice(tester);
      expect(find.text('Nominal belum terdengar'), findsOneWidget);
      await tester.tap(find.text('Pakai'));
      await settle(tester);
      expect(find.widgetWithText(TextField, 'Makan di warteg'), findsOneWidget);
    },
    subscription: FakeSubscriptionStatus(premium: true),
    voice: _says('makan di warteg'),
  );

  appTest(
    'nominal tanpa satuan dianggap ribuan dan diberi tahu',
    (tester, h) async {
      await _openForm(tester);
      await _openVoice(tester);
      expect(find.text('Rp 25.000'), findsOneWidget);
      expect(find.textContaining('dianggap ribuan'), findsOneWidget);
    },
    subscription: FakeSubscriptionStatus(premium: true),
    voice: _says('makan siang dua puluh lima'),
  );

  appTest(
    'izin mikrofon ditolak: petunjuk, tanpa tombol coba lagi',
    (tester, h) async {
      await _openForm(tester);
      await _openVoice(tester);
      expect(find.byKey(const Key('voice-error')), findsOneWidget);
      expect(find.textContaining('Izin mikrofon ditolak'), findsOneWidget);
      expect(find.text('Coba lagi'), findsNothing);
    },
    subscription: FakeSubscriptionStatus(premium: true),
    voice: FakeVoiceRecognizer(failure: VoiceFailure.permissionDenied),
  );

  appTest(
    'tidak ada suara: bisa coba lagi',
    (tester, h) async {
      await _openForm(tester);
      await _openVoice(tester);
      expect(find.textContaining('Tidak ada suara'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      await settle(tester);
      expect(h.voice.listens, 2);
    },
    subscription: FakeSubscriptionStatus(premium: true),
    voice: FakeVoiceRecognizer(failure: VoiceFailure.noSpeech),
  );
}
