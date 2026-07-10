import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/messaging/domain/message_payload.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/group_cipher.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/message_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Device = ({
  LocalDatabase db,
  SyncService sync,
  GroupService groups,
  IdentityKeys identity,
});

Future<_Device> _makeDevice(
  String userId,
  InMemoryTransport transport,
  InMemoryBlobStore blobs,
) async {
  final identity = await IdentityKeys.generate();
  final db = LocalDatabase(NativeDatabase.memory());
  final sync = SyncService(
    db: db,
    transport: transport,
    blobStore: blobs,
    currentUserId: userId,
    identity: () async => identity,
  );
  final groups = GroupService(db: db, sync: sync, currentUserId: userId);
  return (db: db, sync: sync, groups: groups, identity: identity);
}

Future<void> _waitFor(
  Future<bool> Function() condition, {
  int tries = 400,
}) async {
  for (var i = 0; i < tries; i++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('condition was not met in time');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a forged or unsigned envelope is rejected on ingest', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final owner = await _makeDevice('owner', transport, blobs);
    final joiner = await _makeDevice('joiner', transport, blobs);
    addTearDown(() async {
      await owner.sync.dispose();
      await owner.db.close();
      await joiner.sync.dispose();
      await joiner.db.close();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Ward survey',
      identity: owner.identity,
      hotKeys: const [],
    );
    final link = owner.groups.inviteLinkFor(group);
    final realId = await owner.sync.sendText(
      groupId: group.id,
      text: 'real observation',
    );

    // A holder of the group key can encrypt, but not forge authorship.
    final key = base64Decode((await owner.db.groupById(group.id))!.encKey);

    // Forge a message as the owner, signed with a different key than the one
    // the owner announced. The signature will not match on ingest.
    final attacker = await IdentityKeys.generate();
    final forged = MessagePayload(
      id: 'forged-1',
      groupId: group.id,
      senderId: 'owner',
      kind: MessageKind.text,
      createdAtMs: 1000,
      body: 'forged as owner',
    );
    final forgedJson = forged.toJson()
      ..['sig'] = base64Encode(await attacker.sign(forged.bytesToSign()));
    await transport.publish(
      Envelope(
        groupId: group.id,
        messageId: 'forged-1',
        senderId: 'owner',
        ciphertext: await GroupCipher.encryptJson(forgedJson, key),
      ),
    );

    // Inject an unsigned message from a non-member.
    final unsigned = MessagePayload(
      id: 'unsigned-1',
      groupId: group.id,
      senderId: 'intruder',
      kind: MessageKind.text,
      createdAtMs: 1001,
      body: 'unsigned inject',
    );
    await transport.publish(
      Envelope(
        groupId: group.id,
        messageId: 'unsigned-1',
        senderId: 'intruder',
        ciphertext: await GroupCipher.encryptJson(unsigned.toJson(), key),
      ),
    );

    // The joiner catches up: it applies the owner's real, signed message and
    // rejects both the forgery and the unsigned injection.
    await joiner.groups.joinViaLink(link, joiner.identity);
    await _waitFor(
      () async =>
          (await joiner.db.messagesFor(group.id)).any((m) => m.id == realId),
    );
    final ids = (await joiner.db.messagesFor(group.id)).map((m) => m.id);
    expect(ids, contains(realId));
    expect(ids, isNot(contains('forged-1')));
    expect(ids, isNot(contains('unsigned-1')));
  });
}
