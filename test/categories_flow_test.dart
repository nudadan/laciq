import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _openCategories(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Kategori'));
  await settle(tester);
}

/// Tidak memakai tester.pageBack(): ia mencari tooltip 'Back', sedangkan
/// aplikasi berbahasa Indonesia ('Kembali').
Future<void> _back(WidgetTester tester, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);
  }
}

Future<void> _hiburanWithHistory(AppDatabase db) async {
  await db.addTransaction(
    type: TxType.expense,
    amount: 5000,
    accountId: 'acc-tunai',
    categoryId: 'cat-exp-hiburan',
    date: DateTime.now(),
  );
  await db.setBudget('cat-exp-hiburan', 100000);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('tambah', () {
    appTest(
      'kategori baru muncul di daftar dan langsung bisa dipilih saat mencatat',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Tambah'));
        await settle(tester);
        expect(find.text('Kategori Baru'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Kopi');
        await tester.tap(find.byKey(const ValueKey('icon-coffee')));
        await tester.tap(
          find.byKey(ValueKey('color-${0xFF6D4C41.toRadixString(16)}')),
        );
        await tester.pump();
        await tester.tap(find.text('Simpan'));
        await settle(tester);

        expect(find.text('Kategori ditambahkan'), findsOneWidget);
        expect(find.text('Kopi'), findsOneWidget);

        final c = (await tester.runAsync(
          () => h.db.watchCategories(TxType.expense).first,
        ))!.firstWhere((c) => c.name == 'Kopi');
        expect(
          (c.icon, c.color, c.type),
          ('coffee', 0xFF6D4C41, TxType.expense),
        );

        // Kategori tidak lagi di belakang Pengaturan (lihat lib/features/more/
        // more_page.dart) — cuma 1 level Navigator.push, bukan 2.
        await _back(tester, 1);
        await tester.tap(find.byTooltip('Catat'));
        await settle(tester);
        expect(find.text('Kopi'), findsOneWidget); // chip kategori
      },
    );

    appTest('tab Pemasukan membuat kategori bertipe pemasukan', (
      tester,
      h,
    ) async {
      await _openCategories(tester);
      await tester.tap(find.text('Pemasukan'));
      await settle(tester);
      await tester.tap(find.text('Tambah'));
      await settle(tester);
      expect(find.text('Pemasukan'), findsOneWidget); // label jenis di editor

      await tester.enterText(find.byType(TextField), 'Freelance');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      final c = (await tester.runAsync(
        () => h.db.watchCategories(TxType.income).first,
      ))!.firstWhere((c) => c.name == 'Freelance');
      expect(c.type, TxType.income);
      expect(find.text('Freelance'), findsOneWidget);
    });

    appTest('nama kembar menampilkan pesan dan tetap di editor', (
      tester,
      h,
    ) async {
      await _openCategories(tester);
      await tester.tap(find.text('Tambah'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'belanja');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.text('Sudah ada kategori "belanja".'), findsOneWidget);
      expect(find.text('Kategori Baru'), findsOneWidget);
    });

    appTest('nama kosong ditolak', (tester, h) async {
      await _openCategories(tester);
      await tester.tap(find.text('Tambah'));
      await settle(tester);
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect(find.text('Nama kategori wajib diisi.'), findsOneWidget);
    });
  });

  group('ubah', () {
    appTest('ganti nama: daftar dan form Catat ikut berubah', (
      tester,
      h,
    ) async {
      await _openCategories(tester);
      await tester.tap(find.text('Belanja'));
      await settle(tester);
      expect(find.text('Ubah Kategori'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Belanja'),
        findsOneWidget,
      ); // terisi

      await tester.enterText(find.byType(TextField), 'Belanja Bulanan');
      await tester.tap(find.text('Simpan'));
      await settle(tester);

      expect(find.text('Perubahan disimpan'), findsOneWidget);
      expect(find.text('Belanja Bulanan'), findsOneWidget);
      expect(find.text('Belanja'), findsNothing);

      await _back(tester, 1);
      await tester.tap(find.byTooltip('Catat'));
      await settle(tester);
      expect(find.text('Belanja Bulanan'), findsOneWidget);
    });
  });

  group('arsip', () {
    appTest(
      'arsipkan: dialog menjelaskan dampak, hilang dari pilihan, tetap di riwayat',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Hiburan'));
        await settle(tester);
        await tester.tap(find.text('Arsipkan kategori'));
        await settle(tester);

        expect(find.text('Arsipkan "Hiburan"?'), findsOneWidget);
        expect(
          find.textContaining('1 transaksi yang memakainya tetap tersimpan'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Anggarannya disembunyikan'),
          findsOneWidget,
        );
        await tester.tap(find.text('Arsipkan'));
        await settle(tester);

        expect(find.text('Kategori diarsipkan'), findsOneWidget);
        expect(find.text('Diarsipkan'), findsOneWidget); // header bagian
        expect(find.text('Hiburan'), findsOneWidget); // masih terlihat, redup

        // Tidak muncul lagi sebagai pilihan baru...
        await _back(tester, 1);
        await tester.tap(find.byTooltip('Catat'));
        await settle(tester);
        expect(find.text('Hiburan'), findsNothing);
        await _back(tester);

        // ...tetapi tetap ada di riwayat transaksi.
        await tester.tap(find.text('Transaksi').last);
        await settle(tester);
        expect(find.text('Hiburan'), findsOneWidget);
      },
      seed: _hiburanWithHistory,
    );

    appTest('pulihkan kategori yang diarsipkan', (tester, h) async {
      await _openCategories(tester);
      await tester.tap(find.text('Hiburan'));
      await settle(tester);
      expect(find.text('Simpan'), findsNothing); // read-only saat diarsipkan
      await tester.tap(find.text('Pulihkan kategori'));
      await settle(tester);

      expect(find.text('Kategori dipulihkan'), findsOneWidget);
      expect(find.text('Diarsipkan'), findsNothing);
    }, seed: (db) => db.setCategoryArchived('cat-exp-hiburan', archived: true));

    appTest(
      'kategori aktif terakhir tidak bisa diarsipkan',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Pemasukan'));
        await settle(tester);
        await tester.tap(find.text('Gaji'));
        await settle(tester);
        await tester.tap(find.text('Arsipkan kategori'));
        await settle(tester);
        await tester.tap(find.text('Arsipkan'));
        await settle(tester);

        expect(
          find.text('Harus ada minimal satu kategori aktif untuk jenis ini.'),
          findsOneWidget,
        );
        expect(find.text('Ubah Kategori'), findsOneWidget); // tetap di editor
      },
      seed: (db) async {
        final incomes = await db.watchCategories(TxType.income).first;
        for (final c in incomes.where((c) => c.id != 'cat-inc-gaji')) {
          await db.setCategoryArchived(c.id, archived: true);
        }
      },
    );

    appTest(
      'mengubah transaksi lama tetap menampilkan kategorinya yang diarsipkan',
      (tester, h) async {
        await tester.tap(find.text('Transaksi').last);
        await settle(tester);
        await tester.tap(find.text('Hiburan'));
        await settle(tester);

        expect(find.text('Ubah Transaksi'), findsOneWidget);
        final chip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Hiburan'),
        );
        expect(chip.selected, isTrue);
        // Kategori arsip lain tidak ikut tampil.
        expect(find.widgetWithText(ChoiceChip, 'Transportasi'), findsOneWidget);
      },
      seed: (db) async {
        await _hiburanWithHistory(db);
        await db.setCategoryArchived('cat-exp-hiburan', archived: true);
      },
    );
  });
}
