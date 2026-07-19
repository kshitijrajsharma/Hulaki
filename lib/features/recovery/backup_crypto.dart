import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// The stored, encrypted form of a recovery bundle. The server only ever holds
/// this: opaque ciphertext plus the data key wrapped to an unlock key. A
/// passkey wrap is added on top later without changing the format. [lookupId]
/// comes from the recovery key so a fresh install finds its own row without an
/// account; it is unguessable without the key.
class EncryptedBackup {
  const EncryptedBackup({
    required this.lookupId,
    required this.ciphertext,
    required this.keyWrappedKey,
  });

  factory EncryptedBackup.fromJson(Map<String, dynamic> json) =>
      EncryptedBackup(
        lookupId: json['lookupId'] as String,
        ciphertext: json['ciphertext'] as String,
        keyWrappedKey: json['keyWrappedKey'] as String,
      );

  final String lookupId;
  final String ciphertext;
  final String keyWrappedKey;

  Map<String, dynamic> toJson() => {
    'lookupId': lookupId,
    'ciphertext': ciphertext,
    'keyWrappedKey': keyWrappedKey,
  };
}

/// Envelope encryption for the recovery bundle. A random data key encrypts the
/// bundle, and that data key is wrapped with a key derived from a 256-bit
/// recovery key the user saves. The recovery key is shown as grouped Crockford
/// base32 (no lookalike letters). A wrong key fails loud on the AES-GCM tag, so
/// correctness needs no separate checksum.
class BackupCrypto {
  static final _aead = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // Crockford base32: the ambiguous letters I, L, O and U are absent.
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const _keyChars = 52; // 256 bits in base32.

  /// A fresh 256-bit recovery key, grouped in fours for the user to save.
  Future<String> generateKey() async {
    final bytes = await (await _aead.newSecretKey()).extractBytes();
    return _group(_encode(bytes));
  }

  /// The recovery key for an identity: a deterministic 256-bit key derived from
  /// the device seeds, so the same account always yields the same key and one
  /// server row. One-way, so the key never discloses the seeds.
  Future<String> keyForIdentity(
    List<int> signingSeed,
    List<int> agreementSeed,
  ) async {
    final bytes = await _derive(
      [...signingSeed, ...agreementSeed],
      'recovery-key/v1',
    );
    return _group(_encode(bytes));
  }

  /// True when [key] is well formed. Whether it is the right key is proven only
  /// by a successful decrypt.
  bool isValidKey(String key) {
    final normalized = _normalize(key);
    return normalized.length == _keyChars && _decode(normalized) != null;
  }

  Future<String> lookupIdFor(String key) async =>
      base64Encode(await _derive(_keyBytes(key), 'lookup'));

  Future<EncryptedBackup> encrypt(
    List<int> bundle, {
    required String key,
  }) async {
    final seed = _keyBytes(key);
    final kek = SecretKey(await _derive(seed, 'kek'));
    final dek = await _aead.newSecretKey();
    final ciphertext = await _aead.encrypt(bundle, secretKey: dek);
    final wrapped = await _aead.encrypt(
      await dek.extractBytes(),
      secretKey: kek,
    );
    return EncryptedBackup(
      lookupId: base64Encode(await _derive(seed, 'lookup')),
      ciphertext: base64Encode(ciphertext.concatenation()),
      keyWrappedKey: base64Encode(wrapped.concatenation()),
    );
  }

  Future<List<int>> decrypt(
    EncryptedBackup backup, {
    required String key,
  }) async {
    final kek = SecretKey(await _derive(_keyBytes(key), 'kek'));
    final dekBytes = await _aead.decrypt(
      _read(backup.keyWrappedKey),
      secretKey: kek,
    );
    return _aead.decrypt(
      _read(backup.ciphertext),
      secretKey: SecretKey(dekBytes),
    );
  }

  List<int> _keyBytes(String key) {
    final bytes = _decode(_normalize(key));
    if (bytes == null || bytes.length < 32) {
      throw const FormatException('Malformed recovery key');
    }
    return bytes.sublist(0, 32);
  }

  Future<List<int>> _derive(List<int> seed, String info) async =>
      (await _hkdf.deriveKey(
        secretKey: SecretKey(seed),
        info: utf8.encode(info),
      )).extractBytes();

  SecretBox _read(String concatenation) => SecretBox.fromConcatenation(
    base64Decode(concatenation),
    nonceLength: 12,
    macLength: 16,
  );

  String _normalize(String key) => key
      .toUpperCase()
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[^0-9A-Z]'), '');

  String _group(String raw) {
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) out.write('-');
      out.write(raw[i]);
    }
    return out.toString();
  }

  String _encode(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(_alphabet[(buffer >> bits) & 31]);
      }
    }
    if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return out.toString();
  }

  List<int>? _decode(String encoded) {
    final bytes = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final char in encoded.split('')) {
      final value = _alphabet.indexOf(char);
      if (value < 0) return null;
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        bytes.add((buffer >> bits) & 0xff);
      }
    }
    return bytes;
  }
}
