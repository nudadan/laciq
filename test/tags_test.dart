import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:dompet_pintar/data/backup.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Matcher tagError(Matcher msg) =>
      throwsA(isA<TagException>().having((e) => e.message, 'message', msg));

  test('tambah tag baru muncul di daftar, nama dirapikan', () async {
    final id = await db.addTag('  Kantor  ');
    final list = await db.watchTags().first;
    expect(list.single, isA<Tag>().having((t) => t.id, 'id', id));
    expect(list.single.name, 'Kantor');
  });

  test('nama kosong dan terlalu panjang ditolak', () async {
    expect(() => db.addTag('   '), tagError(contains('wajib')));
    expect(() => db.addTag('x' * 41), tagError(contains('maksimal')));
  });

  test('nama kembar ditolak tanpa membedakan huruf besar/kecil', () async {
    await db.addTag('Kantor');
    expect(() => db.addTag('kantor'), tagError(contains('Sudah ada')));
  });

  test('ganti nama tidak bentrok dengan nama sendiri', () async {
    final id = await db.addTag('Kantor');
    await db.renameTag(id, 'kantor'); // beda huruf besar/kecil, tetap boleh
    expect((await db.watchTags().first).single.name, 'kantor');
  });

  test('menandai transaksi dengan beberapa tag dan menggantinya', () async {
    await db.addTransaction(
      type: TxType.expense,
      amount: 20000,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-makan',
      date: DateTime(2026, 9, 5),
    );
    final txId = (await db.getTransactions()).single.tx.id;
    final t1 = await db.addTag('Kantor');
    final t2 = await db.addTag('Liburan');

    await db.setTransactionTags(txId, [t1, t2]);
    expect(
      (await db.watchTagsForTransaction(txId).first).map((t) => t.name),
      containsAll(['Kantor', 'Liburan']),
    );

    await db.setTransactionTags(txId, [t1]);
    final after = await db.watchTagsForTransaction(txId).first;
    expect(after.map((t) => t.name), ['Kantor']);
  });

  test('menghapus tag melepasnya dari semua transaksi', () async {
    await db.addTransaction(
      type: TxType.expense,
      amount: 20000,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-makan',
      date: DateTime(2026, 9, 5),
    );
    final txId = (await db.getTransactions()).single.tx.id;
    final tag = await db.addTag('Kantor');
    await db.setTransactionTags(txId, [tag]);

    await db.deleteTag(tag);

    expect(await db.watchTags().first, isEmpty);
    expect(await db.watchTagsForTransaction(txId).first, isEmpty);
  });

  test('tag dan tautannya ke transaksi ikut backup dan pulih', () async {
    await db.addTransaction(
      type: TxType.expense,
      amount: 20000,
      accountId: 'acc-tunai',
      categoryId: 'cat-exp-makan',
      date: DateTime(2026, 9, 5),
    );
    final txId = (await db.getTransactions()).single.tx.id;
    final tag = await db.addTag('Kantor');
    await db.setTransactionTags(txId, [tag]);
    final json = await BackupService(db).export();

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await BackupService(other).restore(BackupService.parse(json));

    expect((await other.watchTags().first).single.name, 'Kantor');
    expect(
      (await other.watchTagsForTransaction(txId).first).single.name,
      'Kantor',
    );
  });
}
