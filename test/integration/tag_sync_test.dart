import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/capture/gps_gate.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/message_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A relay that replays the newest envelope to any fresh subscriber, the way a
/// reused realtime channel echoes and races the catch-up cursor read.
class _WarmTransport implements MessageTransport {
  final Map<String, List<Envelope>> _log = {};
  final Map<String, StreamController<Envelope>> _streams = {};
  int _seq = 0;

  @override
  Future<int> publish(Envelope envelope) async {
    final seq = ++_seq;
    final stored = envelope.withSeq(seq);
    _log.putIfAbsent(envelope.groupId, () => []).add(stored);
    _streams[envelope.groupId]?.add(stored);
    return seq;
  }

  @override
  Stream<Envelope> subscribe(String groupId) {
    final controller = _streams.putIfAbsent(
      groupId,
      StreamController<Envelope>.broadcast,
    );
    final log = _log[groupId];
    if (log != null && log.isNotEmpty) {
      final last = log.last;
      scheduleMicrotask(() => controller.add(last));
    }
    return controller.stream;
  }

  @override
  Future<List<Envelope>> fetchSince(String groupId, int afterSeq) async {
    final log = _log[groupId] ?? const [];
    return log.where((e) => e.seq > afterSeq).toList();
  }

  @override
  Future<void> purgeGroup(String groupId) async {
    _log.remove(groupId);
  }

  Future<void> dispose() async {
    for (final controller in _streams.values) {
      await controller.close();
    }
  }
}

/// A relay whose catch-up returns rows newest-first, like supabase-dart's
/// default descending order, to prove sync no longer depends on that order.
class _ReverseTransport implements MessageTransport {
  final Map<String, List<Envelope>> _log = {};
  final Map<String, StreamController<Envelope>> _streams = {};
  int _seq = 0;

  @override
  Future<int> publish(Envelope envelope) async {
    final seq = ++_seq;
    final stored = envelope.withSeq(seq);
    _log.putIfAbsent(envelope.groupId, () => []).add(stored);
    _streams[envelope.groupId]?.add(stored);
    return seq;
  }

  @override
  Stream<Envelope> subscribe(String groupId) => _streams
      .putIfAbsent(groupId, StreamController<Envelope>.broadcast)
      .stream;

  @override
  Future<List<Envelope>> fetchSince(String groupId, int afterSeq) async {
    final log = _log[groupId] ?? const [];
    return log.where((e) => e.seq > afterSeq).toList().reversed.toList();
  }

  @override
  Future<void> purgeGroup(String groupId) async {
    _log.remove(groupId);
  }

  Future<void> dispose() async {
    for (final controller in _streams.values) {
      await controller.close();
    }
  }
}

/// One simulated device: its own store and sync engine on a shared relay.
class _Device {
  _Device(this.userId, MessageTransport transport, InMemoryBlobStore blobs)
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

  test('a rejoin keeps tags and points when a warm channel echoes', () async {
    final transport = _WarmTransport();
    final blobs = InMemoryBlobStore();
    final owner = _Device('owner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Ward',
      identity: await IdentityKeys.generate(),
      hotKeys: const [
        HotKeySpec(label: 'Alpha', colorValue: 0xFF3C7A4E),
        HotKeySpec(label: 'Beta', colorValue: 0xFF3466A0),
      ],
    );
    // A later point raises the newest seq, so a warm echo that wrongly advanced
    // the cursor would push it past the group-meta.
    await owner.sync.sendText(
      groupId: group.id,
      text: 'point',
      geo: const GeoResult.placed(85.3, 27.7),
      senderName: 'owner',
    );

    final rejoined = _Device('owner', transport, blobs);
    addTearDown(rejoined.dispose);
    await rejoined.groups.joinViaLink(
      owner.groups.inviteLinkFor(group),
      await IdentityKeys.generate(),
    );

    await _waitFor(() async {
      final labels = (await rejoined.db.hotKeysFor(group.id))
          .map((t) => t.label)
          .toSet();
      final points = (await rejoined.db.messagesFor(group.id))
          .where((m) => m.lat != null)
          .length;
      return labels.containsAll({'Alpha', 'Beta'}) && points == 1;
    });
  });

  test('the latest edit wins when catch-up returns newest-first', () async {
    final transport = _ReverseTransport();
    final blobs = InMemoryBlobStore();
    final owner = _Device('owner', transport, blobs);
    final joiner = _Device('joiner', transport, blobs);
    addTearDown(() async {
      await owner.dispose();
      await joiner.dispose();
      await transport.dispose();
    });

    final group = await owner.groups.createGroup(
      name: 'Ward',
      identity: await IdentityKeys.generate(),
      hotKeys: const [HotKeySpec(label: 'Old', colorValue: 0xFF15181B)],
    );
    await owner.groups.setMappingArea(
      group.id,
      '{"type":"Feature","geometry":{"type":"Polygon","coordinates":'
      '[[[85.30,27.70],[85.31,27.70],[85.31,27.71],[85.30,27.71],'
      '[85.30,27.70]]]}}',
    );
    await owner.groups.updateHotKeys(group.id, [
      EditableHotKey(label: 'New', colorValue: 0xFF3466A0),
    ]);

    await joiner.groups.joinViaLink(
      owner.groups.inviteLinkFor(group),
      await IdentityKeys.generate(),
    );

    await _waitFor(() async {
      final labels = await _tagLabels(joiner, group.id);
      final g = await joiner.db.groupById(group.id);
      return labels.length == 1 &&
          labels.contains('New') &&
          g?.aoiGeoJson != null;
    });
  });
}
