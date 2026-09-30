import 'package:dompet_pintar/data/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Seed langsung ke tabel (bukan lewat `db.addAgenda`, yang memakai
/// `DateTime.now()` internal untuk `createdAt`) supaya `startDate` — dan
/// karenanya `nextDue` — bisa dikontrol presisi lewat hari relatif dari
/// sekarang. Pola sama `test/agenda_page_test.dart`.
Future<void> _seed(
  AppDatabase db, {
  required String id,
  required String title,
  required int daysFromNow,
  bool active = true,
}) {
  final due = DateTime.now().add(Duration(days: daysFromNow));
  return db
      .into(db.agendaReminders)
      .insert(
        AgendaRemindersCompanion.insert(
          id: id,
          title: title,
          frequency: Frequency.monthly,
          startDate: DateTime(due.year, due.month, due.day),
          active: Value(active),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('tanpa agenda: kartu menampilkan ajakan tambah', (tester, h) async {
    expect(
      find.textContaining('Belum ada agenda. Tambah pengingat'),
      findsOneWidget,
    );
  });

  appTest('satu agenda jatuh tempo besok: judul dan "Besok" tampil', (
    tester,
    h,
  ) async {
    expect(find.text('Servis AC'), findsOneWidget);
    expect(find.text('Besok'), findsOneWidget);
  }, seed: (db) => _seed(db, id: 'a', title: 'Servis AC', daysFromNow: 1));

  appTest(
    'lebih dari 2 agenda: kartu cuma tampilkan 2 yang paling dekat',
    (tester, h) async {
      expect(find.text('Terdekat'), findsOneWidget);
      expect(find.text('Kedua'), findsOneWidget);
      expect(find.text('Terjauh'), findsNothing);
    },
    seed: (db) async {
      await _seed(db, id: 'a', title: 'Terjauh', daysFromNow: 20);
      await _seed(db, id: 'b', title: 'Terdekat', daysFromNow: 1);
      await _seed(db, id: 'c', title: 'Kedua', daysFromNow: 5);
    },
  );

  appTest(
    'item yang dijeda tidak pernah muncul di kartu meski paling dekat',
    (tester, h) async {
      expect(find.text('Dijeda'), findsNothing);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('2 hari lagi'), findsOneWidget);
    },
    seed: (db) async {
      await _seed(db, id: 'a', title: 'Dijeda', daysFromNow: 1, active: false);
      await _seed(db, id: 'b', title: 'Aktif', daysFromNow: 2);
    },
  );

  appTest('tap kartu membuka AgendaPage', (tester, h) async {
    await tester.tap(find.text('Servis AC'));
    await settle(tester);

    expect(find.text('Agenda'), findsWidgets); // AppBar halaman Agenda
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  }, seed: (db) => _seed(db, id: 'a', title: 'Servis AC', daysFromNow: 1));
}
