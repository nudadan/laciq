import 'package:drift/native.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('DB: estimasi biaya & eksekusi agenda', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('estimasi biaya tersimpan dan terbaca lagi', () async {
      final id = await db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: DateTime(2030, 1, 10),
        estimatedAmount: 350000,
      );
      final item = (await db.watchAgendaReminders().first).single;
      expect((item.id, item.estimatedAmount), (id, 350000));
    });

    test('estimasi nol atau negatif ditolak', () async {
      expect(
        () => db.addAgenda(
          title: 'Servis AC',
          frequency: Frequency.monthly,
          startDate: DateTime(2030, 1, 10),
          estimatedAmount: 0,
        ),
        throwsA(isA<AccountException>()),
      );
    });

    test('updateAgenda bisa mengubah dan menghapus estimasi', () async {
      final id = await db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: DateTime(2030, 1, 10),
        estimatedAmount: 350000,
      );
      await db.updateAgenda(
        id: id,
        title: 'Servis AC',
        estimatedAmount: 400000,
      );
      expect(
        (await db.watchAgendaReminders().first).single.estimatedAmount,
        400000,
      );

      // Tidak mengirim estimatedAmount = mengirim null = menghapus, sama
      // pola dengan endDate.
      await db.updateAgenda(id: id, title: 'Servis AC');
      expect(
        (await db.watchAgendaReminders().first).single.estimatedAmount,
        null,
      );
    });

    test('executeAgenda: nominal aktual boleh beda dari estimasi, agendaId tertaut', () async {
      final id = await db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: DateTime(2030, 1, 10),
        estimatedAmount: 350000,
      );
      final txId = await db.executeAgenda(
        agendaId: id,
        amount: 420000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-rumah',
        date: DateTime(2030, 1, 10),
      );
      final tx = (await db.getTransactions()).single.tx;
      expect(
        (tx.id, tx.amount, tx.agendaId, tx.type),
        (txId, 420000, id, TxType.expense),
      );
    });

    test('executeAgenda memajukan nextIndex tepat satu langkah', () async {
      final id = await db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: DateTime(2030, 1, 10),
      );
      await db.executeAgenda(
        agendaId: id,
        amount: 100000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-rumah',
        date: DateTime(2030, 1, 10),
      );
      final after = AgendaView((await db.watchAgendaReminders().first).single);
      expect(after.item.nextIndex, 1);
      expect(after.nextDue, DateTime(2030, 2, 10));
    });

    test('agenda Sekali jadi selesai setelah dieksekusi', () async {
      final id = await db.addAgenda(
        title: 'Beli AC baru',
        frequency: Frequency.once,
        startDate: DateTime(2030, 5, 1),
      );
      final before = AgendaView((await db.watchAgendaReminders().first).single);
      expect(before.finished, isFalse);

      await db.executeAgenda(
        agendaId: id,
        amount: 3500000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-rumah',
        date: DateTime(2030, 5, 1),
      );
      final after = AgendaView((await db.watchAgendaReminders().first).single);
      expect(after.finished, isTrue);
    });

    test(
      'advancePastAgenda: item Sekali yang overdue tanpa dieksekusi otomatis '
      'selesai, tanpa hang',
      () async {
        await db.addAgenda(
          title: 'Beli AC baru',
          frequency: Frequency.once,
          startDate: DateTime(2026, 1, 1),
        );
        await db.advancePastAgenda(now: DateTime(2026, 6, 1));
        final view = AgendaView((await db.watchAgendaReminders().first).single);
        expect((view.item.nextIndex, view.finished), (1, true));
      },
    );

    test(
      'advancePastAgenda: item Sekali yang belum jatuh tempo tidak berubah',
      () async {
        await db.addAgenda(
          title: 'Beli AC baru',
          frequency: Frequency.once,
          startDate: DateTime(2026, 12, 1),
        );
        await db.advancePastAgenda(now: DateTime(2026, 6, 1));
        final view = AgendaView((await db.watchAgendaReminders().first).single);
        expect((view.item.nextIndex, view.finished), (0, false));
      },
    );

    test('setAgendaActive lanjutkan item Sekali yang dijeda & overdue tidak '
        'hang, nextIndex tetap 0', () async {
      final id = await db.addAgenda(
        title: 'Beli AC baru',
        frequency: Frequency.once,
        startDate: DateTime(2026, 1, 1),
      );
      await db.setAgendaActive(id, active: false);
      await db.setAgendaActive(id, active: true, now: DateTime(2026, 6, 1));
      final item = (await db.watchAgendaReminders().first).single;
      expect((item.nextIndex, item.active), (0, true));
    });
  });

  group('Widget: alur "Catat transaksi" dari Agenda', () {
    Future<void> openAgenda(WidgetTester tester) async {
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

    appTest(
      'isi estimasi biaya saat buat agenda baru: tersimpan, tampil lagi saat diubah',
      (tester, h) async {
        await openAgenda(tester);
        await tester.tap(find.byIcon(Icons.add_rounded));
        await settle(tester);

        await tester.enterText(find.byType(TextField).at(0), 'Servis AC');
        await tester.enterText(find.byType(TextField).at(1), '350000');
        await tester.tap(find.text('Simpan'));
        await settle(tester);
        expect(find.text('Agenda ditambahkan'), findsOneWidget);

        await tester.tap(find.text('Servis AC'));
        await settle(tester);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(1))
              .controller!
              .text,
          '350.000',
        );
      },
    );

    appTest(
      'catat transaksi dari agenda bulanan: prefill dari estimasi, nominal '
      'bisa diubah, jadwal maju ke bulan berikutnya',
      (tester, h) async {
        await openAgenda(tester);
        expect(find.textContaining('Berikutnya 10 Jan 2030'), findsOneWidget);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await settle(tester);
        await tester.tap(find.text('Catat transaksi'));
        await settle(tester);

        expect(find.text('Catat dari Agenda'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(0))
              .controller!
              .text,
          '350.000',
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(2))
              .controller!
              .text,
          'Servis AC',
        );

        await tester.enterText(find.byType(TextField).at(0), '420000');
        await tester.tap(find.byType(ChoiceChip).first);
        await settle(tester);
        await tester.tap(find.text('Simpan'));
        await settle(tester);

        expect(find.text('Transaksi dicatat dari agenda'), findsOneWidget);
        final txs = await tester.runAsync(() => h.db.getTransactions());
        expect(txs!.single.tx.amount, 420000);
        expect(find.textContaining('Berikutnya 10 Feb 2030'), findsOneWidget);
      },
      seed: (db) => db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: DateTime(2030, 1, 10),
        estimatedAmount: 350000,
      ),
    );

    appTest(
      'catat transaksi dari agenda Sekali: tile jadi "Selesai", aksi hilang dari menu',
      (tester, h) async {
        await openAgenda(tester);
        expect(find.textContaining('Selesai'), findsNothing);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await settle(tester);
        expect(find.text('Catat transaksi'), findsOneWidget);
        await tester.tap(find.text('Catat transaksi'));
        await settle(tester);

        // Tanpa estimasi biaya, nominal kosong — isi manual sebelum simpan.
        await tester.enterText(find.byType(TextField).at(0), '3500000');
        await tester.tap(find.byType(ChoiceChip).first);
        await settle(tester);
        await tester.tap(find.text('Simpan'));
        await settle(tester);

        expect(find.text('Transaksi dicatat dari agenda'), findsOneWidget);
        expect(find.textContaining('Selesai'), findsOneWidget);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await settle(tester);
        expect(find.text('Catat transaksi'), findsNothing);
        expect(find.text('Jeda'), findsNothing);
        expect(find.text('Ubah'), findsOneWidget);
        expect(find.text('Hapus'), findsOneWidget);
      },
      seed: (db) => db.addAgenda(
        title: 'Beli AC baru',
        frequency: Frequency.once,
        startDate: DateTime(2030, 5, 1),
      ),
    );
  });
}
