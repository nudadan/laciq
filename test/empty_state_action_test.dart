import 'package:dompet_pintar/core/theme.dart';
import 'package:dompet_pintar/core/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildTheme(Brightness.light),
  home: Scaffold(body: child),
);

Future<void> _openFromMore(WidgetTester tester, String tile) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text(tile));
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('EmptyState', () {
    testWidgets('tanpa aksi: tidak ada tombol', (tester) async {
      await tester.pumpWidget(
        _host(const EmptyState(icon: Icons.flag_outlined, message: 'Kosong')),
      );
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('hanya label tanpa callback: tidak ada tombol', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.flag_outlined,
            message: 'Kosong',
            actionLabel: 'Mulai',
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('dengan aksi: tombol tampil dan memanggil callback', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          EmptyState(
            icon: Icons.flag_outlined,
            message: 'Kosong',
            actionLabel: 'Mulai',
            onAction: () => taps++,
          ),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Mulai'));
      expect(taps, 1);
    });
  });

  group('tombol di halaman kosong', () {
    appTest('Transaksi: tombol Catat transaksi membuka formulir', (
      tester,
      h,
    ) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transaksi'),
        ),
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Catat transaksi'));
      await settle(tester);
      expect(find.text('Simpan'), findsWidgets);
    });

    appTest('Target: tombol Target baru membuka formulir target', (
      tester,
      h,
    ) async {
      await _openFromMore(tester, 'Target');
      await tester.tap(find.widgetWithText(FilledButton, 'Target baru'));
      await settle(tester);
      expect(find.widgetWithText(FilledButton, 'Target baru'), findsNothing);
      expect(find.byType(TextField), findsWidgets);
    });

    appTest('Utang & Piutang: tombol membuka formulir utang', (
      tester,
      h,
    ) async {
      await _openFromMore(tester, 'Utang & Piutang');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Catat utang atau piutang'),
      );
      await settle(tester);
      expect(find.byType(TextField), findsWidgets);
    }, subscription: FakeSubscriptionStatus(premium: true));

    appTest('Berulang: tombol membuka formulir transaksi berulang', (
      tester,
      h,
    ) async {
      await _openFromMore(tester, 'Transaksi berulang');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Tambah transaksi berulang'),
      );
      await settle(tester);
      expect(find.byType(TextField), findsWidgets);
    }, subscription: FakeSubscriptionStatus(premium: true));

    appTest('Agenda: tombol membuka formulir agenda', (tester, h) async {
      await _openFromMore(tester, 'Agenda');
      await tester.tap(find.widgetWithText(FilledButton, 'Tambah agenda'));
      await settle(tester);
      expect(find.byType(TextField), findsWidgets);
    }, subscription: FakeSubscriptionStatus(premium: true));
  });
}
