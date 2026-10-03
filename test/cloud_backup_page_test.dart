import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/features/cloud_backup/cloud_backup_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await settle(tester);
  await tester.dragUntilVisible(
    find.text('Backup cloud terenkripsi'),
    find.byType(ListView),
    const Offset(0, -300),
  );
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('belum premium: tile Backup cloud menawarkan upgrade, halaman '
      'tidak terjangkau', (tester, h) async {
    await _openSettings(tester);
    // Tampil di lebih dari satu tile premium sekarang (Backup Cloud, Analisa
    // Tren, dst) — cukup pastikan setidaknya satu upsell muncul.
    expect(find.text('Fitur Premium'), findsWidgets);

    await tester.tap(find.text('Backup cloud terenkripsi'));
    await settle(tester);

    // Membuka SubscriptionPage, bukan CloudBackupPage.
    expect(find.text('LaciQ Premium'), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsNothing);
  }, subscription: FakeSubscriptionStatus());

  appTest('premium: masuk dengan Google, lalu backup dan pulihkan', (
    tester,
    h,
  ) async {
    await h.db.addAccount(name: 'BCA', kind: AccountKind.bank);
    await _openSettings(tester);
    await tester.tap(find.text('Backup cloud terenkripsi'));
    await settle(tester);

    expect(find.text('Backup Cloud'), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsOneWidget);

    await tester.tap(find.text('Masuk dengan Google'));
    await settle(tester);

    expect(find.textContaining('test@example.com'), findsOneWidget);
    expect(find.textContaining('belum pernah'), findsOneWidget);
    expect(find.text('Ingatkan saya backup berkala'), findsOneWidget);
    expect(find.text('Mingguan'), findsOneWidget);

    await tester.tap(find.text('Backup sekarang'));
    await settle(tester);
    expect(h.cloudBackup.storedJson, isNotNull);

    await tester.tap(find.text('Pulihkan dari cloud'));
    await settle(tester);
    expect(find.text('Pulihkan backup?'), findsOneWidget);
    await tester.tap(find.text('Ganti data'));
    await settle(tester);

    final accounts = await tester.runAsync(
      () => h.db.watchAccountBalances().first,
    );
    expect(accounts!.map((a) => a.name), contains('BCA'));

    await tester.tap(find.text('Keluar'));
    await settle(tester);
    expect(find.text('Masuk dengan Google'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest('premium: matikan pengingat backup, dropdown interval hilang dan '
      'tersimpan', (tester, h) async {
    await _openSettings(tester);
    await tester.tap(find.text('Backup cloud terenkripsi'));
    await settle(tester);
    await tester.tap(find.text('Masuk dengan Google'));
    await settle(tester);

    expect(find.text('Mingguan'), findsOneWidget);
    await tester.tap(find.text('Ingatkan saya backup berkala'));
    await settle(tester);
    expect(find.text('Mingguan'), findsNothing);

    final enabled = await tester.runAsync(
      () => CloudBackupReminderService(h.store, h.cloudBackup).enabled(),
    );
    expect(enabled, isFalse);
  }, subscription: FakeSubscriptionStatus(premium: true));
}
