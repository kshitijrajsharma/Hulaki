import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/message_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// One simulated device: its own store and sync engine on a shared relay.
class _Device {
  _Device(
    this.userId,
    this.identity,
    InMemoryTransport transport,
    InMemoryBlobStore blobs,
  ) : db = LocalDatabase(NativeDatabase.memory()) {
    sync = SyncService(
      db: db,
      transport: transport,
      blobStore: blobs,
      currentUserId: userId,
      identity: () async => identity,
    );
    groups = GroupService(db: db, sync: sync, currentUserId: userId);
  }

  final String userId;
  final IdentityKeys identity;
  final LocalDatabase db;
  late final SyncService sync;
  late final GroupService groups;

  Future<bool> sees(String groupId, String messageId) async =>
      (await db.messagesFor(groupId)).any((m) => m.id == messageId);

  Future<void> dispose() async {
    await sync.dispose();
    await db.close();
  }
}

Future<_Device> _makeDevice(
  String userId,
  InMemoryTransport transport,
  InMemoryBlobStore blobs,
) async =>
    _Device(userId, await IdentityKeys.generate(), transport, blobs);

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

  test('re-joining a left group backfills its history again', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final owner = await _makeDevice('owner', transport, blobs);
    final joiner = await _makeDevice('joiner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await joiner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Riverside cleanup',
      identity: owner.identity,
      hotKeys: const [],
    );
    final link = owner.groups.inviteLinkFor(group);
    final messageId = await owner.sync.sendText(
      groupId: group.id,
      text: 'First observation',
    );

    // First join receives the name and the earlier message.
    await joiner.groups.joinViaLink(link, joiner.identity);
    await _waitFor(() async {
      final g = await joiner.db.groupById(group.id);
      final msgs = await joiner.db.messagesFor(group.id);
      return g?.name == 'Riverside cleanup' &&
          msgs.any((m) => m.id == messageId);
    });
    expect(await joiner.db.cursorFor(group.id), greaterThan(0));

    // The joiner leaves, wiping the group locally.
    await joiner.groups.deleteGroup(group.id);
    expect(await joiner.db.groupById(group.id), isNull);
    expect(await joiner.db.cursorFor(group.id), 0);

    // Re-joining by the same link must backfill the name and history, not
    // resume past them with a stale cursor. The same device keeps its identity.
    await joiner.groups.joinViaLink(link, joiner.identity);
    await _waitFor(() async {
      final g = await joiner.db.groupById(group.id);
      final msgs = await joiner.db.messagesFor(group.id);
      return g?.name == 'Riverside cleanup' &&
          msgs.any((m) => m.id == messageId);
    });
  });

  test('resync heals a hole left below a stale cursor', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final owner = await _makeDevice('owner', transport, blobs);
    final joiner = await _makeDevice('joiner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await joiner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Ward survey',
      identity: owner.identity,
      hotKeys: const [],
    );
    final link = owner.groups.inviteLinkFor(group);
    await joiner.groups.joinViaLink(link, joiner.identity);

    final firstId = await owner.sync.sendText(groupId: group.id, text: 'one');
    final secondId = await owner.sync.sendText(groupId: group.id, text: 'two');
    await _waitFor(() => joiner.sees(group.id, secondId));

    // Simulate the pre-fix corruption: the first message is gone locally, but
    // the cursor stayed above it, so a normal catch-up can never see the hole.
    await (joiner.db.delete(
      joiner.db.messages,
    )..where((m) => m.id.equals(firstId))).go();
    expect(await joiner.sees(group.id, firstId), isFalse);
    await joiner.sync.catchUp(group.id);
    expect(await joiner.sees(group.id, firstId), isFalse);

    // A full resync re-fetches from the start and restores the missing message.
    await joiner.sync.resync(group.id);
    expect(await joiner.sees(group.id, firstId), isTrue);
    expect(await joiner.sees(group.id, secondId), isTrue);
  });

  test('a poison envelope does not wedge catch-up for the group', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final owner = await _makeDevice('owner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Ward survey',
      identity: owner.identity,
      hotKeys: const [],
    );
    final link = owner.groups.inviteLinkFor(group);
    final firstId = await owner.sync.sendText(groupId: group.id, text: 'one');

    // A hostile device inserts undecryptable rows on the open relay: one too
    // short to authenticate, one long-but-garbage that fails the MAC. Before
    // the fix, either would abort catch-up and freeze the group for everyone.
    await transport.publish(
      Envelope(
        groupId: group.id,
        messageId: 'poison-short',
        senderId: 'attacker',
        ciphertext: Uint8List.fromList([1, 2, 3]),
      ),
    );
    await transport.publish(
      Envelope(
        groupId: group.id,
        messageId: 'poison-mac',
        senderId: 'attacker',
        ciphertext: Uint8List.fromList(List.filled(40, 7)),
      ),
    );

    final secondId = await owner.sync.sendText(groupId: group.id, text: 'two');

    // A device joining afterwards catches up across the poison rows and still
    // receives both real messages.
    final joiner = await _makeDevice('joiner', transport, blobs);
    addTearDown(joiner.dispose);
    await joiner.groups.joinViaLink(link, joiner.identity);
    await _waitFor(
      () async =>
          await joiner.sees(group.id, firstId) &&
          await joiner.sees(group.id, secondId),
    );

    // The poison rows were dropped, not stored as messages.
    expect(await joiner.sees(group.id, 'poison-short'), isFalse);
    expect(await joiner.sees(group.id, 'poison-mac'), isFalse);
  });

  test('an admin delete purges server data for later joiners', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final owner = await _makeDevice('owner', transport, blobs);
    final joiner = await _makeDevice('joiner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await joiner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Ward survey',
      identity: owner.identity,
      hotKeys: const [],
    );
    final link = owner.groups.inviteLinkFor(group);
    final messageId = await owner.sync.sendText(
      groupId: group.id,
      text: 'First observation',
    );
    await joiner.groups.joinViaLink(link, joiner.identity);
    await _waitFor(() => joiner.sees(group.id, messageId));

    expect(await transport.fetchSince(group.id, 0), isNotEmpty);
    await owner.groups.deleteGroupForEveryone(group.id);

    // The server holds nothing, and the local copy is gone.
    expect(await transport.fetchSince(group.id, 0), isEmpty);
    expect(await owner.db.groupById(group.id), isNull);

    // A device joining afterwards backfills an empty history.
    final latecomer = await _makeDevice('latecomer', transport, blobs);
    addTearDown(latecomer.dispose);
    await latecomer.groups.joinViaLink(link, latecomer.identity);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await latecomer.db.messagesFor(group.id), isEmpty);
  });
}
