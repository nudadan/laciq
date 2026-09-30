import 'package:dompet_pintar/features/subscription/subscription_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldConfigureRevenueCat', () {
    test('kunci Test Store dilewati di build rilis (SDK akan menutup app)', () {
      expect(shouldConfigureRevenueCat('test_abc', isRelease: true), isFalse);
    });

    test('kunci Test Store tetap dipakai di debug/profile untuk uji SDK', () {
      expect(shouldConfigureRevenueCat('test_abc', isRelease: false), isTrue);
    });

    test('kunci produksi goog_ dipakai di rilis maupun debug', () {
      expect(shouldConfigureRevenueCat('goog_abc', isRelease: true), isTrue);
      expect(shouldConfigureRevenueCat('goog_abc', isRelease: false), isTrue);
    });
  });
}
