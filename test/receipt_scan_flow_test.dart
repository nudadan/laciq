import 'package:dompet_pintar/core/money.dart';
import 'package:dompet_pintar/features/transactions/receipt_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest(
    'belum premium: tile Scan Struk menawarkan upgrade, scanner tidak dipanggil',
    (tester, h) async {
      await tester.tap(find.byTooltip('Catat'));
      await settle(tester);

      expect(find.text('Scan Struk'), findsOneWidget);
      await tester.tap(find.text('Scan Struk'));
      await settle(tester);

      expect(find.text('LaciQ Premium'), findsOneWidget);
      expect(h.receiptScanner.requestedSources, isEmpty);
    },
    subscription: FakeSubscriptionStatus(),
  );

  appTest(
    'premium: scan berhasil mengisi nominal, tanggal, catatan, dan menandai foto tersimpan',
    (tester, h) async {
      await tester.tap(find.byTooltip('Catat'));
      await settle(tester);

      await tester.tap(find.text('Scan Struk'));
      await settle(tester);
      // Bottom sheet pilihan sumber foto.
      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Galeri'), findsOneWidget);
      await tester.tap(find.text('Kamera'));
      await settle(tester);

      expect(h.receiptScanner.requestedSources, [ImageSource.camera]);
      expect(
        find.widgetWithText(TextField, groupedNumber(23500)),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'INDOMARET'), findsOneWidget);
      expect(find.textContaining('Foto tersimpan'), findsOneWidget);

      await tester.tap(find.text('Makanan & Minuman'));
      await tester.pump();
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      final tx = (await h.db.getTransactions()).single.tx;
      expect(
        (tx.amount, tx.note, tx.receiptPath),
        (23500, 'INDOMARET', 'receipts/fake.jpg'),
      );
    },
    subscription: FakeSubscriptionStatus(premium: true),
    receiptScanner: FakeReceiptScanner(
      result: ScannedReceipt(
        amount: 23500,
        date: DateTime(2026, 9, 23),
        noteGuess: 'INDOMARET',
        photoPath: 'receipts/fake.jpg',
      ),
    ),
  );

  appTest(
    'premium: membatalkan pemilihan foto tidak mengubah apa pun',
    (tester, h) async {
      await tester.tap(find.byTooltip('Catat'));
      await settle(tester);

      await tester.tap(find.text('Scan Struk'));
      await settle(tester);
      await tester.tap(find.text('Galeri'));
      await settle(tester);

      expect(h.receiptScanner.requestedSources, [ImageSource.gallery]);
      expect(find.textContaining('Foto tersimpan'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
    },
    subscription: FakeSubscriptionStatus(premium: true),
    // FakeReceiptScanner default: result null (mensimulasikan batal).
  );
}
