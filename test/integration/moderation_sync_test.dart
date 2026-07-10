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

  Future<void> dispose() async {
    await sync.dispose();
    await db.close();
  }
}

Future<_Device> _makeDevice(
  String userId,
  InMemoryTransport transport,
  InMemoryBlobStore blobs, {
  IdentityKeys? identity,
}) async =>
    _Device(
      userId,
      identity ?? await IdentityKeys.generate(),
      transport,
      blobs,
    );

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

  test('moderation settings propagate to a joiner', () async {
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

    await owner.groups.setAllowMemberExport(group.id, value: true);
    await owner.groups.setAllowMemberPlace(group.id, value: false);
    await owner.groups.setAllowOutsideArea(group.id, value: false);
    await owner.groups.setAllowMemberTags(group.id, value: true);
    await owner.groups.setGpsLimit(group.id, 20);

    await _waitFor(() async {
      final g = await joiner.db.groupById(group.id);
      return g != null &&
          g.allowMemberExport &&
          !g.allowMemberPlace &&
          !g.allowOutsideArea &&
          g.allowMemberTags &&
          g.gpsLimitM == 20;
    });
  });

  test("an admin's own tags return after rejoining", () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final owner = await _makeDevice('owner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Ward tags',
      identity: owner.identity,
      hotKeys: const [
        HotKeySpec(label: 'Tree', colorValue: 0xFF3C7A4E, iconName: 'park'),
        HotKeySpec(label: 'Bin', colorValue: 0xFF15181B, iconName: 'delete'),
      ],
    );
    // Let the group-meta reach the relay before the rejoin catches up.
    await _waitFor(() async => (await owner.db.outboxEntries()).isEmpty);

    // The same user reinstalls: a fresh device with the same id rejoins by
    // link. The tags live only in that user's own published meta.
    final rejoined = await _makeDevice(
      'owner',
      transport,
      blobs,
      identity: owner.identity,
    );
    addTearDown(rejoined.dispose);
    await rejoined.groups.joinViaLink(
      owner.groups.inviteLinkFor(group),
      owner.identity,
    );

    await _waitFor(() async {
      final labels = (await rejoined.db.hotKeysFor(group.id))
          .map((t) => t.label)
          .toSet();
      return labels.containsAll({'Tree', 'Bin'});
    });
  });

  test('defaults hold on a fresh group and survive a round-trip', () async {
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
      name: 'Trail audit',
      identity: owner.identity,
      hotKeys: const [],
    );
    final created = await owner.db.groupById(group.id);
    expect(created!.allowMemberExport, isFalse);
    expect(created.allowMemberPlace, isTrue);
    expect(created.allowOutsideArea, isTrue);
    expect(created.gpsLimitM, isNull);

    final link = owner.groups.inviteLinkFor(group);
    await joiner.groups.joinViaLink(link, joiner.identity);

    await _waitFor(() async {
      final g = await joiner.db.groupById(group.id);
      return g != null &&
          !g.allowMemberExport &&
          g.allowMemberPlace &&
          g.allowOutsideArea &&
          g.gpsLimitM == null;
    });
  });

  test('a mapping area set after creation reaches a joiner', () async {
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
      name: 'Ridge survey',
      identity: owner.identity,
      hotKeys: const [],
    );
    expect((await owner.db.groupById(group.id))?.aoiGeoJson, isNull);
    final link = owner.groups.inviteLinkFor(group);
    await joiner.groups.joinViaLink(link, joiner.identity);

    const aoi =
        '{"type":"Feature","geometry":{"type":"Polygon","coordinates":'
        '[[[85.30,27.70],[85.31,27.70],[85.31,27.71],[85.30,27.71],'
        '[85.30,27.70]]]}}';
    await owner.groups.setMappingArea(group.id, aoi);

    await _waitFor(() async {
      final g = await joiner.db.groupById(group.id);
      return g?.aoiGeoJson == aoi;
    });
  });

  test('a cover photo set by the owner reaches a joiner', () async {
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
      name: 'Harbour survey',
      identity: owner.identity,
      hotKeys: const [],
    );
    final link = owner.groups.inviteLinkFor(group);
    await joiner.groups.joinViaLink(link, joiner.identity);

    final photo = Uint8List.fromList(List<int>.generate(64, (i) => i % 256));
    await owner.groups.updateGroupPhoto(group.id, photo);

    await _waitFor(() async {
      final g = await joiner.db.groupById(group.id);
      return g?.photo != null && g!.photo!.length == photo.length;
    });
    final joined = await joiner.db.groupById(group.id);
    expect(joined!.photo, equals(photo));
  });
}
