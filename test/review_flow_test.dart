import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('mencatat transaksi baru dihitung untuk permintaan ulasan, tanpa '
      'memunculkan dialog sebelum waktunya', (tester, h) async {
    await tester.tap(find.byTooltip('Catat'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '25000');
    await tester.tap(find.text('Makanan & Minuman'));
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await settle(tester);

    expect(await h.store.read('review_tx_count'), '1');
    expect(h.review.requests, 0);
  });

  appTest('transaksi yang gagal divalidasi tidak dihitung', (tester, h) async {
    await tester.tap(find.byTooltip('Catat'));
    await settle(tester);
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(await h.store.read('review_tx_count'), isNull);
  });

  appTest('Pengaturan > Beri nilai LaciQ membuka halaman Play Store', (
    tester,
    h,
  ) async {
    await tester.tap(find.byTooltip('Pengaturan'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Beri nilai LaciQ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Beri nilai LaciQ'));
    await settle(tester);

    expect(h.review.listingOpens, 1);
  });
}
