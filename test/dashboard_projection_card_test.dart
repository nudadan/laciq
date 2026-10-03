import 'package:dompet_pintar/core/money.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'support/harness.dart';

/// 2 hari dari sekarang, DIKLEM supaya tidak pernah melewati akhir jendela
/// simulasi bulan berjalan (`cashFlowProjectionProvider` mengambil rentang
/// [hari ini, awal bulan depan)). Dekat akhir bulan, "+2 hari" polos bisa
/// jatuh ke bulan berikutnya dan keluar dari jendela — ditemukan lewat
/// kegagalan nyata saat tes ini dijalankan tanggal 29 di bulan 30 hari.
DateTime _safeTriggerDate() {
  final now = DateTime.now();
  final windowEnd = DateTime(now.year, now.month + 1); // eksklusif
  final twoDaysOut = DateTime(now.year, now.month, now.day + 2);
  return twoDaysOut.isBefore(windowEnd)
      ? twoDaysOut
      : windowEnd.subtract(const Duration(days: 1));
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest(
    'belum premium: kartu tampil sebagai ajakan upgrade, tap membuka SubscriptionPage',
    (tester, h) async {
      expect(find.text('Proyeksi Bulan Ini'), findsOneWidget);
      expect(find.textContaining('Fitur Premium'), findsWidgets);

      await tester.tap(find.text('Proyeksi Bulan Ini'));
      await settle(tester);

      expect(find.text('LaciQ Premium'), findsOneWidget);
    },
    subscription: FakeSubscriptionStatus(),
  );

  appTest('premium tanpa data Agenda/transaksi berulang: total Rp0', (
    tester,
    h,
  ) async {
    expect(find.text('Proyeksi Bulan Ini'), findsOneWidget);
    expect(find.text(rupiah(0)), findsWidgets); // total + 2 baris rincian
    expect(find.text('Dari Agenda'), findsOneWidget);
    expect(find.text('Dari transaksi berulang'), findsOneWidget);
  }, subscription: FakeSubscriptionStatus(premium: true));

  appTest(
    'premium dengan agenda + transaksi berulang bulan ini: total dan '
    'rincian per sumber benar',
    (tester, h) async {
      // Aturan berulang di-seed mulai BESOK (hari ini langsung dikonsumsi
      // jadi transaksi nyata). Di hari terakhir bulan, besok sudah bulan
      // depan dan di luar proyeksi bulan berjalan, jadi kontribusinya Rp0
      // (perilaku aplikasi yang benar, bukan bug) — ekspektasi mengikuti itu.
      final now = DateTime.now();
      final recurringInMonth =
          now.add(const Duration(days: 1)).month == now.month;
      if (recurringInMonth) {
        expect(find.text(rupiah(800000)), findsOneWidget); // total
        expect(find.text(rupiah(300000)), findsOneWidget); // dari Agenda
        expect(find.text(rupiah(500000)), findsOneWidget); // dari berulang
      } else {
        expect(find.text(rupiah(300000)), findsNWidgets(2)); // total + Agenda
        expect(find.text(rupiah(0)), findsWidgets); // dari berulang
        expect(find.text(rupiah(800000)), findsNothing);
      }
    },
    seed: (db) async {
      await db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: DateTime.now(),
        estimatedAmount: 300000,
      );
      // Bukan `DateTime.now()`: kejadian HARI INI langsung dikonsumsi jadi
      // transaksi nyata oleh generateDueRecurring() (dipanggil app.dart tiap
      // buka app) sebelum providernya sempat menghitung — beda dari Agenda
      // yang murni pengingat (advancePastAgenda tidak memajukan kejadian
      // hari ini, cuma yang benar-benar sudah lewat).
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 500000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-rumah',
        frequency: Frequency.monthly,
        startDate: DateTime.now().add(const Duration(days: 1)),
      );
    },
    subscription: FakeSubscriptionStatus(premium: true),
  );

  appTest(
    'transaksi berulang bertipe pemasukan tidak ikut dihitung ke proyeksi',
    (tester, h) async {
      expect(find.text(rupiah(0)), findsWidgets); // total & rincian tetap 0
    },
    seed: (db) => db.addRecurringRule(
      type: TxType.income,
      amount: 5000000,
      accountId: 'acc-tunai',
      categoryId: 'cat-inc-gaji',
      frequency: Frequency.monthly,
      startDate: DateTime.now().add(const Duration(days: 1)),
    ),
    subscription: FakeSubscriptionStatus(premium: true),
  );

  appTest(
    'agenda tanpa estimasi biaya: tetap tampil di Agenda, kontribusi ke '
    'proyeksi Rp0 (bukan error)',
    (tester, h) async {
      expect(find.text(rupiah(0)), findsWidgets);
    },
    seed: (db) => db.addAgenda(
      title: 'Servis AC',
      frequency: Frequency.monthly,
      startDate: DateTime.now(),
    ),
    subscription: FakeSubscriptionStatus(premium: true),
  );

  appTest(
    'saldo awal cukup menutup proyeksi: status "cukup" tampil',
    (tester, h) async {
      expect(
        find.text('Dana diproyeksikan cukup sepanjang bulan ini'),
        findsOneWidget,
      );
    },
    seed: (db) async {
      await db.addAccount(
        name: 'BCA',
        kind: AccountKind.bank,
        initialBalance: 2000000,
      );
      await db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: DateTime.now(),
        estimatedAmount: 300000,
      );
      await db.addRecurringRule(
        type: TxType.expense,
        amount: 500000,
        accountId: 'acc-tunai',
        categoryId: 'cat-exp-rumah',
        frequency: Frequency.monthly,
        startDate: DateTime.now().add(const Duration(days: 1)),
      );
    },
    subscription: FakeSubscriptionStatus(premium: true),
  );

  appTest(
    'saldo awal tidak cukup: status peringatan tampil dengan nominal dan '
    'tanggal pemicu yang tepat',
    (tester, h) async {
      final trigger = _safeTriggerDate();
      final expected =
          'Berpotensi kurang ${rupiah(400000)} pada '
          '${DateFormat('d MMM', 'id_ID').format(trigger)}';
      expect(find.text(expected), findsOneWidget);
    },
    seed: (db) async {
      await db.addAccount(
        name: 'BCA',
        kind: AccountKind.bank,
        initialBalance: 100000,
      );
      await db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: _safeTriggerDate(),
        estimatedAmount: 500000,
      );
    },
    subscription: FakeSubscriptionStatus(premium: true),
  );

  appTest(
    'pemasukan datang sebelum pengeluaran besar: status tetap "cukup" '
    '(kartu benar-benar simulasi harian, bukan total-vs-saldo statis)',
    (tester, h) async {
      expect(
        find.text('Dana diproyeksikan cukup sepanjang bulan ini'),
        findsOneWidget,
      );
    },
    seed: (db) async {
      await db.addAccount(
        name: 'BCA',
        kind: AccountKind.bank,
        initialBalance: 100000,
      );
      await db.addRecurringRule(
        type: TxType.income,
        amount: 5000000,
        accountId: 'acc-tunai',
        categoryId: 'cat-inc-gaji',
        frequency: Frequency.monthly,
        startDate: DateTime.now().add(const Duration(days: 1)),
      );
      await db.addAgenda(
        title: 'Servis AC',
        frequency: Frequency.monthly,
        startDate: DateTime.now().add(const Duration(days: 3)),
        estimatedAmount: 3000000,
      );
    },
    subscription: FakeSubscriptionStatus(premium: true),
  );
}
