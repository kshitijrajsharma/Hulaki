import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Authenticated encryption for group content. Each group holds one static
/// symmetric key for its whole life, shared out of band through the invite link
/// and never sent to the server. The transport and blob store only ever see the
/// output here.
///
/// There is no forward secrecy or key rotation here: the Signal sender-key
/// ratchet that would add them is a future drop-in behind these same call
/// sites, not yet wired in. Authorship instead comes from the per-envelope
/// Ed25519 signature applied in the sync service.
class GroupCipher {
  GroupCipher._();

  static final AesGcm _algorithm = AesGcm.with256bits();
  static const int _macLength = 16;

  /// A fresh 256-bit group key.
  static Future<Uint8List> generateKey() async {
    final key = await _algorithm.newSecretKey();
    return Uint8List.fromList(await key.extractBytes());
  }

  static Future<Uint8List> encryptBytes(
    List<int> plaintext,
    Uint8List key,
  ) async {
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(box.concatenation());
  }

  static Future<Uint8List> decryptBytes(
    Uint8List combined,
    Uint8List key,
  ) async {
    // Reject a too-short blob as malformed input rather than letting the
    // library throw an ArgumentError, so callers handling untrusted ciphertext
    // catch one Exception type.
    if (combined.length < _algorithm.nonceLength + _macLength) {
      throw const FormatException('ciphertext too short to authenticate');
    }
    final box = SecretBox.fromConcatenation(
      combined,
      nonceLength: _algorithm.nonceLength,
      macLength: _macLength,
    );
    final clear = await _algorithm.decrypt(box, secretKey: SecretKey(key));
    return Uint8List.fromList(clear);
  }

  static Future<Uint8List> encryptJson(
    Map<String, dynamic> json,
    Uint8List key,
  ) => encryptBytes(utf8.encode(jsonEncode(json)), key);

  static Future<Map<String, dynamic>> decryptJson(
    Uint8List combined,
    Uint8List key,
  ) async {
    final clear = await decryptBytes(combined, key);
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }
}
