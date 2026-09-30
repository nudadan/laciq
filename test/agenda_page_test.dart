import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _openAgenda(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Agenda'));
  await settle(tester);
}

Future<void> _addAgenda(WidgetTester tester, String title) async {
  await tester.tap(find.byIcon(Icons.add_rounded));
  await settle(tester);
  await tester.enterText(find.byType(TextField).first, title);
  await tester.tap(find.text('Simpan'));
  await settle(tester);
}

/// Seed langsung ke tabel (bukan lewat `db.addAgenda`, yang memakai
/// `DateTime.now()` internal) supaya `createdAt` antar-item bisa dikontrol
/// presisi — perbandingan kuota gratis bergantung urutan `createdAt`.
Future<void> _seedAt(AppDatabase db, String id, DateTime createdAt) => db
    .into(db.agendaReminders)
    .insert(
      AgendaRemindersCompanion.insert(
        id: id,
        title: 'Agenda $id',
        frequency: Frequency.monthly,
        startDate: DateTime(2030, 1, 15),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest(
    'belum premium: tile Agenda langsung buka AgendaPage, bukan diarahkan '
    'ke upgrade',
    (tester, h) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Lainnya'),
        ),
      );
      await settle(tester);
      expect(find.textContaining('gratis 3 item'), findsOneWidget);

      await tester.tap(find.text('Agenda'));
      await settle(tester);

      expect(find.text('Agenda'), findsWidgets);
      expect(find.text('DompetKu Premium'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    },
    subscription: FakeSubscriptionStatus(),
  );

  appTest('belum premium: bisa tambah sampai 3 item, item ke-4 diarahkan ke '
      'upgrade', (tester, h) async {
    await _openAgenda(tester);

    await _addAgenda(tester, 'Servis AC');
    expect(find.text('Agenda ditambahkan'), findsOneWidget);
    await _addAgenda(tester, 'Servis Mobil');
    await _addAgenda(tester, 'Perpanjang STNK');

    final items = await tester.runAsync(
      () => h.db.watchAgendaReminders().first,
    );
    expect(items, hasLength(3));

    // Percobaan ke-4: dialihkan ke SubscriptionPage, form TIDAK terbuka.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    expect(find.text('DompetKu Premium'), findsOneWidget);
    expect(find.text('Agenda Baru'), findsNothing);
  }, subscription: FakeSubscriptionStatus());

  appTest(
    'belum premium dengan 4 item (turun dari premium): tepat 1 item '
    'menampilkan "Pengingat nonaktif"',
    (tester, h) async {
      await _openAgenda(tester);
      expect(find.textContaining('Pengingat nonaktif'), findsOneWidget);
    },
    seed: (db) async {
      await _seedAt(db, 'a', DateTime(2026, 1));
      await _seedAt(db, 'b', DateTime(2026, 2));
      await _seedAt(db, 'c', DateTime(2026, 3));
      await _seedAt(db, 'd', DateTime(2026, 4));
    },
    subscription: FakeSubscriptionStatus(),
  );

  appTest('premium tanpa data menampilkan pesan kosong', (tester, h) async {
    await _openAgenda(tester);
    expect(find.textContaining('Belum ada agenda'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest(
    'premium dengan 4 item: semua bisa dibuat, tidak ada yang terkunci',
    (tester, h) async {
      await _openAgenda(tester);
      expect(find.textContaining('Pengingat nonaktif'), findsNothing);

      // Masih bisa tambah item ke-5 tanpa dialihkan ke upgrade.
      await _addAgenda(tester, 'Servis Kulkas');
      expect(find.text('Agenda ditambahkan'), findsOneWidget);
    },
    seed: (db) async {
      await _seedAt(db, 'a', DateTime(2026, 1));
      await _seedAt(db, 'b', DateTime(2026, 2));
      await _seedAt(db, 'c', DateTime(2026, 3));
      await _seedAt(db, 'd', DateTime(2026, 4));
    },
    subscription: FakeSubscriptionStatus(premium: true),
  );

  appTest('premium: tambah agenda, muncul di daftar dengan jadwal', (
    tester,
    h,
  ) async {
    await _openAgenda(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);

    expect(find.text('Agenda Baru'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Servis AC');
    await tester.tap(find.text('Bulanan'));
    await settle(tester);
    await tester.tap(find.text('Tahunan').last);
    await settle(tester);

    await tester.tap(find.text('Simpan'));
    await settle(tester);

    expect(find.text('Agenda ditambahkan'), findsOneWidget);
    expect(find.text('Servis AC'), findsOneWidget);
    expect(find.textContaining('Setiap tahun'), findsOneWidget);
    expect(find.textContaining('Berikutnya'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest(
    'premium: jeda, lanjutkan, lalu hapus agenda',
    (tester, h) async {
      await _openAgenda(tester);
      expect(find.text('Servis kendaraan'), findsOneWidget);
      expect(find.textContaining('Berikutnya'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('Jeda'));
      await settle(tester);
      expect(find.textContaining('Dijeda'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('Lanjutkan'));
      await settle(tester);
      expect(find.textContaining('Berikutnya'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('Hapus'));
      await settle(tester);
      expect(find.text('Hapus agenda?'), findsOneWidget);
      await tester.tap(find.text('Hapus').last);
      await settle(tester);

      expect(find.textContaining('Belum ada agenda'), findsOneWidget);
      final items = await tester.runAsync(
        () => h.db.watchAgendaReminders().first,
      );
      expect(items, isEmpty);
    },
    seed: (db) async {
      await db.addAgenda(
        title: 'Servis kendaraan',
        frequency: Frequency.monthly,
        startDate: DateTime(2030, 1, 15),
      );
    },
    subscription: FakeSubscriptionStatus(premium: true),
  );
}
