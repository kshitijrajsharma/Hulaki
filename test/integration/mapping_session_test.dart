import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/capture/gps_gate.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:fieldchat/features/export/gpx.dart';
import 'package:fieldchat/features/export/project_archive.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:fieldchat/features/track/track_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// One simulated member: their own device store and sync engine, all talking
/// through the shared transport and blob store (the stand-in server).
class Client {
  Client(this.userId, MessageTransportBundle server)
    : db = LocalDatabase(NativeDatabase.memory()) {
    sync = SyncService(
      db: db,
      transport: server.transport,
      blobStore: server.blobStore,
      currentUserId: userId,
    );
    groups = GroupService(db: db, sync: sync, currentUserId: userId);
  }

  final String userId;
  final LocalDatabase db;
  late final SyncService sync;
  late final GroupService groups;

  Future<List<Message>> visible(String groupId) => db.messagesFor(groupId);
  Future<bool> sees(String groupId, String id) async =>
      (await visible(groupId)).any((m) => m.id == id);

  Future<void> dispose() async {
    await sync.dispose();
    await db.close();
  }
}

class MessageTransportBundle {
  MessageTransportBundle(this.transport, this.blobStore);
  final InMemoryTransport transport;
  final InMemoryBlobStore blobStore;
}

Future<void> waitFor(
  Future<bool> Function() condition, {
  int tries = 400,
}) async {
  for (var i = 0; i < tries; i++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('condition was not met in time');
}

const _aoiGeoJson =
    '{"type":"Feature","properties":{},"geometry":{"type":"Polygon",'
    '"coordinates":[[[85.300,27.700],[85.310,27.700],[85.310,27.710],'
    '[85.300,27.710],[85.300,27.700]]]}}';

void main() {
  // Three simulated members run as three databases in one process by design.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a full mapping session across three members', () async {
    final server = MessageTransportBundle(
      InMemoryTransport(),
      InMemoryBlobStore(),
    );
    final you = Client('you', server);
    final asha = Client('asha', server);
    final tomas = Client('tomas', server);
    addTearDown(() async {
      await you.dispose();
      await asha.dispose();
      await tomas.dispose();
      await server.transport.dispose();
    });

    // 1. Create a group with hot-keys and a drawn AOI.
    final group = await you.groups.createGroup(
      name: 'Ward 7 · Litter survey',
      identity: await IdentityKeys.generate(),
      aoiGeoJson: _aoiGeoJson,
      hotKeys: const [
        HotKeySpec(label: 'Trash', colorValue: 0xFF15181B),
        HotKeySpec(label: 'Crossings', colorValue: 0xFFE0922A),
        HotKeySpec(label: 'Streetlight', colorValue: 0xFF7B6FC4),
        HotKeySpec(label: 'Pole', colorValue: 0xFFC4615E),
      ],
    );
    expect(aoiBounds(group.aoiGeoJson), [85.300, 27.700, 85.310, 27.710]);

    // 2. Others join by invite link and receive the metadata + hot-keys + AOI.
    final link = you.groups.inviteLinkFor(group);
    await asha.groups.joinViaLink(link, await IdentityKeys.generate());
    await tomas.groups.joinViaLink(link, await IdentityKeys.generate());
    await waitFor(
      () async =>
          (await asha.db.groupById(group.id))?.name == group.name &&
          (await tomas.db.groupById(group.id))?.name == group.name,
    );
    final hotKeys = await asha.db.hotKeysFor(group.id);
    expect(hotKeys.map((h) => h.label), [
      'Trash',
      'Crossings',
      'Streetlight',
      'Pole',
    ]);
    expect(
      aoiBounds((await tomas.db.groupById(group.id))!.aoiGeoJson),
      isNotNull,
    );
    final trash = hotKeys.firstWhere((h) => h.label == 'Trash').id;
    final pole = hotKeys.firstWhere((h) => h.label == 'Pole').id;

    // 3. Asha sends a photo, tagged + captioned, with GPS that improves
    //    12m -> 6m through the gate. Others see it live and can open the media.
    const gate = GpsGate(maxWait: Duration(seconds: 1));
    final geo = await gate.acquire(
      Stream.fromIterable(const [
        GpsFix(lat: 27.7050, lng: 85.3050, accuracyM: 12),
        GpsFix(lat: 27.7051, lng: 85.3051, accuracyM: 6),
      ]),
    );
    final photo = Uint8List.fromList(List.generate(4096, (i) => i % 256));
    final photoId = await asha.sync.sendPhoto(
      groupId: group.id,
      bytes: photo,
      caption: 'Overflowing bin near gate',
      tagId: trash,
      geo: geo,
    );
    await waitFor(() => you.sees(group.id, photoId));

    final received = (await you.visible(
      group.id,
    )).firstWhere((m) => m.id == photoId);
    expect(received.body, 'Overflowing bin near gate');
    expect(received.tagId, trash);
    expect(received.accuracyM, 6);
    expect(received.lat, isNotNull);
    expect(await you.db.mediaBytes(received.mediaId!), equals(photo));

    // 4. Tomas replies to Asha's photo with his own photo + text.
    final replyId = await tomas.sync.sendPhoto(
      groupId: group.id,
      bytes: Uint8List.fromList([10, 20, 30, 40]),
      caption: 'Same bin from the road',
      tagId: trash,
      geo: GeoResult.fix(
        const GpsFix(lat: 27.7052, lng: 85.3052, accuracyM: 7),
      ),
      replyToId: photoId,
    );
    await waitFor(() => you.sees(group.id, replyId));
    expect(
      (await you.visible(
        group.id,
      )).firstWhere((m) => m.id == replyId).replyToId,
      photoId,
    );

    // 5. Weak GPS that never improves keeps the first (coarse) fix.
    final weak = await gate.acquire(
      Stream.fromIterable(const [
        GpsFix(lat: 27.706, lng: 85.306, accuracyM: 18),
      ]),
    );
    expect(weak.accuracyM, 18);
    final poleId = await tomas.sync.sendText(
      groupId: group.id,
      text: 'Leaning pole on the corner',
      tagId: pole,
      geo: weak,
    );
    await waitFor(() => you.sees(group.id, poleId));

    // 6. You go offline, capture two points, and they queue. Others do not see
    //    them. On reconnect they sync and everyone converges.
    await you.sync.setOnline(value: false);
    final off1 = await you.sync.sendText(
      groupId: group.id,
      text: 'Bin near the bus stop',
      tagId: trash,
      geo: GeoResult.fix(const GpsFix(lat: 27.707, lng: 85.307, accuracyM: 5)),
    );
    final off2 = await you.sync.sendPhoto(
      groupId: group.id,
      bytes: Uint8List.fromList([1, 1, 2, 3, 5, 8]),
      caption: 'Pile by the wall',
      tagId: trash,
      geo: GeoResult.fix(const GpsFix(lat: 27.708, lng: 85.308, accuracyM: 7)),
    );
    expect(await you.sees(group.id, off1), isTrue); // visible locally at once
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(await asha.sees(group.id, off1), isFalse); // not sent yet

    await you.sync.setOnline(value: true);
    await waitFor(
      () async =>
          await asha.sees(group.id, off1) && await asha.sees(group.id, off2),
    );

    // 7. A capture with no GPS fix is sent as location-pending.
    final pendingGeo = await gate.acquire(const Stream<GpsFix>.empty());
    expect(pendingGeo.pending, isTrue);
    final pendingId = await you.sync.sendText(
      groupId: group.id,
      text: 'Saw something, GPS was down',
      tagId: trash,
      geo: pendingGeo,
    );
    await waitFor(() => asha.sees(group.id, pendingId));
    final pendingRow = (await asha.visible(
      group.id,
    )).firstWhere((m) => m.id == pendingId);
    expect(pendingRow.locationPending, isTrue);
    expect(pendingRow.lat, isNull);

    // 8. Edit and delete propagate to everyone.
    await asha.sync.editMessage(
      messageId: photoId,
      newBody: 'Overflowing bin (now cleared)',
    );
    await waitFor(() async {
      final m = (await you.visible(
        group.id,
      )).firstWhere((m) => m.id == photoId);
      return m.body == 'Overflowing bin (now cleared)' && m.editedAt != null;
    });
    await you.sync.deleteMessage(off1);
    await waitFor(() async => !await asha.sees(group.id, off1));

    // 8b. Editing hot-keys (dropping one) prunes it on every member, and the
    //     group name survives a metadata update that changes only the hot-keys.
    final kept = (await you.db.hotKeysFor(group.id))
        .where((h) => h.label != 'Streetlight')
        .map(
          (h) => EditableHotKey(
            id: h.id,
            label: h.label,
            colorValue: h.colorValue,
          ),
        )
        .toList();
    await you.groups.updateHotKeys(group.id, kept);
    await waitFor(() async {
      final labels = (await asha.db.hotKeysFor(group.id)).map((h) => h.label);
      return !labels.contains('Streetlight') && labels.contains('Trash');
    });
    expect((await asha.db.groupById(group.id))?.name, group.name);

    // 9. Your 24-hour track records the walk accurately.
    final recorder = TrackRecorder(you.db);
    final base = DateTime(2026, 6, 30, 9);
    final walk = [27.7050, 27.7052, 27.7054, 27.7056, 27.7058];
    for (var i = 0; i < walk.length; i++) {
      await recorder.record(
        ownerId: 'you',
        fix: GpsFix(lat: walk[i], lng: 85.3050, accuracyM: 5),
        at: base.add(Duration(seconds: i * 10)),
      );
    }
    final trail = await recorder.visibleTrack(
      ownerId: 'you',
      now: base.add(const Duration(minutes: 1)),
    );
    expect(trail.length, walk.length);

    // 10. Everyone converges on the same visible messages.
    for (final client in [you, asha, tomas]) {
      await client.sync.catchUp(group.id);
    }
    Future<Set<String>> idsFor(Client c) async =>
        (await c.visible(group.id)).map((m) => m.id).toSet();
    final yourIds = await idsFor(you);
    expect(await idsFor(asha), yourIds);
    expect(await idsFor(tomas), yourIds);
    expect(yourIds.contains(off1), isFalse); // deleted for everyone

    // 11. Export to GeoJSON and GPX, and write the artifacts for review.
    final messages = await you.visible(group.id);
    final groupHotKeys = await you.db.hotKeysFor(group.id);
    final featureCollection = buildFeatureCollection(messages, groupHotKeys);
    final located = messages
        .where((m) => m.lat != null && m.deletedAt == null)
        .length;
    expect((featureCollection['features'] as List).length, located);

    final gpx = buildGpx(
      name: group.name,
      messages: messages,
      hotKeys: groupHotKeys,
      track: trail,
    );
    final doc = XmlDocument.parse(gpx);
    expect(doc.findAllElements('wpt').length, located);
    expect(doc.findAllElements('trkpt').length, walk.length);

    // 12. Project bundle: a .zip with the geojson, area, track and media.
    final projectZip = await buildProjectArchive(
      group: group,
      hotKeys: groupHotKeys,
      messages: messages,
      mediaResolver: you.db.mediaBytes,
      track: trail,
      exportedAt: DateTime.utc(2026, 6, 30, 10),
    );
    final bundle = ZipDecoder().decodeBytes(projectZip);
    expect(
      bundle.files.where((f) => f.name.startsWith('media/')).length,
      greaterThan(0),
    );

    final outDir = Directory('${Directory.current.path}/.prep/exports')
      ..createSync(recursive: true);
    File(
      '${outDir.path}/ward7_litter.geojson',
    ).writeAsStringSync(featureCollectionToString(featureCollection));
    File('${outDir.path}/ward7_litter.gpx').writeAsStringSync(gpx);
    File(
      '${outDir.path}/ward7_litter_project.zip',
    ).writeAsBytesSync(projectZip);
  });
}
