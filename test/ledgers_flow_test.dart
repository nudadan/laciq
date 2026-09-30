import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/providers.dart';
import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:dompet_pintar/features/security/lock_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await settle(tester);
}

Finder get _chip => find.widgetWithText(ActionChip, 'Buku Utama');

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('bukan Ultimate: tidak ada pengalih buku; tile Buku Kas mengarah ke '
      'halaman langganan', (tester, h) async {
    expect(find.byType(ActionChip), findsNothing);
    await _openTab(tester, 'Lainnya');
    expect(find.text('Buku Kas'), findsOneWidget);
    expect(find.text('Fitur Ultimate'), findsOneWidget);

    await tester.tap(find.text('Buku Kas'));
    await settle(tester);
    expect(find.text('DompetKu Premium'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest('Ultimate: chip menampilkan Buku Utama; buat buku Bisnis lewat '
      'Kelola, otomatis aktif, dompet dan form terpisah', (tester, h) async {
    expect(_chip, findsOneWidget);

    // Buka pengalih -> Kelola buku kas.
    await tester.tap(_chip);
    await settle(tester);
    expect(find.text('Kelola buku kas'), findsOneWidget);
    await tester.tap(find.text('Kelola buku kas'));
    await settle(tester);
    expect(find.text('Kelola Buku Kas'), findsOneWidget);

    // Buku baru: nama + template Bisnis.
    await tester.tap(find.text('Buku Baru'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Toko');
    await tester.tap(find.text('Bisnis'));
    await settle(tester);
    await tester.tap(find.text('Simpan'));
    await settle(tester);
    expect(find.text('Buku kas ditambahkan'), findsOneWidget);

    // Kembali ke Ringkasan: chip kini "Toko".
    await _back(tester);
    await settle(tester);
    expect(find.widgetWithText(ActionChip, 'Toko'), findsOneWidget);
    // Pilihan tersimpan.
    final ledgers = await tester.runAsync(() => h.db.watchLedgers().first);
    final biz = ledgers!.firstWhere((l) => l.name == 'Toko').id;
    expect(await tester.runAsync(() => h.store.read('active_ledger_id')), biz);

    // Dompet: hanya Kas Usaha (jenisnya bertulisan "Tunai" satu kali), bukan
    // dompet Tunai milik Buku Utama (nama + jenis = dua kali).
    await _openTab(tester, 'Dompet');
    expect(find.text('Kas Usaha'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget);

    // Form Catat menyebut buku tujuan.
    await tester.tap(find.byTooltip('Catat'));
    await settle(tester);
    expect(find.text('Mencatat di: Toko'), findsOneWidget);
    await _back(tester);
    await settle(tester);

    // Kembali ke Buku Utama lewat pengalih.
    await tester.tap(find.widgetWithText(ActionChip, 'Toko'));
    await settle(tester);
    await tester.tap(find.text('Buku Utama'));
    await settle(tester);
    expect(_chip, findsOneWidget);
    expect(find.text('Tunai'), findsNWidgets(2));
    expect(find.text('Kas Usaha'), findsNothing);
  }, subscription: FakeSubscriptionStatus(ultimate: true));

  appTest(
    'Ultimate: transaksi tercatat di buku aktif saja',
    (tester, h) async {
      await _openTab(tester, 'Transaksi');
      expect(find.textContaining('nasi pribadi'), findsOneWidget);
      expect(find.textContaining('jual barang'), findsNothing);

      await tester.tap(_chip);
      await settle(tester);
      await tester.tap(find.text('Toko'));
      await settle(tester);
      expect(find.textContaining('jual barang'), findsOneWidget);
      expect(find.textContaining('nasi pribadi'), findsNothing);
    },
    subscription: FakeSubscriptionStatus(ultimate: true),
    seed: (db) async {
      final biz = await db.addLedger(
        name: 'Toko',
        icon: 'business',
        color: 0xFF00897B,
        template: LedgerTemplate.business,
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: 25000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-makan',
        date: DateTime.now(),
        note: 'nasi pribadi',
      );
      await db.addTransaction(
        type: TxType.income,
        amount: 90000,
        accountId: ledgerSeedId(biz, 'acc-tunai'),
        categoryId: ledgerSeedId(biz, 'cat-inc-penjualan'),
        date: DateTime.now(),
        note: 'jual barang',
      );
    },
  );

  appTest(
    'Ultimate berakhir: buku tambahan terkunci, hanya Buku Utama yang '
    'dipakai, data tetap utuh dan bisa diekspor',
    (tester, h) async {
      expect(find.byType(ActionChip), findsNothing);
      await _openTab(tester, 'Lainnya');
      expect(find.text('1 buku terkunci · Fitur Ultimate'), findsOneWidget);

      await tester.tap(find.text('Buku Kas'));
      await settle(tester);
      expect(find.text('Buku tambahan terkunci'), findsOneWidget);
      expect(find.text('Toko'), findsOneWidget);
      expect(find.textContaining('Terkunci'), findsOneWidget);
      // Tidak bisa membuat buku baru tanpa Ultimate.
      expect(find.text('Buku Baru'), findsNothing);

      // Menu buku terkunci: hanya Ekspor CSV (tanpa Ubah/Arsipkan/Hapus).
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await settle(tester);
      expect(find.text('Ekspor CSV'), findsOneWidget);
      expect(find.text('Hapus'), findsNothing);
      expect(find.text('Ubah'), findsNothing);
      await tester.tapAt(const Offset(5, 5)); // tutup menu
      await settle(tester);

      // Data buku tambahan masih ada di database.
      final all = await tester.runAsync(
        () => h.db.watchAccountBalances(ledgerId: null).first,
      );
      expect(all!.length, 2);
    },
    subscription: FakeSubscriptionStatus(premium: true),
    seed: (db) async {
      await db.addLedger(
        name: 'Toko',
        icon: 'business',
        color: 0xFF00897B,
        template: LedgerTemplate.business,
      );
    },
  );

  group('buku aktif yang dipakai', () {
    late AppDatabase db;
    late MemoryKeyValueStore store;
    late String biz;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      store = MemoryKeyValueStore();
      biz = await db.addLedger(name: 'Toko', icon: 'business', color: 1);
    });
    tearDown(() => db.close());

    Future<String> activeFor({
      required bool ultimate,
      required String? pref,
    }) async {
      if (pref != null) await store.write('active_ledger_id', pref);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          keyValueStoreProvider.overrideWithValue(store),
          subscriptionStatusProvider.overrideWithValue(
            FakeSubscriptionStatus(ultimate: ultimate),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(activeLedgerIdProvider, (_, _) {});
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      return container.read(activeLedgerIdProvider);
    }

    test('Ultimate dengan pilihan valid memakai buku itu', () async {
      expect(await activeFor(ultimate: true, pref: biz), biz);
    });

    test('pilihan yang sudah tidak ada jatuh ke Buku Utama', () async {
      expect(
        await activeFor(ultimate: true, pref: 'ledger-hantu'),
        kMainLedgerId,
      );
    });

    test('buku yang diarsipkan jatuh ke Buku Utama', () async {
      await db.setLedgerArchived(biz, archived: true);
      expect(await activeFor(ultimate: true, pref: biz), kMainLedgerId);
    });

    test('bukan Ultimate selalu Buku Utama walau pilihan tersimpan', () async {
      expect(await activeFor(ultimate: false, pref: biz), kMainLedgerId);
    });

    test('lockedLedgerIds: arsip selalu terkunci; non-Ultimate mengunci semua '
        'selain Buku Utama', () async {
      await db.addLedger(name: 'Arsip', icon: 'other', color: 1);
      final ledgers = await db.watchLedgers().first;
      final archivedId = ledgers.firstWhere((l) => l.name == 'Arsip').id;
      await db.setLedgerArchived(archivedId, archived: true);
      final fresh = await db.watchLedgers().first;
      expect(lockedLedgerIds(fresh, ultimate: true), {archivedId});
      expect(lockedLedgerIds(fresh, ultimate: false), {biz, archivedId});
    });
  });
}
