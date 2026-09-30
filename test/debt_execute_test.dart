import 'package:drift/native.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('DB: utang/piutang & pembayaran', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test(
      'kategori bawaan "Utang" (pengeluaran) dan "Piutang" (pemasukan) '
      'tersedia sejak database baru dibuat, supaya pembayaran mudah dilacak',
      () async {
        final expenseCats = await db.watchCategories(TxType.expense).first;
        final utang = expenseCats.firstWhere((c) => c.id == 'cat-exp-utang');
        expect(utang.name, 'Utang');

        final incomeCats = await db.watchCategories(TxType.income).first;
        final piutang = incomeCats.firstWhere((c) => c.id == 'cat-inc-piutang');
        expect(piutang.name, 'Piutang');
      },
    );

    test(
      'addDebt tersimpan dan terbaca lagi, paidAmount mulai dari 0',
      () async {
        final id = await db.addDebt(
          type: DebtType.debt,
          counterpartyName: 'Budi',
          amount: 500000,
        );
        final item = (await db.watchDebts().first).single;
        expect(
          (
            item.id,
            item.type,
            item.counterpartyName,
            item.amount,
            item.paidAmount,
          ),
          (id, DebtType.debt, 'Budi', 500000, 0),
        );
      },
    );

    test('nama kosong atau nominal nol/negatif ditolak', () async {
      expect(
        () => db.addDebt(
          type: DebtType.debt,
          counterpartyName: '  ',
          amount: 100000,
        ),
        throwsA(isA<AccountException>()),
      );
      expect(
        () => db.addDebt(
          type: DebtType.debt,
          counterpartyName: 'Budi',
          amount: 0,
        ),
        throwsA(isA<AccountException>()),
      );
    });

    test('updateDebt mengubah nama/nominal/catatan, tipe tidak bisa diubah '
        '(tidak ada parameter type)', () async {
      final id = await db.addDebt(
        type: DebtType.receivable,
        counterpartyName: 'Sari',
        amount: 200000,
      );
      await db.updateDebt(
        id: id,
        counterpartyName: 'Sari Wijaya',
        amount: 250000,
        note: 'pinjam buat modal',
      );
      final item = (await db.watchDebts().first).single;
      expect(
        (item.counterpartyName, item.amount, item.note),
        ('Sari Wijaya', 250000, 'pinjam buat modal'),
      );
    });

    test('deleteDebt menghapus baris', () async {
      final id = await db.addDebt(
        type: DebtType.debt,
        counterpartyName: 'Budi',
        amount: 100000,
      );
      await db.deleteDebt(id);
      expect(await db.watchDebts().first, isEmpty);
    });

    test(
      'recordDebtPayment (utang): mencatat PENGELUARAN, menambah paidAmount, '
      'debtId tertaut',
      () async {
        final id = await db.addDebt(
          type: DebtType.debt,
          counterpartyName: 'Budi',
          amount: 500000,
        );
        final txId = await db.recordDebtPayment(
          debtId: id,
          amount: 200000,
          accountId: 'acc-tunai',
          date: DateTime(2026, 4, 1),
        );
        final tx = (await db.getTransactions()).single.tx;
        expect(
          (tx.id, tx.type, tx.amount, tx.debtId),
          (txId, TxType.expense, 200000, id),
        );
        final debt = (await db.watchDebts().first).single;
        expect(debt.paidAmount, 200000);
      },
    );

    test('recordDebtPayment (piutang): mencatat PEMASUKAN', () async {
      final id = await db.addDebt(
        type: DebtType.receivable,
        counterpartyName: 'Sari',
        amount: 300000,
      );
      final txId = await db.recordDebtPayment(
        debtId: id,
        amount: 300000,
        accountId: 'acc-tunai',
        date: DateTime(2026, 4, 1),
      );
      final tx = (await db.getTransactions()).single.tx;
      expect((tx.id, tx.type), (txId, TxType.income));
    });

    test('recordDebtPayment menerima kategori "Utang"/"Piutang" bawaan '
        '(dipilih otomatis oleh UI, lihat TransactionFormPage)', () async {
      final debtId = await db.addDebt(
        type: DebtType.debt,
        counterpartyName: 'Budi',
        amount: 100000,
      );
      final debtTxId = await db.recordDebtPayment(
        debtId: debtId,
        amount: 100000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-utang',
        date: DateTime(2026, 4, 1),
      );
      final receivableId = await db.addDebt(
        type: DebtType.receivable,
        counterpartyName: 'Sari',
        amount: 200000,
      );
      final receivableTxId = await db.recordDebtPayment(
        debtId: receivableId,
        amount: 200000,
        accountId: 'acc-tunai',
        categoryId: 'cat-inc-piutang',
        date: DateTime(2026, 4, 1),
      );
      final txs = await db.getTransactions();
      final debtTx = txs.firstWhere((e) => e.tx.id == debtTxId).tx;
      final receivableTx = txs.firstWhere((e) => e.tx.id == receivableTxId).tx;
      expect(debtTx.categoryId, 'cat-exp-utang');
      expect(receivableTx.categoryId, 'cat-inc-piutang');
    });

    test('pembayaran sebagian berkali-kali: paidAmount terakumulasi, lunas '
        'setelah total >= pokok', () async {
      final id = await db.addDebt(
        type: DebtType.debt,
        counterpartyName: 'Budi',
        amount: 500000,
      );
      await db.recordDebtPayment(
        debtId: id,
        amount: 200000,
        accountId: 'acc-tunai',
        date: DateTime(2026, 4, 1),
      );
      var view = DebtView((await db.watchDebts().first).single);
      expect(
        (view.item.paidAmount, view.remaining, view.settled),
        (200000, 300000, false),
      );

      await db.recordDebtPayment(
        debtId: id,
        amount: 300000,
        accountId: 'acc-tunai',
        date: DateTime(2026, 5, 1),
      );
      view = DebtView((await db.watchDebts().first).single);
      expect(
        (view.item.paidAmount, view.remaining, view.settled),
        (500000, 0, true),
      );

      final txs = await db.getTransactions();
      expect(txs.length, 2);
      expect(txs.every((e) => e.tx.debtId == id), isTrue);
    });

    test(
      'DebtView.remaining bisa negatif kalau overpay, tetap dianggap settled',
      () async {
        final id = await db.addDebt(
          type: DebtType.debt,
          counterpartyName: 'Budi',
          amount: 100000,
        );
        await db.recordDebtPayment(
          debtId: id,
          amount: 150000,
          accountId: 'acc-tunai',
          date: DateTime(2026, 4, 1),
        );
        final view = DebtView((await db.watchDebts().first).single);
        expect((view.remaining, view.settled), (-50000, true));
      },
    );
  });
}
