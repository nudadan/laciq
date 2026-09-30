import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/data/goals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('monthlyNeed', () {
    final today = DateTime(2026, 1, 1);

    test('membagi sisa rata ke jumlah bulan, dibulatkan ke atas', () {
      // 1 Jan -> 1 Jul 2026 = 181 hari = 5,95 bulan -> 6 bulan.
      expect(
        monthlyNeed(
          remaining: 6000000,
          deadline: DateTime(2026, 7, 1),
          today: today,
        ),
        1000000,
      );
      expect(
        monthlyNeed(
          remaining: 6000001,
          deadline: DateTime(2026, 7, 1),
          today: today,
        ),
        1000001,
      );
    });

    test('kurang dari sebulan dihitung satu bulan penuh', () {
      expect(
        monthlyNeed(
          remaining: 500000,
          deadline: DateTime(2026, 1, 10),
          today: today,
        ),
        500000,
      );
      expect(
        monthlyNeed(remaining: 500000, deadline: today, today: today),
        500000,
      ); // hari ini
    });

    test('null bila sudah tercapai atau tenggat lewat', () {
      expect(
        monthlyNeed(remaining: 0, deadline: DateTime(2027, 1, 1), today: today),
        isNull,
      );
      expect(
        monthlyNeed(
          remaining: 100,
          deadline: DateTime(2025, 12, 31),
          today: today,
        ),
        isNull,
      );
    });

    test('daysUntil tahan terhadap jam pada tanggal dan pergantian bulan', () {
      expect(
        daysUntil(DateTime(2026, 3, 1, 23, 59), DateTime(2026, 2, 28, 0, 1)),
        1,
      );
      expect(daysUntil(DateTime(2026, 1, 1), DateTime(2026, 1, 2)), -1);
    });
  });

  group('database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Matcher goalError(Matcher msg) =>
        throwsA(isA<GoalException>().having((e) => e.message, 'message', msg));

    Future<String> goal({int target = 1000000, String name = 'Liburan'}) =>
        db.addGoal(name: name, targetAmount: target, icon: 'travel', color: 1);
    Future<GoalView> view(String id) async =>
        (await db.watchGoals().first).firstWhere((g) => g.goal.id == id);
    Future<void> put(String id, int amount) => db.addContribution(
      goalId: id,
      kind: ContributionKind.deposit,
      amount: amount,
    );
    Future<void> take(String id, int amount) => db.addContribution(
      goalId: id,
      kind: ContributionKind.withdrawal,
      amount: amount,
    );

    test('target baru: nama dirapikan, dana 0, belum tercapai', () async {
      final id = await goal(name: '  Dana   Darurat ');
      final v = await view(id);
      expect(v.goal.name, 'Dana Darurat');
      expect(
        (v.saved, v.reached, v.remaining, v.fraction),
        (0, false, 1000000, 0.0),
      );
    });

    test('validasi nama dan nominal target', () async {
      Future<String> add(String n, int t) =>
          db.addGoal(name: n, targetAmount: t, icon: 'x', color: 1);
      expect(() => add('  ', 1), goalError(contains('wajib')));
      expect(() => add('x' * 61, 1), goalError(contains('maksimal')));
      expect(() => add('A', 0), goalError(contains('lebih dari 0')));
      expect(
        () => add('A', AppDatabase.maxGoalTarget + 1),
        goalError(contains('terlalu besar')),
      );
    });

    test('dana = setoran - penarikan; progres, sisa, dan tercapai', () async {
      final id = await goal(target: 1000000);
      await put(id, 600000);
      await take(id, 100000);
      var v = await view(id);
      expect((v.saved, v.remaining, v.reached), (500000, 500000, false));
      expect(v.fraction, 0.5);

      await put(id, 700000); // 1.200.000 > target
      v = await view(id);
      expect(
        (v.saved, v.remaining, v.reached, v.fraction),
        (1200000, 0, true, 1.0),
      );
    });

    test('penarikan tidak boleh melebihi dana terkumpul', () async {
      final id = await goal();
      expect(() => take(id, 1), goalError(contains('Belum ada dana')));
      await put(id, 200000);
      expect(() => take(id, 200001), goalError(contains('hanya')));
      await take(id, 200000); // pas: boleh, jadi 0
      expect((await view(id)).saved, 0);
    });

    test('nominal tidak valid ditolak', () async {
      final id = await goal();
      expect(() => put(id, 0), goalError(contains('lebih dari 0')));
      expect(() => put(id, -5), goalError(contains('lebih dari 0')));
    });

    test('tidak memengaruhi saldo dompet, laporan, maupun anggaran', () async {
      final id = await goal();
      await put(id, 400000);
      expect((await db.watchAccountBalances().first).single.balance, 0);
      final t = await db.watchTotals(DateTime.now()).first;
      expect((t.income, t.expense), (0, 0));
      expect(await db.getTransactions(), isEmpty);
    });

    test('hapus & pulihkan setoran (soft delete) memperbarui dana', () async {
      final id = await goal();
      await put(id, 300000);
      final c = (await db.watchContributions(id).first).single;
      await db.setContributionDeleted(c.id, deleted: true);
      expect((await view(id)).saved, 0);
      expect(await db.watchContributions(id).first, isEmpty);
      await db.setContributionDeleted(c.id, deleted: false);
      expect((await view(id)).saved, 300000);
      await db.setContributionDeleted(c.id, deleted: false); // idempoten
      expect((await view(id)).saved, 300000);
    });

    test('menghapus setoran yang sudah sebagian ditarik ditolak', () async {
      final id = await goal();
      await put(id, 300000);
      await take(id, 200000);
      final deposit = (await db.watchContributions(id).first).firstWhere(
        (c) => c.kind == ContributionKind.deposit,
      );
      expect(
        () => db.setContributionDeleted(deposit.id, deleted: true),
        goalError(contains('negatif')),
      );
      expect((await view(id)).saved, 100000); // tidak berubah
    });

    test('menghapus penarikan lalu menghapus setoran diperbolehkan', () async {
      final id = await goal();
      await put(id, 300000);
      await take(id, 200000);
      final list = await db.watchContributions(id).first;
      final withdrawal = list.firstWhere(
        (c) => c.kind == ContributionKind.withdrawal,
      );
      final deposit = list.firstWhere(
        (c) => c.kind == ContributionKind.deposit,
      );
      await db.setContributionDeleted(withdrawal.id, deleted: true);
      await db.setContributionDeleted(deposit.id, deleted: true);
      expect((await view(id)).saved, 0);
    });

    test('memulihkan penarikan yang membuat dana negatif ditolak', () async {
      final id = await goal();
      await put(id, 100000);
      await take(id, 100000);
      final withdrawal = (await db.watchContributions(id).first).firstWhere(
        (c) => c.kind == ContributionKind.withdrawal,
      );
      await db.setContributionDeleted(
        withdrawal.id,
        deleted: true,
      ); // dana 100rb
      final deposit = (await db.watchContributions(id).first).single;
      await db.setContributionDeleted(deposit.id, deleted: true); // dana 0
      expect(
        () => db.setContributionDeleted(withdrawal.id, deleted: false),
        goalError(contains('negatif')),
      );
    });

    test('ubah target: nilai baru, progres dihitung ulang', () async {
      final id = await goal(target: 1000000);
      await put(id, 500000);
      await db.updateGoal(
        id: id,
        name: 'Liburan Bali',
        targetAmount: 400000, // di bawah dana terkumpul: langsung tercapai
        icon: 'travel',
        color: 2,
        deadline: DateTime(2026, 12, 31, 15),
      );
      final v = await view(id);
      expect(
        (v.goal.name, v.target, v.reached),
        ('Liburan Bali', 400000, true),
      );
      expect(v.goal.deadline, DateTime(2026, 12, 31)); // hanya tanggal
      expect(v.saved, 500000);
    });

    test(
      'arsip: tidak bisa diubah danaya, tetap terlihat di urutan bawah',
      () async {
        final a = await goal(name: 'A');
        await goal(name: 'B');
        await db.setGoalArchived(a, archived: true);
        final list = await db.watchGoals().first;
        expect(list.map((g) => g.goal.name), ['B', 'A']);
        expect(() => put(a, 1000), goalError(contains('diarsipkan')));
        await db.setGoalArchived(a, archived: false);
        await put(a, 1000);
        expect((await view(a)).saved, 1000);
      },
    );

    test(
      'hapus target menghapus seluruh setoran/penarikannya, target lain aman',
      () async {
        final a = await goal(name: 'A');
        final b = await goal(name: 'B');
        await put(a, 1000);
        await put(b, 2000);
        await db.deleteGoal(a);
        final list = await db.watchGoals().first;
        expect(list.map((g) => g.goal.name), ['B']);
        expect(list.single.saved, 2000);
        expect(await db.watchContributions(a).first, isEmpty);
      },
    );

    test('id tidak ada melempar error', () async {
      expect(
        () => db.setGoalArchived('nope', archived: true),
        throwsStateError,
      );
      expect(
        () => db.addContribution(
          goalId: 'nope',
          kind: ContributionKind.deposit,
          amount: 1,
        ),
        throwsStateError,
      );
    });
  });

  group('backup', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<Map<String, dynamic>> seeded() async {
      final id = await db.addGoal(
        name: 'Motor',
        targetAmount: 20000000,
        icon: 'car',
        color: 5,
        deadline: DateTime(2027, 6, 1),
      );
      await db.addContribution(
        goalId: id,
        kind: ContributionKind.deposit,
        amount: 3000000,
      );
      await db.addContribution(
        goalId: id,
        kind: ContributionKind.withdrawal,
        amount: 500000,
        note: 'darurat',
      );
      return jsonDecode(await BackupService(db).export())
          as Map<String, dynamic>;
    }

    test('target dan setoran ikut backup dan pulih utuh', () async {
      final json = jsonEncode(await seeded());
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).restore(BackupService.parse(json));

      final g = (await other.watchGoals().first).single;
      expect(
        (g.goal.name, g.target, g.saved, g.goal.deadline),
        ('Motor', 20000000, 2500000, DateTime(2027, 6, 1)),
      );
      final list = await other.watchContributions(g.goal.id).first;
      expect(list.map((c) => c.note), contains('darurat'));
    });

    test('backup versi 1 dan 2 (tanpa target) masih bisa dipulihkan', () async {
      final map = await seeded()
        ..['version'] = 2
        ..remove('savingsGoals')
        ..remove('goalContributions');
      final data = BackupService.parse(jsonEncode(map));
      expect(data.savingsGoals, isEmpty);
      await BackupService(db).restore(data);
      expect(await db.watchGoals().first, isEmpty); // target lama tergantikan
    });

    test(
      'file yang diakali ditolak: setoran tanpa target, dana negatif, ID ganda',
      () async {
        final base = await seeded();
        Map<String, dynamic> clone() =>
            jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        void rejects(Map<String, dynamic> m) => expect(
          () => BackupService.parse(jsonEncode(m)),
          throwsA(isA<BackupException>()),
        );

        final orphan = clone();
        ((orphan['goalContributions'] as List).first as Map)['goalId'] =
            'hilang';
        rejects(orphan);

        final negative = clone(); // hanya penarikan, tanpa setoran
        (negative['goalContributions'] as List).removeWhere(
          (c) => (c as Map)['kind'] == ContributionKind.deposit.index,
        );
        rejects(negative);

        final dup = clone();
        (dup['savingsGoals'] as List).add((dup['savingsGoals'] as List).first);
        rejects(dup);

        final badTarget = clone();
        ((badTarget['savingsGoals'] as List).first as Map)['targetAmount'] = 0;
        rejects(badTarget);
      },
    );
  });
}
