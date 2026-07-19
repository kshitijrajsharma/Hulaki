import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';

/// Writes the identity seeds when restoring an account from a recovery bundle.
/// A seam so restore can run against a fake without the platform keystore.
// ignore: one_member_abstracts
abstract interface class IdentitySeedStore {
  Future<IdentityKeys> save({
    required List<int> signingSeed,
    required List<int> agreementSeed,
  });
}

/// Loads this device's identity keys, creating them once on first use. The
/// private seeds live in the platform keystore; only the public keys ever leave
/// the device.
class DeviceIdentityStore implements IdentitySeedStore {
  DeviceIdentityStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _signingSeedKey = 'identity.signingSeed';
  static const _agreementSeedKey = 'identity.agreementSeed';

  Future<IdentityKeys> loadOrCreate() async {
    final signingSeed = await _storage.read(key: _signingSeedKey);
    final agreementSeed = await _storage.read(key: _agreementSeedKey);
    if (signingSeed != null && agreementSeed != null) {
      return IdentityKeys.fromSeeds(
        signingSeed: base64Decode(signingSeed),
        agreementSeed: base64Decode(agreementSeed),
      );
    }
    final keys = await IdentityKeys.generate();
    await _storage.write(
      key: _signingSeedKey,
      value: base64Encode(await keys.signingSeed()),
    );
    await _storage.write(
      key: _agreementSeedKey,
      value: base64Encode(await keys.agreementSeed()),
    );
    return keys;
  }

  @override
  Future<IdentityKeys> save({
    required List<int> signingSeed,
    required List<int> agreementSeed,
  }) async {
    await _storage.write(
      key: _signingSeedKey,
      value: base64Encode(signingSeed),
    );
    await _storage.write(
      key: _agreementSeedKey,
      value: base64Encode(agreementSeed),
    );
    return IdentityKeys.fromSeeds(
      signingSeed: Uint8List.fromList(signingSeed),
      agreementSeed: Uint8List.fromList(agreementSeed),
    );
  }
}
