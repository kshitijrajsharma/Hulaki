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

  test('moderation settings propagate to a joiner through group-meta', () async {
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

    await owner.groups.setAllowMemberExport(group.id, value: true);
    await owner.groups.setAllowMemberPlace(group.id, value: false);
    await owner.groups.setAllowOutsideArea(group.id, value: false);
    await owner.groups.setGpsLimit(group.id, 20);

    await _waitFor(() async {
      final g = await joiner.db.groupById(group.id);
      return g != null &&
          g.allowMemberExport &&
          !g.allowMemberPlace &&
          !g.allowOutsideArea &&
          g.gpsLimitM == 20;
    });
  });

  test('defaults hold on a fresh group and survive a meta round-trip', () async {
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
      name: 'Trail audit',
      identity: await IdentityKeys.generate(),
      hotKeys: const [],
    );
    final created = await owner.db.groupById(group.id);
    expect(created!.allowMemberExport, isFalse);
    expect(created.allowMemberPlace, isTrue);
    expect(created.allowOutsideArea, isTrue);
    expect(created.gpsLimitM, isNull);

    final link = owner.groups.inviteLinkFor(group);
    await joiner.groups.joinViaLink(link, await IdentityKeys.generate());

    await _waitFor(() async {
      final g = await joiner.db.groupById(group.id);
      return g != null &&
          !g.allowMemberExport &&
          g.allowMemberPlace &&
          g.allowOutsideArea &&
          g.gpsLimitM == null;
    });
  });
}
