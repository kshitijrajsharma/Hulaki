import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// One simulated device: its own store and sync engine on a shared relay.
class _Device {
  _Device(this.userId, InMemoryTransport transport, InMemoryBlobStore blobs)
    : db = LocalDatabase(NativeDatabase.memory()) {
    sync = SyncService(
      db: db,
      transport: transport,
      blobStore: blobs,
      currentUserId: userId,
    );
    groups = GroupService(db: db, sync: sync, currentUserId: userId);
  }

  final String userId;
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
    final owner = _Device('owner', transport, blobs);
    final joiner = _Device('joiner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await joiner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Riverside cleanup',
      identity: await IdentityKeys.generate(),
      hotKeys: const [],
    );
    final link = owner.groups.inviteLinkFor(group);
    final messageId = await owner.sync.sendText(
      groupId: group.id,
      text: 'First observation',
    );

    // First join receives the name and the earlier message.
    await joiner.groups.joinViaLink(link, await IdentityKeys.generate());
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
    // resume past them with a stale cursor.
    await joiner.groups.joinViaLink(link, await IdentityKeys.generate());
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
    final owner = _Device('owner', transport, blobs);
    final joiner = _Device('joiner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await joiner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Ward survey',
      identity: await IdentityKeys.generate(),
      hotKeys: const [],
    );
    final link = owner.groups.inviteLinkFor(group);
    await joiner.groups.joinViaLink(link, await IdentityKeys.generate());

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

  test('an admin delete purges server data for later joiners', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final owner = _Device('owner', transport, blobs);
    final joiner = _Device('joiner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await joiner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Ward survey',
      identity: await IdentityKeys.generate(),
      hotKeys: const [],
    );
    final link = owner.groups.inviteLinkFor(group);
    final messageId = await owner.sync.sendText(
      groupId: group.id,
      text: 'First observation',
    );
    await joiner.groups.joinViaLink(link, await IdentityKeys.generate());
    await _waitFor(() => joiner.sees(group.id, messageId));

    expect(await transport.fetchSince(group.id, 0), isNotEmpty);
    await owner.groups.deleteGroupForEveryone(group.id);

    // The server holds nothing, and the local copy is gone.
    expect(await transport.fetchSince(group.id, 0), isEmpty);
    expect(await owner.db.groupById(group.id), isNull);

    // A device joining afterwards backfills an empty history.
    final latecomer = _Device('latecomer', transport, blobs);
    addTearDown(latecomer.dispose);
    await latecomer.groups.joinViaLink(link, await IdentityKeys.generate());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await latecomer.db.messagesFor(group.id), isEmpty);
  });
}
