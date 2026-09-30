import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('boot standar: belum layak iklan, widget iklan sungguhan '
      'tidak pernah dibangun', (tester, h) async {
    // Store segar (appTest selalu mulai kosong) -> first-use tercatat
    // "sekarang" -> 0 hari berlalu -> selalu dalam masa tenggang di tes.
    expect(find.byType(AdWidget), findsNothing);
    expect(await h.store.read('first_use_at'), isNotNull);
  });
}
