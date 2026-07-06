import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// A device's cryptographic identity: an Ed25519 pair for signing control
/// messages (admin invites, acceptances, join approvals) and an X25519 pair for
/// sealing the group key to an approved joiner. Public keys travel in band; the
/// private keys never leave the device.
class IdentityKeys {
  IdentityKeys._({
    required this.signing,
    required this.agreement,
    required this.signingPublic,
    required this.agreementPublic,
  });

  final SimpleKeyPair signing;
  final SimpleKeyPair agreement;
  final Uint8List signingPublic;
  final Uint8List agreementPublic;

  static final _ed25519 = Ed25519();
  static final _x25519 = X25519();
  static final _aead = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// A fresh identity, both key pairs generated at random.
  static Future<IdentityKeys> generate() async {
    final signing = await _ed25519.newKeyPair();
    final agreement = await _x25519.newKeyPair();
    return IdentityKeys._(
      signing: signing,
      agreement: agreement,
      signingPublic: Uint8List.fromList(
        (await signing.extractPublicKey()).bytes,
      ),
      agreementPublic: Uint8List.fromList(
        (await agreement.extractPublicKey()).bytes,
      ),
    );
  }

  /// Rebuilds an identity from the private seeds persisted on the device.
  static Future<IdentityKeys> fromSeeds({
    required Uint8List signingSeed,
    required Uint8List agreementSeed,
  }) async {
    final signing = await _ed25519.newKeyPairFromSeed(signingSeed);
    final agreement = await _x25519.newKeyPairFromSeed(agreementSeed);
    return IdentityKeys._(
      signing: signing,
      agreement: agreement,
      signingPublic: Uint8List.fromList(
        (await signing.extractPublicKey()).bytes,
      ),
      agreementPublic: Uint8List.fromList(
        (await agreement.extractPublicKey()).bytes,
      ),
    );
  }

  Future<Uint8List> signingSeed() async =>
      Uint8List.fromList(await signing.extractPrivateKeyBytes());

  Future<Uint8List> agreementSeed() async =>
      Uint8List.fromList(await agreement.extractPrivateKeyBytes());

  /// Signs [message] with the Ed25519 key.
  Future<Uint8List> sign(List<int> message) async {
    final signature = await _ed25519.sign(message, keyPair: signing);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verifies an Ed25519 [signature] over [message] against a signer's public
  /// key. Returns false on any mismatch rather than throwing.
  static Future<bool> verify(
    List<int> message, {
    required Uint8List signature,
    required Uint8List signerPublic,
  }) {
    return _ed25519.verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(signerPublic, type: KeyPairType.ed25519),
      ),
    );
  }

  /// Seals [plaintext] to a recipient's X25519 public key using an ephemeral
  /// key, so only the holder of the matching private key can open it. Returns a
  /// self-describing map (ephemeral public key, nonce, ciphertext) as base64.
  static Future<Map<String, String>> seal(
    List<int> plaintext, {
    required Uint8List recipientAgreementPublic,
  }) async {
    final ephemeral = await _x25519.newKeyPair();
    final shared = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: SimplePublicKey(
        recipientAgreementPublic,
        type: KeyPairType.x25519,
      ),
    );
    final wrapKey = await _hkdf.deriveKey(secretKey: shared);
    final box = await _aead.encrypt(plaintext, secretKey: wrapKey);
    return {
      'epk': base64Encode((await ephemeral.extractPublicKey()).bytes),
      'box': base64Encode(box.concatenation()),
    };
  }

  /// Opens a [sealed] box produced by [seal], recovering the plaintext with
  /// this identity's X25519 private key.
  Future<Uint8List> open(Map<String, String> sealed) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: agreement,
      remotePublicKey: SimplePublicKey(
        base64Decode(sealed['epk']!),
        type: KeyPairType.x25519,
      ),
    );
    final wrapKey = await _hkdf.deriveKey(secretKey: shared);
    final box = SecretBox.fromConcatenation(
      base64Decode(sealed['box']!),
      nonceLength: 12,
      macLength: 16,
    );
    final clear = await _aead.decrypt(box, secretKey: wrapKey);
    return Uint8List.fromList(clear);
  }
}
