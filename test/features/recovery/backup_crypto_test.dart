import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/features/recovery/backup_crypto.dart';
import 'package:hulaki/features/recovery/backup_store.dart';
import 'package:hulaki/features/recovery/recovery_bundle.dart';

void main() {
  final crypto = BackupCrypto();

  RecoveryBundle sampleBundle() => const RecoveryBundle(
    signingSeed: 'c2lnbmluZw==',
    agreementSeed: 'YWdyZWVtZW50',
    senderId: 'device-1',
    username: 'ward7mapper',
    groups: [
      BackedUpGroup(id: 'g1', encKey: 'a2V5MQ==', role: 'admin'),
      BackedUpGroup(id: 'g2', encKey: 'a2V5Mg==', role: 'member'),
    ],
  );

  test('a fresh key is well formed and validates', () async {
    final key = await crypto.generateKey();
    expect(crypto.isValidKey(key), isTrue);
    expect(crypto.isValidKey('not a key'), isFalse);
    // Lookalike letters are accepted and normalised.
    expect(crypto.isValidKey(key.toLowerCase()), isTrue);
  });

  test('the identity key is deterministic and unique to the seeds', () async {
    final signing = List<int>.filled(32, 1);
    final agreement = List<int>.filled(32, 2);
    final key = await crypto.keyForIdentity(signing, agreement);

    expect(crypto.isValidKey(key), isTrue);
    expect(await crypto.keyForIdentity(signing, agreement), key);
    expect(await crypto.keyForIdentity(agreement, signing), isNot(key));
  });

  test(
    'a bundle round-trips through encrypt and decrypt with its key',
    () async {
      final key = await crypto.generateKey();
      final bundle = sampleBundle();
      final backup = await crypto.encrypt(bundle.toBytes(), key: key);
      final restored = RecoveryBundle.fromBytes(
        await crypto.decrypt(backup, key: key),
      );

      expect(restored.signingSeed, bundle.signingSeed);
      expect(restored.agreementSeed, bundle.agreementSeed);
      expect(restored.senderId, bundle.senderId);
      expect(restored.username, bundle.username);
      expect(restored.groups.map((g) => g.id), ['g1', 'g2']);
      expect(restored.groups.first.encKey, 'a2V5MQ==');
      expect(restored.groups.first.role, 'admin');
    },
  );

  test('the wrong key fails on the authentication tag', () async {
    final backup = await crypto.encrypt(
      sampleBundle().toBytes(),
      key: await crypto.generateKey(),
    );
    await expectLater(
      crypto.decrypt(backup, key: await crypto.generateKey()),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('lookupId is deterministic for a key and matches the backup', () async {
    final key = await crypto.generateKey();
    final backup = await crypto.encrypt(sampleBundle().toBytes(), key: key);
    expect(await crypto.lookupIdFor(key), backup.lookupId);
  });

  test('the store finds a backup by its lookupId', () async {
    final key = await crypto.generateKey();
    final backup = await crypto.encrypt(sampleBundle().toBytes(), key: key);
    final store = InMemoryBackupStore();
    await store.put(backup);

    final found = await store.getByLookupId(await crypto.lookupIdFor(key));
    expect(found, isNotNull);
    final restored = RecoveryBundle.fromBytes(
      await crypto.decrypt(found!, key: key),
    );
    expect(restored.username, 'ward7mapper');
    expect(await store.getByLookupId('missing'), isNull);
  });
}
