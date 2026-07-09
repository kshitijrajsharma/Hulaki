import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/capture/gps_gate.dart';
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
  int tries = 600,
}) async {
  for (var i = 0; i < tries; i++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('condition was not met in time');
}

Future<Set<String>> _tagLabels(_Device device, String groupId) async =>
    (await device.db.hotKeysFor(groupId)).map((t) => t.label).toSet();

Future<void> _waitForLabels(
  _Device device,
  String groupId,
  Set<String> expected,
  String phase, {
  int tries = 600,
}) async {
  var last = <String>{};
  for (var i = 0; i < tries; i++) {
    last = await _tagLabels(device, groupId);
    if (last.length == expected.length && last.containsAll(expected)) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('[$phase] expected $expected but saw $last');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a joiner sees the admin edited tags, not create defaults', () async {
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
      hotKeys: const [
        HotKeySpec(label: 'Trash', colorValue: 0xFF15181B, iconName: 'delete'),
        HotKeySpec(label: 'Crossings', colorValue: 0xFFC0801F),
      ],
    );
    await owner.groups.updateHotKeys(group.id, [
      EditableHotKey(label: 'Graffiti', colorValue: 0xFF6E5DA6),
      EditableHotKey(label: 'Pothole', colorValue: 0xFFB0503D),
    ]);

    await joiner.groups.joinViaLink(
      owner.groups.inviteLinkFor(group),
      await IdentityKeys.generate(),
    );

    await _waitFor(() async {
      final labels = await _tagLabels(joiner, group.id);
      return labels.length == 2 &&
          labels.containsAll({'Graffiti', 'Pothole'});
    });
  });

  test('tags survive a leave, rejoin, edit, then leave and rejoin', () async {
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
      hotKeys: const [HotKeySpec(label: 'One', colorValue: 0xFF15181B)],
    );
    final link = owner.groups.inviteLinkFor(group);

    await joiner.groups.joinViaLink(link, await IdentityKeys.generate());
    await _waitForLabels(joiner, group.id, {'One'}, 'first join');

    await joiner.groups.leaveGroup(group.id);
    expect(await joiner.db.groupById(group.id), isNull);

    await joiner.groups.joinViaLink(link, await IdentityKeys.generate());
    await _waitForLabels(joiner, group.id, {'One'}, 'rejoin restores One');

    await owner.groups.updateHotKeys(group.id, [
      EditableHotKey(label: 'Two', colorValue: 0xFF3466A0),
    ]);
    await _waitForLabels(joiner, group.id, {'Two'}, 'live edit to Two');

    await joiner.groups.leaveGroup(group.id);
    await joiner.groups.joinViaLink(link, await IdentityKeys.generate());
    await _waitForLabels(joiner, group.id, {'Two'}, 'rejoin restores Two');
  });

  test('a located point from the admin reaches a joiner', () async {
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
      name: 'Riverside',
      identity: await IdentityKeys.generate(),
      hotKeys: const [],
    );
    await joiner.groups.joinViaLink(
      owner.groups.inviteLinkFor(group),
      await IdentityKeys.generate(),
    );

    await owner.sync.sendText(
      groupId: group.id,
      text: 'Overflowing bin by the bridge',
      geo: const GeoResult.placed(85.307, 27.695),
      senderName: 'owner',
    );

    await _waitFor(() async {
      final located = (await joiner.db.messagesFor(group.id))
          .where((m) => m.lat != null && m.lng != null)
          .toList();
      return located.length == 1;
    });
  });
}
