import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/auth/data/auth_repository.dart';
import 'package:hulaki/features/identity/device_identity_store.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';
import 'package:hulaki/features/recovery/backup_crypto.dart';
import 'package:hulaki/features/recovery/backup_store.dart';
import 'package:hulaki/features/recovery/recovery_bundle.dart';

/// Raised when no backup exists for the supplied recovery key.
class RecoveryNotFound implements Exception {
  const RecoveryNotFound();

  @override
  String toString() => 'No backup found for this recovery key';
}

/// Backs up and restores an account. A backup captures the identity seeds, the
/// sender id and username, and every group key, envelope-encrypted so the store
/// only ever holds ciphertext. A restore rebuilds all of it on a fresh install.
class RecoveryService {
  RecoveryService({
    required this.crypto,
    required this.store,
    required this.db,
    required this.auth,
    required this.seedStore,
  });

  final BackupCrypto crypto;
  final BackupStore store;
  final LocalDatabase db;
  final AuthRepository auth;
  final IdentitySeedStore seedStore;

  /// Assembles and uploads a backup, returning the recovery key to show the
  /// user once. The key is never stored.
  Future<String> backUp({
    required IdentityKeys identity,
    required String senderId,
    required String username,
  }) async {
    final bundle = RecoveryBundle(
      signingSeed: base64Encode(await identity.signingSeed()),
      agreementSeed: base64Encode(await identity.agreementSeed()),
      senderId: senderId,
      username: username,
      groups: await _groups(senderId),
    );
    final key = await crypto.keyForIdentity(
      await identity.signingSeed(),
      await identity.agreementSeed(),
    );
    await store.put(await crypto.encrypt(bundle.toBytes(), key: key));
    return key;
  }

  Future<List<BackedUpGroup>> _groups(String userId) async {
    final result = <BackedUpGroup>[];
    for (final group in await db.activeGroups()) {
      result.add(
        BackedUpGroup(
          id: group.id,
          encKey: group.encKey,
          role: await db.groupRoleFor(group.id, userId) ?? 'member',
        ),
      );
    }
    return result;
  }

  /// Restores an account from its recovery key: rebuilds the identity, the
  /// sender id and username, and re-attaches every group. Returns the identity.
  Future<IdentityKeys> restore(String key) async {
    final backup = await store.getByLookupId(await crypto.lookupIdFor(key));
    if (backup == null) throw const RecoveryNotFound();
    final bundle = RecoveryBundle.fromBytes(
      await crypto.decrypt(backup, key: key),
    );
    final identity = await seedStore.save(
      signingSeed: base64Decode(bundle.signingSeed),
      agreementSeed: base64Decode(bundle.agreementSeed),
    );
    await auth.restoreSession(
      userId: bundle.senderId,
      username: bundle.username,
    );
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(id: bundle.senderId, phone: ''),
          mode: InsertMode.insertOrIgnore,
        );
    for (final group in bundle.groups) {
      await _reattach(group, bundle.senderId);
    }
    return identity;
  }

  // Re-inserts a group and this device's membership from the backup. Names,
  // roster, and roles then re-sync from the server once the app reconnects.
  Future<void> _reattach(BackedUpGroup group, String senderId) async {
    await db
        .into(db.groups)
        .insert(
          GroupsCompanion.insert(
            id: group.id,
            name: '',
            createdBy: '',
            encKey: group.encKey,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.groupMembers)
        .insert(
          GroupMembersCompanion.insert(
            groupId: group.id,
            profileId: senderId,
            role: Value(group.role),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
