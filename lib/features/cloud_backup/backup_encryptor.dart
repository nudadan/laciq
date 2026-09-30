import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Enkripsi/dekripsi AES-256-GCM untuk blob backup sebelum diunggah ke
/// Supabase Storage. Murni Dart (paket `cryptography`, bukan plugin native)
/// — tidak ada dependensi jaringan/plugin, aman dites langsung tanpa fake.
class BackupEncryptor {
  const BackupEncryptor();

  static final _algo = AesGcm.with256bits();

  Future<List<int>> encrypt(String plainJson, List<int> keyBytes) =>
      encryptBytes(utf8.encode(plainJson), keyBytes);

  /// Melempar [SecretBoxAuthenticationError] kalau kunci salah atau
  /// ciphertext rusak/dimanipulasi.
  Future<String> decrypt(List<int> cipherBytes, List<int> keyBytes) async =>
      utf8.decode(await decryptBytes(cipherBytes, keyBytes));

  /// Varian biner — dipakai untuk foto struk (fitur Premium), yang tidak
  /// boleh lewat `utf8.encode` seperti JSON (bisa merusak data biner
  /// sembarang). [encrypt]/[decrypt] di atas kini murni pembungkus tipis.
  Future<List<int>> encryptBytes(
    List<int> plainBytes,
    List<int> keyBytes,
  ) async {
    final box = await _algo.encrypt(plainBytes, secretKey: SecretKey(keyBytes));
    return box.concatenation(nonce: true, mac: true);
  }

  Future<List<int>> decryptBytes(
    List<int> cipherBytes,
    List<int> keyBytes,
  ) async {
    final box = SecretBox.fromConcatenation(
      cipherBytes,
      nonceLength: _algo.nonceLength,
      macLength: _algo.macAlgorithm.macLength,
    );
    return _algo.decrypt(box, secretKey: SecretKey(keyBytes));
  }
}
