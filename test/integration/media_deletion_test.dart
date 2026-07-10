import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('deleting a message removes its media blob from the store', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final identity = await IdentityKeys.generate();
    final db = LocalDatabase(NativeDatabase.memory());
    final sync = SyncService(
      db: db,
      transport: transport,
      blobStore: blobs,
      currentUserId: 'owner',
      identity: () async => identity,
    );
    final groups = GroupService(db: db, sync: sync, currentUserId: 'owner');
    addTearDown(() async {
      await sync.dispose();
      await db.close();
      await transport.dispose();
    });

    final group = await groups.createGroup(
      name: 'Ward survey',
      identity: identity,
      hotKeys: const [],
    );
    final messageId = await sync.sendPhoto(
      groupId: group.id,
      bytes: Uint8List.fromList(List<int>.filled(32, 9)),
    );

    // Once drained, the encrypted blob is on the store keyed by its media id.
    Future<String> mediaIdOf() async => (await db.messagesFor(group.id))
        .firstWhere((m) => m.id == messageId)
        .mediaId!;
    await _waitFor(() async => await blobs.get(await mediaIdOf()) != null);
    final mediaId = await mediaIdOf();

    // Deleting the message drops the blob, so it is no longer downloadable.
    await sync.deleteMessage(messageId);
    expect(await blobs.get(mediaId), isNull);
  });
}
