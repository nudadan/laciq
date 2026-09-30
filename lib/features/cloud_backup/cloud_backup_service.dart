import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../security/app_lock_service.dart';
import 'backup_encryptor.dart';
import 'cloud_backup_config.dart';

class CloudBackupException implements Exception {
  const CloudBackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pengguna membatalkan sendiri dialog pemilihan akun — bukan kegagalan
/// yang perlu ditampilkan sebagai error (pola sama `SubscriptionCancelled`
/// di fitur langganan).
class CloudBackupCancelled implements Exception {
  const CloudBackupCancelled();
}

/// Menyembunyikan tipe-tipe `google_sign_in`/`googleapis` dari sisa
/// aplikasi — pola sama seperti `SubscriptionStatus` untuk RevenueCat.
abstract interface class CloudBackupService {
  /// Init lazy terjadi di dalam sini SEBELUM yield pertama — jangan baca
  /// [currentEmail] sebelum stream ini pernah emit sekali (lewat provider).
  /// PERHATIAN: pada implementasi nyata ini bisa memicu dialog "Login dengan
  /// Google" yang TERLIHAT pengguna (bukan selalu diam-diam walau namanya
  /// "lightweight") — jangan panggil dari pengecekan pasif yang jalan di
  /// setiap buka app; pakai [cachedSignedIn] untuk itu.
  Stream<bool> watchSignedIn();
  String? get currentEmail;
  Future<void> signIn();
  Future<void> signOut();

  /// Status masuk yang TERAKHIR DIKETAHUI, dibaca lokal (KeyValueStore) TANPA
  /// panggilan jaringan atau dialog akun apa pun — beda dari [watchSignedIn].
  /// Dipakai untuk pengecekan pasif seperti pengingat backup berkala
  /// (`CloudBackupReminderService`) yang tidak boleh mengganggu pengguna di
  /// bagian app yang tidak berhubungan dengan Backup Cloud sama sekali.
  Future<bool> cachedSignedIn();
  Future<DateTime?> lastBackupAt();
  Future<void> uploadBackup(String plainJson);
  Future<String> downloadBackup();

  /// Mengunggah [bytes] (dienkripsi otomatis di dalam, kunci sama dengan
  /// backup utama) ke Drive dengan nama [fileName] — satu file per panggilan,
  /// beda dari [uploadBackup] yang satu blob JSON gabungan. Dipakai untuk foto
  /// struk (fitur Premium, lihat docs/RENCANA-IMPLEMENTASI-OCR-SCAN-STRUK.md).
  Future<void> uploadFile(String fileName, List<int> bytes);

  /// Null kalau file dengan nama itu tidak ada di Drive (mis. belum pernah
  /// di-backup, atau foto sudah dihapus manual dari Drive pengguna).
  Future<List<int>?> downloadFile(String fileName);
}

/// Backup terenkripsi disimpan di folder tersembunyi `appDataFolder` milik
/// pengguna sendiri di Google Drive mereka (pola sama WhatsApp) — dua
/// berkas: `backup.enc` (blob terenkripsi) dan `key.b64` (kunci AES-256
/// mereka). Kami sendiri tidak pernah menyimpan salinan keduanya.
class GoogleDriveCloudBackupService implements CloudBackupService {
  GoogleDriveCloudBackupService(this._store);

  final KeyValueStore _store;
  static bool _initialized = false;

  static const _kCachedKey = 'cloud_backup_key';
  static const _kSignedInFlag = 'cloud_backup_signed_in';
  static const _encryptor = BackupEncryptor();
  static const _keyFileName = 'key.b64';
  static const _backupFileName = 'backup.enc';

  GoogleSignInAccount? _currentUser;

  /// Lazy (dipanggil dari sini, bukan main.dart) — fitur opt-in yang hanya
  /// disentuh dari Pengaturan, sama seperti alasan lazy-init SDK iklan.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: kGoogleServerClientId,
    );
    _initialized = true;
  }

  @override
  Stream<bool> watchSignedIn() async* {
    await _ensureInitialized();
    // Coba masuk diam-diam kalau pengguna sudah pernah mengizinkan
    // sebelumnya, supaya tidak selalu diminta pilih akun ulang tiap buka.
    try {
      _currentUser = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
    } catch (_) {
      _currentUser = null;
    }
    // Simpan status masuk yang terdeteksi di sini juga (bukan cuma dari
    // signIn() eksplisit) — menutup kasus akun Google yang masih tersimpan
    // di OS setelah pasang ulang app, supaya cachedSignedIn() tetap akurat
    // begitu pengguna pernah membuka halaman ini sekali di perangkat baru.
    if (_currentUser != null) await _store.write(_kSignedInFlag, '1');
    yield _currentUser != null;

    yield* GoogleSignIn.instance.authenticationEvents.map((event) {
      _currentUser = switch (event) {
        GoogleSignInAuthenticationEventSignIn(:final user) => user,
        GoogleSignInAuthenticationEventSignOut() => null,
      };
      return _currentUser != null;
    });
  }

  @override
  String? get currentEmail => _currentUser?.email;

  @override
  Future<bool> cachedSignedIn() async =>
      (await _store.read(_kSignedInFlag)) == '1';

  @override
  Future<void> signIn() async {
    await _ensureInitialized();
    try {
      _currentUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const CloudBackupCancelled();
      }
      throw const CloudBackupException(
        'Gagal masuk dengan Google. Periksa koneksi internet Anda.',
      );
    }
    await _store.write(_kSignedInFlag, '1');
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
    _currentUser = null;
    await _store.delete(_kCachedKey);
    await _store.delete(_kSignedInFlag);
  }

  Future<drive.DriveApi> _driveApi() async {
    final user = _currentUser;
    if (user == null) throw const CloudBackupException('Anda belum masuk.');
    final headers = await user.authorizationClient.authorizationHeaders([
      drive.DriveApi.driveAppdataScope,
    ], promptIfNecessary: true);
    if (headers == null) {
      throw const CloudBackupException(
        'Izin akses Google Drive ditolak atau dibatalkan.',
      );
    }
    return drive.DriveApi(_HeaderClient(headers));
  }

  Future<drive.File?> _findFile(drive.DriveApi api, String name) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$name' and trashed=false",
      orderBy: 'createdTime',
      $fields: 'files(id,name,createdTime,modifiedTime)',
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first; // paling lama dibuat — deterministik kalau race.
  }

  @override
  Future<DateTime?> lastBackupAt() async {
    try {
      final api = await _driveApi();
      final file = await _findFile(api, _backupFileName);
      return file?.modifiedTime;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> uploadBackup(String plainJson) async {
    final api = await _driveApi();
    final key = await _getOrCreateKey(api);
    await _uploadEncrypted(
      api,
      key,
      _backupFileName,
      utf8.encode(plainJson),
      errorMessage: 'Gagal mengunggah backup. Periksa koneksi internet Anda.',
    );
  }

  @override
  Future<String> downloadBackup() async {
    final api = await _driveApi();
    final key = await _getOrCreateKey(api);
    final bytes = await _downloadEncrypted(
      api,
      key,
      _backupFileName,
      corruptMessage:
          'Backup tidak bisa dibaca (kunci tidak cocok atau file rusak).',
      errorMessage: 'Gagal mengunduh backup. Periksa koneksi internet Anda.',
    );
    if (bytes == null) {
      throw const CloudBackupException('Belum ada backup cloud tersimpan.');
    }
    return utf8.decode(bytes);
  }

  @override
  Future<void> uploadFile(String fileName, List<int> bytes) async {
    final api = await _driveApi();
    final key = await _getOrCreateKey(api);
    await _uploadEncrypted(
      api,
      key,
      fileName,
      bytes,
      errorMessage:
          'Gagal mengunggah foto struk. Periksa koneksi internet Anda.',
    );
  }

  @override
  Future<List<int>?> downloadFile(String fileName) async {
    final api = await _driveApi();
    final key = await _getOrCreateKey(api);
    return _downloadEncrypted(
      api,
      key,
      fileName,
      corruptMessage:
          'Foto struk tidak bisa dibaca (kunci tidak cocok atau file rusak).',
      errorMessage:
          'Gagal mengunduh foto struk. Periksa koneksi internet Anda.',
    );
  }

  Future<void> _uploadEncrypted(
    drive.DriveApi api,
    List<int> key,
    String fileName,
    List<int> plainBytes, {
    required String errorMessage,
  }) async {
    try {
      final cipherBytes = await _encryptor.encryptBytes(plainBytes, key);
      final media = drive.Media(Stream.value(cipherBytes), cipherBytes.length);
      final existing = await _findFile(api, fileName);
      if (existing != null) {
        await api.files.update(drive.File(), existing.id!, uploadMedia: media);
      } else {
        await api.files.create(
          drive.File(name: fileName, parents: const ['appDataFolder']),
          uploadMedia: media,
        );
      }
    } catch (_) {
      throw CloudBackupException(errorMessage);
    }
  }

  /// Null kalau file [fileName] tidak ada di Drive sama sekali (bukan
  /// dianggap error — pemanggil yang memutuskan artinya, lihat
  /// [downloadFile]/[downloadBackup]).
  Future<List<int>?> _downloadEncrypted(
    drive.DriveApi api,
    List<int> key,
    String fileName, {
    required String corruptMessage,
    required String errorMessage,
  }) async {
    final file = await _findFile(api, fileName);
    if (file == null) return null;
    try {
      final media = await api.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = await _collectBytes(media.stream);
      return await _encryptor.decryptBytes(bytes, key);
    } on SecretBoxAuthenticationError {
      throw CloudBackupException(corruptMessage);
    } catch (e) {
      if (e is CloudBackupException) rethrow;
      throw CloudBackupException(errorMessage);
    }
  }

  /// Mengambil kunci AES pengguna dari cache lokal, atau dari Drive kalau
  /// belum ada cache (mis. HP baru), atau membuat baru kalau ini pertama
  /// kalinya pengguna ini pakai backup cloud sama sekali.
  ///
  /// Drive tidak menegakkan nama berkas unik — kalau dua perangkat
  /// nyaris bersamaan membuat `key.b64`, `_findFile` selalu mengembalikan
  /// yang PALING LAMA dibuat (`orderBy: createdTime`), jadi kedua
  /// perangkat konvergen ke kunci yang sama di pembacaan berikutnya.
  Future<List<int>> _getOrCreateKey(drive.DriveApi api) async {
    final cached = await _store.read(_kCachedKey);
    if (cached != null) return base64Decode(cached);

    final existing = await _findFile(api, _keyFileName);
    if (existing != null) {
      final media = await api.files.get(
        existing.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = await _collectBytes(media.stream);
      return _cacheAndReturn(utf8.decode(bytes));
    }

    final newKeyB64 = base64Encode(_generateKey());
    try {
      await api.files.create(
        drive.File(name: _keyFileName, parents: const ['appDataFolder']),
        uploadMedia: drive.Media(
          Stream.value(utf8.encode(newKeyB64)),
          utf8.encode(newKeyB64).length,
        ),
      );
    } catch (_) {
      throw const CloudBackupException(
        'Gagal menyiapkan kunci backup. Periksa koneksi internet Anda.',
      );
    }
    return _cacheAndReturn(newKeyB64);
  }

  Future<List<int>> _cacheAndReturn(String keyB64) async {
    await _store.write(_kCachedKey, keyB64);
    return base64Decode(keyB64);
  }

  static List<int> _generateKey() =>
      List<int>.generate(32, (_) => Random.secure().nextInt(256));

  static Future<List<int>> _collectBytes(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }
}

/// Menyuntik header otorisasi Google ke tiap request — dibuat sendiri
/// (bukan paket jembatan `extension_google_sign_in_as_googleapis_auth`)
/// karena ada laporan ketidakcocokan paket itu dengan google_sign_in v7.
class _HeaderClient extends http.BaseClient {
  _HeaderClient(this._headers);
  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
