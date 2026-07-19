import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/auth/data/device_auth_repository.dart';
import 'package:hulaki/features/identity/device_identity_store.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';
import 'package:hulaki/features/recovery/backup_crypto.dart';
import 'package:hulaki/features/recovery/backup_store.dart';
import 'package:hulaki/features/recovery/recovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rebuilds the identity from seeds in memory, standing in for the platform
/// keystore that a real restore writes to.
class _FakeSeedStore implements IdentitySeedStore {
  IdentityKeys? saved;

  @override
  Future<IdentityKeys> save({
    required List<int> signingSeed,
    required List<int> agreementSeed,
  }) async {
    saved = await IdentityKeys.fromSeeds(
      signingSeed: Uint8List.fromList(signingSeed),
      agreementSeed: Uint8List.fromList(agreementSeed),
    );
    return saved!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  final encKey = base64Encode(List<int>.filled(32, 7));

  test("device B restores the same account from device A's key", () async {
    final store = InMemoryBackupStore();
    final crypto = BackupCrypto();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Device A: an identity and one admin group, then a backup.
    final dbA = LocalDatabase(NativeDatabase.memory());
    final identityA = await IdentityKeys.generate();
    await dbA.upsertProfile(ProfilesCompanion.insert(id: 'user-a', phone: ''));
    await dbA
        .into(dbA.groups)
        .insert(
          GroupsCompanion.insert(
            id: 'g1',
            name: 'Ward 7',
            createdBy: 'user-a',
            encKey: encKey,
          ),
        );
    await dbA
        .into(dbA.groupMembers)
        .insert(
          GroupMembersCompanion.insert(
            groupId: 'g1',
            profileId: 'user-a',
            role: const Value('admin'),
          ),
        );

    final serviceA = RecoveryService(
      crypto: crypto,
      store: store,
      db: dbA,
      auth: DeviceAuthRepository(prefs),
      seedStore: _FakeSeedStore(),
    );
    final key = await serviceA.backUp(
      identity: identityA,
      senderId: 'user-a',
      username: 'ward7',
    );

    // The key is deterministic: backing up again returns the same key, so the
    // store upserts one row rather than orphaning the old one.
    expect(
      await serviceA.backUp(
        identity: identityA,
        senderId: 'user-a',
        username: 'ward7',
      ),
      key,
    );

    // Device B: a fresh install with no identity yet, then a restore.
    final dbB = LocalDatabase(NativeDatabase.memory());
    final seedB = _FakeSeedStore();
    final authB = DeviceAuthRepository(prefs);
    final serviceB = RecoveryService(
      crypto: crypto,
      store: store,
      db: dbB,
      auth: authB,
      seedStore: seedB,
    );

    expect(await dbB.groupById('g1'), isNull);
    final restored = await serviceB.restore(key);

    // Same identity: matching public keys and, since Ed25519 is deterministic,
    // an identical signature over the same message.
    final message = [1, 2, 3, 4];
    expect(restored.signingPublic, identityA.signingPublic);
    expect(restored.agreementPublic, identityA.agreementPublic);
    expect(await restored.sign(message), await identityA.sign(message));

    // Same sender id and username.
    final session = await authB.currentSession();
    expect(session?.userId, 'user-a');
    expect(session?.username, 'ward7');

    // The group is re-attached with its key and this device's admin role.
    expect((await dbB.groupById('g1'))?.encKey, encKey);
    expect(await dbB.groupRoleFor('g1', 'user-a'), 'admin');

    await dbA.close();
    await dbB.close();
  });

  test('restoring with an unknown key throws RecoveryNotFound', () async {
    final crypto = BackupCrypto();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LocalDatabase(NativeDatabase.memory());
    final service = RecoveryService(
      crypto: crypto,
      store: InMemoryBackupStore(),
      db: db,
      auth: DeviceAuthRepository(prefs),
      seedStore: _FakeSeedStore(),
    );

    await expectLater(
      service.restore(await crypto.generateKey()),
      throwsA(isA<RecoveryNotFound>()),
    );
    await db.close();
  });
}
