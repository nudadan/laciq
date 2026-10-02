import '../security/app_lock_service.dart';

/// Pilihan pengguna untuk Backup Cloud yang bukan soal jadwal pengingat.
class CloudBackupOptions {
  CloudBackupOptions(this._store);

  final KeyValueStore _store;

  static const _kIncludePhotos = 'backup_include_receipt_photos';

  /// Apakah foto struk ikut diunggah ke Drive pengguna dan diunduh saat
  /// memulihkan. Default AKTIF supaya perilaku pengguna lama tidak berubah
  /// diam-diam (foto selama ini sudah ikut); hanya '0' yang mematikannya.
  Future<bool> includePhotos() async =>
      (await _store.read(_kIncludePhotos)) != '0';

  Future<void> setIncludePhotos(bool v) =>
      _store.write(_kIncludePhotos, v ? '1' : '0');
}
