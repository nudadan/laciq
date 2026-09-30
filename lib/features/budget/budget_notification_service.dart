import 'package:intl/intl.dart';

import '../../core/budget_status.dart';
import '../../core/money.dart';
import '../../core/notification_sender.dart';
import '../../data/database.dart';
import '../security/app_lock_service.dart';

/// Notifikasi lokal saat pemakaian kategori mendekati atau melebihi
/// anggaran bulan berjalan. Dicek setiap aplikasi dibuka/kembali dari latar
/// belakang (lihat `_checkBudgetNotifications` di lib/app.dart) — bukan
/// lewat layanan terjadwal, jadi tidak butuh izin alarm atau layanan latar
/// belakang baru.
class BudgetNotificationService {
  BudgetNotificationService(this._store, [NotificationSender? sender])
    : _sender = sender ?? LocalNotificationSender();

  final KeyValueStore _store;
  final NotificationSender _sender;

  /// Membandingkan pemakaian bulan berjalan (bukan bulan yang sedang dilihat
  /// pengguna di tab Anggaran) terhadap anggaran tiap kategori, dan mengirim
  /// notifikasi untuk yang baru menyeberang ambang warning/over — maksimal
  /// sekali per kategori, per bulan, per ambang (dedup lewat [KeyValueStore]).
  Future<void> checkAndNotify(AppDatabase db) async {
    await _sender.init();
    final now = DateTime.now();
    final progress = await db.watchBudgetProgress(now).first;
    for (final p in progress) {
      final budget = p.budget;
      if (budget == null) continue;
      final status = budgetStatusOf(p.spent, budget);
      if (status == BudgetStatus.ok) continue;
      final key = _dedupKey(p.category.id, now, status);
      if (await _store.read(key) != null) continue;
      await _show(p.category.id, p.category.name, status, p.spent, budget);
      await _store.write(key, '1');
    }
  }

  String _dedupKey(String categoryId, DateTime month, BudgetStatus status) =>
      'budget_notified_${categoryId}_'
      '${DateFormat('yyyyMM').format(month)}_${status.name}';

  Future<void> _show(
    String categoryId,
    String categoryName,
    BudgetStatus status,
    int spent,
    int budget,
  ) async {
    final over = status == BudgetStatus.over;
    final title = over
        ? 'Anggaran $categoryName terlampaui'
        : 'Anggaran $categoryName hampir habis';
    final body = over
        ? 'Terpakai ${rupiah(spent)} dari ${rupiah(budget)}.'
        : 'Sudah ${(spent / budget * 100).floor()}% dari ${rupiah(budget)} '
              'terpakai bulan ini.';
    await _sender.show(
      id: Object.hash(categoryId, status).abs() % 2147483647,
      title: title,
      body: body,
    );
  }
}
