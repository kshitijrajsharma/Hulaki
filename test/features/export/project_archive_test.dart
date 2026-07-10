import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/capture/gps_gate.dart';
import 'package:fieldchat/features/export/project_archive.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('project zip bundles media, geojson, manifest and readme', () async {
    final db = LocalDatabase(NativeDatabase.memory());
    final identity = await IdentityKeys.generate();
    final sync = SyncService(
      db: db,
      transport: InMemoryTransport(),
      blobStore: InMemoryBlobStore(),
      currentUserId: 'you',
      identity: () async => identity,
    );
    final groups = GroupService(db: db, sync: sync, currentUserId: 'you');
    addTearDown(() async {
      await sync.dispose();
      await db.close();
    });

    final group = await groups.createGroup(
      name: 'Ward 7 · Litter survey',
      identity: identity,
      hotKeys: const [HotKeySpec(label: 'Trash', colorValue: 0xFF15181B)],
    );
    final trash = (await db.hotKeysFor(group.id)).first.id;

    final photo = Uint8List.fromList(List.generate(2048, (i) => i % 256));
    final photoId = await sync.sendPhoto(
      groupId: group.id,
      bytes: photo,
      caption: 'Overflowing bin',
      tagId: trash,
      geo: GeoResult.fix(const GpsFix(lat: 27.705, lng: 85.305, accuracyM: 6)),
    );

    final messages = await db.messagesFor(group.id);
    final mediaId = messages.firstWhere((m) => m.id == photoId).mediaId!;

    final zipBytes = await buildProjectArchive(
      group: group,
      hotKeys: await db.hotKeysFor(group.id),
      messages: messages,
      mediaResolver: db.mediaBytes,
      exportedAt: DateTime.utc(2026, 6, 30, 10),
    );

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, contains('data.geojson'));
    expect(names, contains('project.json'));
    expect(names, contains('README.txt'));
    expect(names, contains('media/$mediaId.jpg'));

    // The bundled photo is byte-identical to the original.
    final bundled = archive.files.firstWhere(
      (f) => f.name == 'media/$mediaId.jpg',
    );
    expect(bundled.content as List<int>, equals(photo));

    // The GeoJSON points at the bundled media by relative path.
    final geojsonFile = archive.files.firstWhere(
      (f) => f.name == 'data.geojson',
    );
    final geojson =
        jsonDecode(utf8.decode(geojsonFile.content as List<int>))
            as Map<String, dynamic>;
    final feature = (geojson['features'] as List).first as Map<String, dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;
    expect(properties['media'], 'media/$mediaId.jpg');
    expect(properties['text'], 'Overflowing bin');

    // The manifest counts the point and the media file.
    final manifestFile = archive.files.firstWhere(
      (f) => f.name == 'project.json',
    );
    final manifest =
        jsonDecode(utf8.decode(manifestFile.content as List<int>))
            as Map<String, dynamic>;
    expect((manifest['counts'] as Map)['points'], 1);
    expect((manifest['counts'] as Map)['media'], 1);
  });

  test('project zip bundles the track as GPX when one is recorded', () async {
    final db = LocalDatabase(NativeDatabase.memory());
    final identity = await IdentityKeys.generate();
    final sync = SyncService(
      db: db,
      transport: InMemoryTransport(),
      blobStore: InMemoryBlobStore(),
      currentUserId: 'you',
      identity: () async => identity,
    );
    final groups = GroupService(db: db, sync: sync, currentUserId: 'you');
    addTearDown(() async {
      await sync.dispose();
      await db.close();
    });

    final group = await groups.createGroup(
      name: 'Ward 7 · Litter survey',
      identity: identity,
      hotKeys: const [HotKeySpec(label: 'Trash', colorValue: 0xFF15181B)],
    );

    final base = DateTime.utc(2026, 6, 30, 9);
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.trackPoints)
          .insert(
            TrackPointsCompanion.insert(
              ownerId: 'you',
              lat: 27.705 + i * 0.0005,
              lng: 85.305 + i * 0.0005,
              accuracyM: 5,
              recordedAt: base.add(Duration(minutes: i)),
            ),
          );
    }
    final track = await db.trackSince(
      'you',
      base.subtract(const Duration(hours: 1)),
    );

    final zipBytes = await buildProjectArchive(
      group: group,
      hotKeys: await db.hotKeysFor(group.id),
      messages: await db.messagesFor(group.id),
      mediaResolver: db.mediaBytes,
      track: track,
      exportedAt: DateTime.utc(2026, 6, 30, 10),
    );

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, contains('track.gpx'));

    final gpx = utf8.decode(
      archive.files.firstWhere((f) => f.name == 'track.gpx').content
          as List<int>,
    );
    expect(gpx, contains('<trkpt'));
    expect(gpx, contains('lat="27.705"'));

    final manifest =
        jsonDecode(
              utf8.decode(
                archive.files
                        .firstWhere((f) => f.name == 'project.json')
                        .content
                    as List<int>,
              ),
            )
            as Map<String, dynamic>;
    expect((manifest['files'] as Map)['track'], 'track.gpx');
  });
}
