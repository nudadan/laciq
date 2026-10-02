import 'package:in_app_review/in_app_review.dart';

import '../security/app_lock_service.dart';

/// Menyembunyikan plugin `in_app_review` dari sisa app — pola sama
/// `NotificationSender`/`SubscriptionStatus`, supaya logika kapan meminta
/// ulasan bisa diuji lewat fake tanpa Play Store sungguhan.
abstract interface class ReviewLauncher {
  /// Dialog ulasan bawaan Play (tanpa keluar dari app). False di APK hasil
  /// pasang manual atau perangkat tanpa Play Store.
  Future<bool> isAvailable();
  Future<void> requestReview();

  /// Membuka halaman aplikasi di Play Store (untuk tombol manual di Pengaturan).
  Future<void> openStoreListing();
}

class InAppReviewLauncher implements ReviewLauncher {
  InAppReviewLauncher([InAppReview? review])
    : _review = review ?? InAppReview.instance;
  final InAppReview _review;

  @override
  Future<bool> isAvailable() => _review.isAvailable();
  @override
  Future<void> requestReview() => _review.requestReview();
  @override
  Future<void> openStoreListing() => _review.openStoreListing();
}

/// Kapan meminta ulasan: hanya setelah pengguna terbukti memakai app (banyak
/// transaksi, beberapa hari), jarang, dan tidak pernah di momen negatif.
/// Kebijakan Play melarang imbalan atas ulasan dan memaksa penilaian, jadi
/// dialog ini selalu bisa ditutup dan tidak diberi insentif apa pun.
class ReviewPromptService {
  ReviewPromptService(
    this._store,
    this._launcher, {
    DateTime Function()? clock,
    this.promptDelay = const Duration(seconds: 2),
  }) : _now = clock ?? DateTime.now;

  /// Jeda sebelum dialog Play muncul, supaya transisi layar dan snackbar
  /// "tersimpan" selesai dulu. Tes memakai [Duration.zero].
  final Duration promptDelay;

  final KeyValueStore _store;
  final ReviewLauncher _launcher;
  final DateTime Function() _now;

  static const _kCount = 'review_tx_count';
  static const _kFirstAt = 'review_first_tx_at';
  static const _kLastPromptAt = 'review_last_prompt_at';
  static const _kPromptCount = 'review_prompt_count';

  static const minTransactions = 10;
  static const minDaysSinceFirst = 2;
  static const minDaysBetweenPrompts = 120;
  static const maxPrompts = 3;

  /// Dipanggil setiap pengguna berhasil mencatat transaksi baru (momen
  /// positif). Tidak pernah melempar: kegagalan ulasan tidak boleh
  /// mengganggu pencatatan.
  Future<void> onTransactionSaved() async {
    try {
      final count = (int.tryParse(await _store.read(_kCount) ?? '') ?? 0) + 1;
      await _store.write(_kCount, '$count');
      if (await _store.read(_kFirstAt) == null) {
        await _store.write(_kFirstAt, '${_now().millisecondsSinceEpoch}');
      }
      if (!await _isDue(count)) return;
      if (!await _launcher.isAvailable()) return;
      // Dicatat SEBELUM meminta: Play yang memutuskan tampil atau tidak
      // (kuota), dan kita tidak bisa tahu hasilnya. Mencatat dulu mencegah
      // permintaan berulang bila Play menolak diam-diam.
      await _store.write(_kLastPromptAt, '${_now().millisecondsSinceEpoch}');
      final prompts = int.tryParse(await _store.read(_kPromptCount) ?? '') ?? 0;
      await _store.write(_kPromptCount, '${prompts + 1}');
      await Future<void>.delayed(promptDelay);
      await _launcher.requestReview();
    } catch (_) {
      // Abaikan: ulasan hanya pelengkap.
    }
  }

  Future<bool> _isDue(int count) async {
    if (count < minTransactions) return false;
    final firstMs = int.tryParse(await _store.read(_kFirstAt) ?? '');
    if (firstMs == null) return false;
    final first = DateTime.fromMillisecondsSinceEpoch(firstMs);
    if (_now().difference(first).inDays < minDaysSinceFirst) return false;
    final prompts = int.tryParse(await _store.read(_kPromptCount) ?? '') ?? 0;
    if (prompts >= maxPrompts) return false;
    final lastMs = int.tryParse(await _store.read(_kLastPromptAt) ?? '');
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (_now().difference(last).inDays < minDaysBetweenPrompts) return false;
    }
    return true;
  }

  Future<void> openStoreListing() => _launcher.openStoreListing();
}
