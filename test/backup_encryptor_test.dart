import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:dompet_pintar/features/cloud_backup/backup_encryptor.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _randomKey() =>
    List<int>.generate(32, (_) => Random.secure().nextInt(256));

void main() {
  const encryptor = BackupEncryptor();

  test(
    'round-trip: encrypt lalu decrypt dengan kunci sama kembali persis',
    () async {
      final key = _randomKey();
      const plain = '{"format":"dompet_pintar_backup","version":4}';

      final cipher = await encryptor.encrypt(plain, key);
      final decrypted = await encryptor.decrypt(cipher, key);

      expect(decrypted, plain);
    },
  );

  test('kunci salah gagal decrypt', () async {
    final key = _randomKey();
    final wrongKey = _randomKey();
    final cipher = await encryptor.encrypt('{"a":1}', key);

    expect(
      () => encryptor.decrypt(cipher, wrongKey),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('ciphertext rusak gagal decrypt', () async {
    final key = _randomKey();
    final cipher = await encryptor.encrypt('{"a":1}', key);
    final tampered = List<int>.from(cipher)
      ..[cipher.length - 1] ^= 0xFF; // ubah 1 byte terakhir (bagian MAC)

    expect(
      () => encryptor.decrypt(tampered, key),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  group('varian biner (encryptBytes/decryptBytes, dipakai foto struk)', () {
    test(
      'round-trip: byte sembarang (bukan UTF-8 valid) kembali persis',
      () async {
        final key = _randomKey();
        // Byte 0xFF 0xFE dst. bukan urutan UTF-8 valid — membuktikan varian
        // biner tidak lewat utf8.encode/decode sama sekali (beda dari
        // encrypt/decrypt berbasis String yang akan merusak data seperti ini).
        final plain = List<int>.generate(300, (i) => (i * 37 + 0xFF) % 256);

        final cipher = await encryptor.encryptBytes(plain, key);
        final decrypted = await encryptor.decryptBytes(cipher, key);

        expect(decrypted, plain);
      },
    );

    test('kunci salah gagal decrypt', () async {
      final key = _randomKey();
      final wrongKey = _randomKey();
      final cipher = await encryptor.encryptBytes([1, 2, 3], key);

      expect(
        () => encryptor.decryptBytes(cipher, wrongKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });
}
