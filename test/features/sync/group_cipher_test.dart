import 'dart:typed_data';

import 'package:fieldchat/features/sync/group_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a JSON payload', () async {
    final key = await GroupCipher.generateKey();
    final payload = {'id': 'm1', 'body': 'Overflowing bin', 'accuracyM': 6};

    final cipher = await GroupCipher.encryptJson(payload, key);
    final clear = await GroupCipher.decryptJson(cipher, key);

    expect(clear, equals(payload));
  });

  test('a wrong key cannot decrypt', () async {
    final key = await GroupCipher.generateKey();
    final other = await GroupCipher.generateKey();
    final cipher = await GroupCipher.encryptJson(const {'x': 1}, key);

    expect(
      () => GroupCipher.decryptJson(cipher, other),
      throwsA(isA<Object>()),
    );
  });

  test('tampered ciphertext is rejected', () async {
    final key = await GroupCipher.generateKey();
    final cipher = await GroupCipher.encryptBytes(
      Uint8List.fromList([1, 2, 3, 4, 5]),
      key,
    );
    cipher[cipher.length - 1] ^= 0xFF;

    expect(
      () => GroupCipher.decryptBytes(cipher, key),
      throwsA(isA<Object>()),
    );
  });
}
