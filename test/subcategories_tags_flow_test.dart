import 'package:dompet_pintar/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _openLainnya(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Lainnya'),
    ),
  );
  await settle(tester);
}

Future<void> _openCategories(WidgetTester tester) async {
  await _openLainnya(tester);
  await tester.tap(find.text('Kategori'));
  await settle(tester);
}

Future<void> _openTags(WidgetTester tester) async {
  await _openLainnya(tester);
  await tester.tap(find.text('Tag'));
  await settle(tester);
}

Future<void> _back(WidgetTester tester, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('sub-kategori', () {
    appTest(
      'membuat sub-kategori lewat pemilih induk; tampil di daftar dan di form Catat',
      (tester, h) async {
        await _openCategories(tester);
        await tester.tap(find.text('Tambah'));
        await settle(tester);

        await tester.enterText(find.byType(TextField), 'Kopi');
        await tester.tap(
          find.widgetWithText(
            DropdownButtonFormField<String?>,
            'Sub-kategori dari (opsional)',
          ),
        );
        await settle(tester);
        await tester.tap(find.text('Makanan & Minuman').last);
        await settle(tester);
        await tester.tap(find.text('Simpan'));
        await settle(tester);

        expect(find.text('Kategori ditambahkan'), findsOneWidget);
        expect(find.text('Kopi'), findsOneWidget);

        final list = (await tester.runAsync(
          () => h.db.watchCategories(TxType.expense).first,
        ))!;
        final kopi = list.firstWhere((c) => c.name == 'Kopi');
        expect(kopi.parentId, 'cat-exp-makan');

        // Kategori tidak lagi di belakang Pengaturan — cuma 1 level
        // Navigator.push, bukan 2 (lihat lib/features/more/more_page.dart).
        await _back(tester, 1);
        await tester.tap(find.byTooltip('Catat'));
        await settle(tester);
        expect(find.text('↳ Kopi'), findsOneWidget);
      },
    );

    appTest(
      'mengarsipkan induk dengan sub-kategori aktif ditolak dengan pesan',
      (tester, h) async {
        await tester.runAsync(
          () => h.db.addCategory(
            type: TxType.expense,
            name: 'Kopi',
            icon: 'coffee',
            color: 1,
            parentId: 'cat-exp-makan',
          ),
        );
        await _openCategories(tester);
        await tester.tap(find.text('Makanan & Minuman').first);
        await settle(tester);
        await tester.tap(find.text('Arsipkan kategori'));
        await settle(tester);
        await tester.tap(find.text('Arsipkan').last);
        await settle(tester);

        expect(find.textContaining('sub-kategori aktif'), findsOneWidget);
      },
    );
  });

  group('tag', () {
    appTest(
      'tambah tag baru langsung dari form Catat, tersimpan dan terpilih lagi saat diubah',
      (tester, h) async {
        await tester.tap(find.byTooltip('Catat'));
        await settle(tester);

        await tester.enterText(find.byType(TextField).first, '20.000');
        await tester.tap(find.text('Makanan & Minuman'));
        await tester.pump();
        // TextField "Tag baru…" dikenali lewat hintText (tidak punya label).
        await tester.enterText(
          find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == 'Tag baru…',
          ),
          'Liburan',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);

        expect(find.widgetWithText(FilterChip, 'Liburan'), findsOneWidget);
        final chip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Liburan'),
        );
        expect(chip.selected, isTrue);

        await tester.tap(find.text('Simpan'));
        await settle(tester);

        final txs = (await tester.runAsync(() => h.db.getTransactions()))!;
        final tags = await tester.runAsync(
          () => h.db.watchTagsForTransaction(txs.last.tx.id).first,
        );
        expect(tags!.map((t) => t.name), ['Liburan']);
      },
    );

    appTest('kelola tag: tambah, ganti nama, hapus', (tester, h) async {
      await _openTags(tester);
      await tester.tap(find.text('Tambah'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Kantor');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect(find.text('Kantor'), findsOneWidget);

      await tester.tap(find.byTooltip('Ganti nama'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Kerja');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect(find.text('Kerja'), findsOneWidget);
      expect(find.text('Kantor'), findsNothing);

      await tester.tap(find.byTooltip('Hapus'));
      await settle(tester);
      await tester.tap(find.text('Hapus').last);
      await settle(tester);
      expect(find.text('Kerja'), findsNothing);
    });
  });
}
