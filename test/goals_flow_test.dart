import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// "Target" pindah dari tab navbar sendiri ke dalam hub "Lainnya" (lihat
/// lib/features/more/more_page.dart) — buka "Lainnya" dulu, baru tap tile
/// "Target" untuk masuk ke [GoalsPage] (sekarang halaman terpisah, bukan tab
/// inline lagi).
Future<void> _openGoalsTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Target'));
  await settle(tester);
}

Future<void> _openGoal(WidgetTester tester, [String name = 'Liburan']) async {
  await _openGoalsTab(tester);
  await tester.tap(find.text(name));
  await settle(tester);
}

Finder _inDialog(String text) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

bool _enabled(WidgetTester tester, String label) {
  final button = tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ),
  );
  return button.onPressed != null;
}

Future<void> _menu(WidgetTester tester, String item) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await settle(tester);
  await tester.tap(find.text(item));
  await settle(tester);
}

Future<void> _seedGoal(
  AppDatabase db, {
  int target = 1000000,
  int saved = 0,
  DateTime? deadline,
  String name = 'Liburan',
}) async {
  final id = await db.addGoal(
    name: name,
    targetAmount: target,
    icon: 'travel',
    color: 0xFF00897B,
    deadline: deadline,
  );
  if (saved > 0) {
    await db.addContribution(
      goalId: id,
      kind: ContributionKind.deposit,
      amount: saved,
    );
  }
}

Future<GoalView> _goal(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.watchGoals().first))!.first;

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('daftar dan pembuatan', () {
    appTest(
      'tab Target kosong: petunjuk dan tombol Target Baru menggantikan Catat',
      (tester, h) async {
        await _openGoalsTab(tester);
        expect(
          find.textContaining('Belum ada target tabungan'),
          findsOneWidget,
        );
        expect(find.byTooltip('Target Baru'), findsOneWidget);
        expect(find.byTooltip('Catat'), findsNothing);
      },
    );

    appTest('membuat target: muncul di daftar dengan progres 0%', (
      tester,
      h,
    ) async {
      await _openGoalsTab(tester);
      await tester.tap(find.byTooltip('Target Baru'));
      await settle(tester);
      expect(find.text('Target Baru').evaluate().length, greaterThan(0));

      await tester.enterText(find.byType(TextField).at(0), 'Liburan');
      await tester.enterText(find.byType(TextField).at(1), '6000000');
      await tester.tap(find.byKey(const ValueKey('icon-travel')));
      await tester.pump();
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.text('Target dibuat'), findsOneWidget);
      expect(find.text('Liburan'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.textContaining('6.000.000'), findsWidgets);
      final g = await _goal(tester, h.db);
      expect((g.goal.icon, g.target, g.saved), ('travel', 6000000, 0));
    });

    appTest('validasi form: nama dan nominal wajib', (tester, h) async {
      await _openGoalsTab(tester);
      await tester.tap(find.byTooltip('Target Baru'));
      await settle(tester);

      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect(find.text('Masukkan nominal target.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '1000');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect(find.text('Nama target wajib diisi.'), findsOneWidget);
    });

    appTest('kartu menampilkan dana terkumpul, persen, dan sisa', (
      tester,
      h,
    ) async {
      await _openGoalsTab(tester);
      expect(find.text('25%'), findsOneWidget);
      expect(find.textContaining('250.000 dari'), findsOneWidget);
      expect(find.textContaining('Sisa'), findsOneWidget);
      expect(find.textContaining('Saldo dompet tidak berubah'), findsOneWidget);
    }, seed: (db) => _seedGoal(db, saved: 250000));

    appTest(
      'tenggat: menampilkan perkiraan setoran per bulan; lewat tenggat ditandai',
      (tester, h) async {
        await _openGoalsTab(tester);
        expect(find.textContaining('perlu ±'), findsOneWidget);
        expect(find.textContaining('/bulan'), findsOneWidget);
        expect(find.textContaining('Lewat tenggat'), findsOneWidget);
      },
      seed: (db) async {
        await _seedGoal(
          db,
          name: 'Motor',
          target: 6000000,
          deadline: DateTime.now().add(const Duration(days: 185)),
        );
        await _seedGoal(
          db,
          name: 'Kado',
          deadline: DateTime.now().subtract(const Duration(days: 30)),
        );
      },
    );
  });

  group('setor dan tarik', () {
    appTest(
      'setor: dialog menutup, dana dan riwayat bertambah, saldo dompet tetap',
      (tester, h) async {
        await _openGoal(tester);
        expect(
          find.text('Belum ada setoran.\nKetuk "Setor" untuk mulai menabung.'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Setor'));
        await settle(tester);
        expect(find.text('Setor ke Liburan'), findsOneWidget);
        await tester.enterText(find.byType(TextField).at(0), '250000');
        await tester.enterText(find.byType(TextField).at(1), 'dari gaji');
        await tester.tap(_inDialog('Setor'));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('25%'), findsOneWidget);
        expect(find.text('Setoran'), findsOneWidget);
        expect(find.textContaining('dari gaji'), findsOneWidget);
        expect(find.textContaining('+Rp'), findsOneWidget);

        expect((await _goal(tester, h.db)).saved, 250000);
        final accounts = (await tester.runAsync(
          () => h.db.watchAccountBalances().first,
        ))!;
        expect(accounts.single.balance, 0); // dompet tidak terpengaruh
      },
      seed: (db) => _seedGoal(db),
    );

    appTest('setoran yang mencapai target menampilkan ucapan selamat', (
      tester,
      h,
    ) async {
      await _openGoal(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Setor'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), '300000');
      await tester.tap(_inDialog('Setor'));
      await settle(tester);

      expect(find.text('Selamat! Target "Liburan" tercapai.'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Tercapai'), findsOneWidget);
    }, seed: (db) => _seedGoal(db, target: 1000000, saved: 700000));

    appTest('setor tanpa nominal: dialog tetap terbuka dengan pesan', (
      tester,
      h,
    ) async {
      await _openGoal(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Setor'));
      await settle(tester);
      await tester.tap(_inDialog('Setor'));
      await settle(tester);
      expect(find.text('Masukkan nominal.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    }, seed: (db) => _seedGoal(db));

    appTest('batal menutup dialog tanpa perubahan', (tester, h) async {
      await _openGoal(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Setor'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), '1000');
      await tester.tap(find.text('Batal'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await _goal(tester, h.db)).saved, 0);
    }, seed: (db) => _seedGoal(db));

    appTest('tarik: tidak bisa melebihi dana; nominal sah mengurangi dana', (
      tester,
      h,
    ) async {
      await _openGoal(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tarik'));
      await settle(tester);
      expect(find.text('Tarik dari Liburan'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '300000');
      await tester.tap(_inDialog('Tarik'));
      await settle(tester);
      expect(find.textContaining('Dana terkumpul hanya'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '100000');
      await tester.tap(_inDialog('Tarik'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await _goal(tester, h.db)).saved, 100000);
      expect(find.text('Penarikan'), findsOneWidget);
    }, seed: (db) => _seedGoal(db, saved: 200000));

    appTest('tombol Tarik nonaktif bila belum ada dana', (tester, h) async {
      await _openGoal(tester);
      expect(_enabled(tester, 'Setor'), isTrue);
      expect(_enabled(tester, 'Tarik'), isFalse);
    }, seed: (db) => _seedGoal(db));
  });

  group('riwayat', () {
    appTest(
      'menggeser setoran yang sudah sebagian ditarik ditolak dengan pesan',
      (tester, h) async {
        await _openGoal(tester);
        await tester.drag(find.text('Setoran'), const Offset(-600, 0));
        await settle(tester);

        expect(
          find.textContaining('dana terkumpul akan menjadi negatif'),
          findsOneWidget,
        );
        expect(find.text('Setoran'), findsOneWidget); // baris tetap ada
        expect((await _goal(tester, h.db)).saved, 300000);
      },
      seed: (db) async {
        await _seedGoal(db, saved: 500000);
        final g = (await db.watchGoals().first).first;
        await db.addContribution(
          goalId: g.goal.id,
          kind: ContributionKind.withdrawal,
          amount: 200000,
        );
      },
    );

    appTest(
      'menggeser penarikan menghapusnya; Batal memulihkan',
      (tester, h) async {
        await _openGoal(tester);
        expect((await _goal(tester, h.db)).saved, 300000);

        await tester.drag(find.text('Penarikan'), const Offset(-600, 0));
        await settle(tester);
        expect(find.text('Penarikan dihapus'), findsOneWidget);
        expect((await _goal(tester, h.db)).saved, 500000);

        await tester.tap(find.text('Batal'));
        await settle(tester);
        expect((await _goal(tester, h.db)).saved, 300000);
        expect(find.text('Penarikan'), findsOneWidget);
      },
      seed: (db) async {
        await _seedGoal(db, saved: 500000);
        final g = (await db.watchGoals().first).first;
        await db.addContribution(
          goalId: g.goal.id,
          kind: ContributionKind.withdrawal,
          amount: 200000,
        );
      },
    );
  });

  group('kelola target', () {
    appTest('ubah target: form terisi, perubahan tampil di detail', (
      tester,
      h,
    ) async {
      await _openGoal(tester);
      await tester.tap(find.byTooltip('Ubah target'));
      await settle(tester);
      expect(find.text('Ubah Target'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Liburan'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1.000.000'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Liburan Bali');
      await tester.enterText(find.byType(TextField).at(1), '2000000');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.text('Perubahan disimpan'), findsOneWidget);
      expect(find.text('Liburan Bali'), findsOneWidget);
      expect(
        find.text('12%'),
        findsOneWidget,
      ); // 250.000 / 2.000.000 = 12,5% -> 12
      expect((await _goal(tester, h.db)).target, 2000000);
    }, seed: (db) => _seedGoal(db, saved: 250000));

    appTest(
      'arsipkan: tombol setor/tarik nonaktif, muncul di bagian Diarsipkan, bisa dipulihkan',
      (tester, h) async {
        await _openGoal(tester);
        await _menu(tester, 'Arsipkan target');
        expect(find.text('Target diarsipkan'), findsOneWidget);
        expect(find.textContaining('Target ini diarsipkan'), findsOneWidget);
        expect(_enabled(tester, 'Setor'), isFalse);
        expect(_enabled(tester, 'Tarik'), isFalse);

        await tester.tap(find.byType(BackButton));
        await settle(tester);
        expect(find.text('Diarsipkan'), findsOneWidget);

        await tester.tap(find.text('Liburan'));
        await settle(tester);
        await _menu(tester, 'Pulihkan target');
        expect(find.text('Target dipulihkan'), findsOneWidget);
        expect(_enabled(tester, 'Setor'), isTrue);
      },
      seed: (db) => _seedGoal(db, saved: 100000),
    );

    appTest(
      'hapus target: konfirmasi menjelaskan dampak, lalu hilang dari daftar',
      (tester, h) async {
        await _openGoal(tester);
        await _menu(tester, 'Hapus target');
        expect(find.text('Hapus "Liburan"?'), findsOneWidget);
        expect(
          find.textContaining('Saldo dompet Anda tidak terpengaruh'),
          findsOneWidget,
        );
        await tester.tap(find.text('Hapus'));
        await settle(tester);

        expect(find.text('Target dihapus'), findsOneWidget);
        expect(
          find.textContaining('Belum ada target tabungan'),
          findsOneWidget,
        );
        final goals = await tester.runAsync(() => h.db.watchGoals().first);
        expect(goals, isEmpty);
      },
      seed: (db) => _seedGoal(db, saved: 100000),
    );

    appTest('batal menghapus target tidak mengubah apa pun', (tester, h) async {
      await _openGoal(tester);
      await _menu(tester, 'Hapus target');
      await tester.tap(find.text('Batal'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await _goal(tester, h.db)).saved, 100000);
    }, seed: (db) => _seedGoal(db, saved: 100000));
  });
}
