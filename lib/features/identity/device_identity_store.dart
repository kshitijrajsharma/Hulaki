import 'dart:convert';

import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Loads this device's identity keys, creating them once on first use. The
/// private seeds live in the platform keystore; only the public keys ever leave
/// the device.
class DeviceIdentityStore {
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
}
