import '../security/app_lock_service.dart';

/// Kelayakan iklan untuk pengguna tier gratis — murni logika tanggal, tanpa
/// menyentuh plugin iklan sama sekali (lihat `banner_ad_widget.dart`).
class AdEligibilityService {
  AdEligibilityService(this._store, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _now;

  static const _kFirstUse = 'first_use_at';
  static const gracePeriod = Duration(days: 30);

  /// Mencatat waktu pemakaian pertama jika belum ada. Idempoten — aman
  /// dipanggil berulang (pola sama `_generateRecurring`/`_checkBudgetNotifications`
  /// di lib/app.dart).
  Future<void> recordFirstUseIfAbsent() async {
    if (await _store.read(_kFirstUse) == null) {
      await _store.write(_kFirstUse, '${_now().millisecondsSinceEpoch}');
    }
  }

  /// true jika pengguna gratis sudah lewat masa bebas iklan 30 hari. Status
  /// premium (RevenueCat) sengaja TIDAK dicek di sini — dikombinasikan di
  /// level provider (`shouldShowAdsProvider`, lib/data/providers.dart) agar
  /// kelas ini tetap murni dan tidak bergantung pada plugin langganan.
  Future<bool> shouldShowAds() async {
    final ms = int.tryParse(await _store.read(_kFirstUse) ?? '');
    if (ms == null) return false; // belum tercatat -> anggap baru
    final firstUse = DateTime.fromMillisecondsSinceEpoch(ms);
    return _now().difference(firstUse) >= gracePeriod;
  }
}
