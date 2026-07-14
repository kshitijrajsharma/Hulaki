import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/export/shared_snapshot.dart';
import 'package:image/image.dart' as img;

/// Load test: a thousand-point snapshot must stay a small download, since the
/// points live in one JSON object and photos are fetched separately.
void main() {
  test('1000 points build to a small snapshot', () async {
    final db = LocalDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db
        .into(db.groups)
        .insert(
          GroupsCompanion.insert(
            id: 'g',
            name: 'City-wide survey',
            createdBy: 'u',
            encKey: 'k',
          ),
        );
    const tags = [
      ('t1', 'Trash', 0xFF15181B, 'delete'),
      ('t2', 'Crossings', 0xFFE0922A, 'crossing'),
      ('t3', 'Streetlight', 0xFF7B6FC4, 'streetlight'),
      ('t4', 'Pole', 0xFFC4615E, 'bolt'),
    ];
    for (final (id, label, color, icon) in tags) {
      await db
          .into(db.hotKeys)
          .insert(
            HotKeysCompanion.insert(
              id: id,
              groupId: 'g',
              label: label,
              colorValue: color,
              iconName: Value(icon),
            ),
          );
    }

    final photo = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 16, height: 16)),
    );
    const photoCount = 120;
    await db.batch((batch) {
      for (var i = 0; i < 1000; i++) {
        final hasPhoto = i < photoCount;
        if (hasPhoto) {
          batch.insert(
            db.mediaBlobs,
            MediaBlobsCompanion.insert(
              id: 'm$i',
              bytes: photo,
              mime: 'image/jpeg',
            ),
          );
        }
        batch.insert(
          db.messages,
          MessagesCompanion.insert(
            id: 'p$i',
            groupId: 'g',
            senderId: 'u',
            kind: hasPhoto ? 'photo' : 'text',
            body: Value('Observation number $i on the route'),
            tagId: Value(tags[i % tags.length].$1),
            lat: Value(27.70 + (i % 100) * 0.001),
            lng: Value(85.30 + (i ~/ 100) * 0.001),
            accuracyM: const Value(5),
            mediaId: hasPhoto ? Value('m$i') : const Value.absent(),
            createdAt: DateTime.utc(2026, 7, 14),
          ),
        );
      }
    });

    final stopwatch = Stopwatch()..start();
    final snapshot = await buildSharedSnapshot(
      groupName: 'City-wide survey',
      messages: await db.messagesFor('g'),
      hotKeys: await db.hotKeysFor('g'),
      mediaBytes: {
        for (var i = 0; i < photoCount; i++)
          'm$i': (await db.mediaBytes('m$i'))!,
      },
      generatedAt: DateTime.utc(2026, 7, 14),
    );
    stopwatch.stop();

    final dataBytes = snapshotToBytes(snapshot.data).length;
    final features = (snapshot.data['geojson'] as Map)['features'] as List;
    final kb = (dataBytes / 1024).toStringAsFixed(0);
    // Surface the measured size and timing in the test run log.
    // ignore: avoid_print
    print(
      'Snapshot: ${features.length} points, data $kb KB, '
      '${snapshot.photos.length} photos, '
      'built in ${stopwatch.elapsedMilliseconds} ms',
    );

    expect(features, hasLength(1000));
    // The download the viewer pulls first stays well under a megabyte.
    expect(dataBytes, lessThan(400 * 1024));
    // Photos are separate objects, not inlined into the JSON.
    expect(
      utf8.decode(snapshotToBytes(snapshot.data)),
      isNot(contains('base64')),
    );
  });
}
