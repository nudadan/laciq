import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Mode usaha dan pilihan kelompok laporan kategori (docs/RENCANA-IMPLEMENTASI-UMKM.md §4.2).

Future<void> _openMore(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
}

Future<void> _openCategories(WidgetTester tester) async {
  await _openMore(tester);
  await tester.tap(find.text('Kategori'));
  await settle(tester);
}

Future<Ledger> _main(WidgetTester tester, AppHarness h) async =>
    (await tester.runAsync(() => h.db.watchLedgers().first))!
        .firstWhere((l) => l.id == kMainLedgerId);

Future<ReportGroup?> _groupOf(
  WidgetTester tester,
  AppHarness h,
  String name,
) async {
  final all = (await tester.runAsync(
    () => h.db.select(h.db.categories).get(),
  ))!;
  return all.firstWhere((c) => c.name == name).reportGroup;
}

/// Mode usaha dinyalakan lewat data (bukan lewat UI) agar tes fokus ke kategori.
Future<void> _businessMain(AppDatabase db) =>
    db.setLedgerKind(kMainLedgerId, LedgerKind.business);

final _groupField = find.byType(DropdownButtonFormField<ReportGroup?>);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('saklar Mode usaha', () {
    appTest(
      'ada di Lainnya untuk semua paket; menyala dan mati mengubah sifat buku',
      (tester, h) async {
        await _openMore(tester);
        expect(find.text('Mode usaha'), findsOneWidget);
        expect((await _main(tester, h)).kind, LedgerKind.personal);

        await tester.tap(find.byType(Switch));
        await settle(tester);
        expect((await _main(tester, h)).kind, LedgerKind.business);
        expect(
          find.text('Kategori dikelompokkan untuk laporan Laba Rugi.'),
          findsOneWidget,
        );

        await tester.tap(find.byType(Switch));
        await settle(tester);
        expect((await _main(tester, h)).kind, LedgerKind.personal);
      },
      subscription: FakeSubscriptionStatus(),
    );

    appTest('mengubah mode tidak menyentuh data', (tester, h) async {
      await _openMore(tester);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      final balances = (await tester.runAsync(
        () => h.db.watchAccountBalances().first,
      ))!;
      expect(balances.single.id, 'acc-tunai');
      expect(await _groupOf(tester, h, 'Makanan & Minuman'), isNull);
    }, subscription: FakeSubscriptionStatus());
  });

  group('editor kategori', () {
    appTest('buku pribadi: tidak ada pilihan "Masuk ke laporan sebagai"', (
      tester,
      h,
    ) async {
      await _openCategories(tester);
      // Daftar tidak menampilkan kelompok.
      expect(find.textContaining('Di luar laba rugi'), findsNothing);
      await tester.tap(find.text('Tambah'));
      await settle(tester);
      expect(find.text('Kategori Baru'), findsOneWidget);
      expect(find.text('Masuk ke laporan sebagai'), findsNothing);
      expect(_groupField, findsNothing);
    }, subscription: FakeSubscriptionStatus());

    appTest(
      'buku usaha: daftar menampilkan kelompok tiap kategori utama',
      (tester, h) async {
        await _openCategories(tester);
        // Pengeluaran: bawaan jenis = beban operasional; Utang di luar laba rugi.
        expect(find.text('Beban operasional · otomatis'), findsWidgets);
        expect(find.text('Di luar laba rugi'), findsOneWidget); // Utang
        await tester.tap(find.text('Pemasukan'));
        await settle(tester);
        expect(find.text('Pendapatan usaha · otomatis'), findsWidgets);
        expect(find.text('Di luar laba rugi'), findsOneWidget); // Piutang
      },
      subscription: FakeSubscriptionStatus(),
      seed: _businessMain,
    );

    appTest(
      'kategori baru "Beli stok": disarankan HPP, bisa disimpan',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Tambah'));
        await settle(tester);
        expect(find.text('Masuk ke laporan sebagai'), findsOneWidget);
        expect(find.text('Otomatis (Beban operasional)'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Beli stok');
        await tester.pump();
        expect(find.text('Harga pokok penjualan (HPP)'), findsOneWidget);
        expect(
          find.text('Disarankan dari nama kategori. Ubah bila perlu.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Simpan'));
        await settle(tester);
        expect(find.text('Kategori ditambahkan'), findsOneWidget);
        expect(await _groupOf(tester, h, 'Beli stok'), ReportGroup.cogs);
      },
      subscription: FakeSubscriptionStatus(),
      seed: _businessMain,
    );

    appTest(
      'nama yang tidak dikenali: tanpa saran, disimpan otomatis (kosong)',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Tambah'));
        await settle(tester);
        await tester.enterText(find.byType(TextField), 'Sewa kios');
        await tester.pump();
        expect(find.textContaining('Disarankan dari nama'), findsNothing);
        await tester.tap(find.text('Simpan'));
        await settle(tester);
        expect(await _groupOf(tester, h, 'Sewa kios'), isNull);
      },
      subscription: FakeSubscriptionStatus(),
      seed: _businessMain,
    );

    appTest(
      'pilihan manual menang atas saran, dan tidak ditimpa saat nama berubah',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Tambah'));
        await settle(tester);
        await tester.enterText(find.byType(TextField), 'Beli stok');
        await tester.pump();

        // Pengguna memilih sendiri "Beban lain".
        await tester.tap(_groupField);
        await settle(tester);
        await tester.tap(find.text('Beban lain').last);
        await settle(tester);
        expect(
          find.text('Disarankan dari nama kategori. Ubah bila perlu.'),
          findsNothing,
        );

        // Mengetik nama lain tidak mengubah pilihan.
        await tester.enterText(find.byType(TextField), 'Beli stok barang');
        await tester.pump();
        await tester.tap(find.text('Simpan'));
        await settle(tester);
        expect(
          await _groupOf(tester, h, 'Beli stok barang'),
          ReportGroup.otherExpense,
        );
      },
      subscription: FakeSubscriptionStatus(),
      seed: _businessMain,
    );

    appTest(
      'pemasukan menawarkan kelompok pemasukan saja',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Pemasukan'));
        await settle(tester);
        await tester.tap(find.text('Tambah'));
        await settle(tester);
        await tester.tap(_groupField);
        await settle(tester);
        expect(find.text('Pendapatan usaha'), findsWidgets);
        expect(find.text('Pendapatan lain'), findsWidgets);
        expect(find.text('Harga pokok penjualan (HPP)'), findsNothing);
        expect(find.text('Beban operasional'), findsNothing);
      },
      subscription: FakeSubscriptionStatus(),
      seed: _businessMain,
    );

    appTest(
      'mengubah kelompok kategori yang ada, lalu kembali ke otomatis',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Hiburan'));
        await settle(tester);
        await tester.tap(_groupField);
        await settle(tester);
        await tester.tap(find.text('Beban lain').last);
        await settle(tester);
        await tester.tap(find.text('Simpan'));
        await settle(tester);
        expect(await _groupOf(tester, h, 'Hiburan'), ReportGroup.otherExpense);
        expect(find.text('Beban lain'), findsOneWidget); // tampil di daftar

        await tester.tap(find.text('Hiburan'));
        await settle(tester);
        await tester.tap(_groupField);
        await settle(tester);
        await tester.tap(find.textContaining('Otomatis (').last);
        await settle(tester);
        await tester.tap(find.text('Simpan'));
        await settle(tester);
        expect(await _groupOf(tester, h, 'Hiburan'), isNull);
      },
      subscription: FakeSubscriptionStatus(),
      seed: _businessMain,
    );

    appTest(
      'mengubah nama tanpa menyentuh kelompok tidak mengubah kelompoknya',
      (tester, h) async {
        await tester.runAsync(
          () => h.db.setCategoryReportGroup(
            'cat-exp-hiburan',
            ReportGroup.otherExpense,
          ),
        );
        await _openCategories(tester);
        await tester.tap(find.text('Hiburan'));
        await settle(tester);
        await tester.enterText(find.byType(TextField), 'Hiburan keluarga');
        await tester.pump();
        await tester.tap(find.text('Simpan'));
        await settle(tester);
        expect(
          await _groupOf(tester, h, 'Hiburan keluarga'),
          ReportGroup.otherExpense,
        );
      },
      subscription: FakeSubscriptionStatus(),
      seed: _businessMain,
    );

    appTest(
      'sub-kategori: pilihan kelompok diganti catatan, kelompok tersimpan kosong',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Tambah'));
        await settle(tester);
        await tester.enterText(find.byType(TextField), 'Beli stok kopi');
        await tester.pump();
        expect(_groupField, findsOneWidget);

        // Jadikan sub-kategori dari "Makanan & Minuman".
        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await settle(tester);
        await tester.tap(find.text('Makanan & Minuman').last);
        await settle(tester);
        expect(_groupField, findsNothing);
        expect(
          find.text(
            'Sub-kategori mengikuti kelompok laporan kategori induknya.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Simpan'));
        await settle(tester);
        expect(await _groupOf(tester, h, 'Beli stok kopi'), isNull);
      },
      subscription: FakeSubscriptionStatus(),
      seed: _businessMain,
    );

    appTest(
      'kategori sistem (Utang) menampilkan "Di luar laba rugi" di editor',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Utang'));
        await settle(tester);
        expect(find.text('Di luar laba rugi'), findsWidgets);
        expect(
          find.textContaining('Tidak mengubah untung-rugi'),
          findsOneWidget,
        );
      },
      subscription: FakeSubscriptionStatus(),
      seed: _businessMain,
    );
  });

  group('dialog buku kas (Ultimate)', () {
    Future<void> openLedgers(WidgetTester tester) async {
      await _openMore(tester);
      await tester.tap(find.text('Buku Kas'));
      await settle(tester);
    }

    appTest('template Bisnis menyalakan saklar "Buku usaha" otomatis', (
      tester,
      h,
    ) async {
      await openLedgers(tester);
      await tester.tap(find.text('Buku Baru'));
      await settle(tester);
      final sw = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      await tester.tap(find.text('Bisnis'));
      await settle(tester);
      expect(tester.widget<SwitchListTile>(sw).value, isTrue);

      await tester.enterText(find.byType(TextField), 'Toko');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      final toko = (await tester.runAsync(() => h.db.watchLedgers().first))!
          .firstWhere((l) => l.name == 'Toko');
      expect(toko.kind, LedgerKind.business);
    }, subscription: FakeSubscriptionStatus(ultimate: true));

    appTest(
      'template Pribadi + saklar dinyalakan sendiri = buku usaha; saklar tidak lagi ikut template',
      (tester, h) async {
        await openLedgers(tester);
        await tester.tap(find.text('Buku Baru'));
        await settle(tester);
        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();
        // Mengganti template setelah menyentuh saklar tidak mengubahnya lagi.
        await tester.tap(find.text('Kosong'));
        await settle(tester);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
        await tester.enterText(find.byType(TextField), 'Usaha kecil');
        await tester.tap(find.text('Simpan'));
        await settle(tester);
        final l = (await tester.runAsync(() => h.db.watchLedgers().first))!
            .firstWhere((l) => l.name == 'Usaha kecil');
        expect(l.kind, LedgerKind.business);
      },
      subscription: FakeSubscriptionStatus(ultimate: true),
    );

    appTest('Ubah buku: saklar mengubah sifat buku yang ada', (
      tester,
      h,
    ) async {
      await openLedgers(tester);
      await tester.tap(find.byTooltip('Aksi').first);
      await settle(tester);
      await tester.tap(find.text('Ubah'));
      await settle(tester);
      expect(find.text('Ubah Buku Kas'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect((await _main(tester, h)).kind, LedgerKind.business);
      // Kembali ke pribadi.
      await tester.tap(find.byTooltip('Aksi').first);
      await settle(tester);
      await tester.tap(find.text('Ubah'));
      await settle(tester);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect((await _main(tester, h)).kind, LedgerKind.personal);
    }, subscription: FakeSubscriptionStatus(ultimate: true));
  });
}
