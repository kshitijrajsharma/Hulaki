import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/export/shared_snapshot.dart';
import 'package:hulaki/features/export/snapshot_publisher.dart';
import 'package:hulaki/features/export/snapshot_store.dart';
import 'package:hulaki/features/sync/group_cipher.dart';
import 'package:image/image.dart' as img;

Future<void> _seed(LocalDatabase db) async {
  await db
      .into(db.groups)
      .insert(
        GroupsCompanion.insert(
          id: 'g1',
          name: 'Ward 7 survey',
          createdBy: 'u1',
          encKey: 'k',
        ),
      );
  await db
      .into(db.hotKeys)
      .insert(
        HotKeysCompanion.insert(
          id: 't1',
          groupId: 'g1',
          label: 'Trash',
          colorValue: 0xFF15181B,
          iconName: const Value('delete'),
        ),
      );

  final png = img.encodePng(img.Image(width: 8, height: 8));
  await db
      .into(db.mediaBlobs)
      .insert(
        MediaBlobsCompanion.insert(
          id: 'm1',
          bytes: Uint8List.fromList(png),
          mime: 'image/png',
        ),
      );

  final base = DateTime.utc(2026, 7, 14, 9);
  await db
      .into(db.messages)
      .insert(
        MessagesCompanion.insert(
          id: 'msg1',
          groupId: 'g1',
          senderId: 'u1',
          kind: 'photo',
          body: const Value('Overflowing bin'),
          tagId: const Value('t1'),
          lat: const Value(27.7),
          lng: const Value(85.3),
          accuracyM: const Value(5),
          mediaId: const Value('m1'),
          createdAt: base,
        ),
      );
  await db
      .into(db.messages)
      .insert(
        MessagesCompanion.insert(
          id: 'msg2',
          groupId: 'g1',
          senderId: 'u1',
          kind: 'text',
          body: const Value('A note'),
          tagId: const Value('t1'),
          lat: const Value(27.71),
          lng: const Value(85.31),
          createdAt: base,
        ),
      );
}

void main() {
  late LocalDatabase db;

  setUp(() => db = LocalDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('builds an enriched snapshot with no author identity', () async {
    await _seed(db);
    final messages = await db.messagesFor('g1');
    final hotKeys = await db.hotKeysFor('g1');

    final snapshot = await buildSharedSnapshot(
      groupName: 'Ward 7 survey',
      messages: messages,
      hotKeys: hotKeys,
      mediaBytes: {'m1': (await db.mediaBytes('m1'))!},
      generatedAt: DateTime.utc(2026, 7, 14, 10),
    );

    expect(snapshot.data['meta'], containsPair('count', 2));

    final legend = snapshot.data['legend'] as List;
    expect(legend, hasLength(1));
    expect(legend.first, containsPair('color', '#15181B'));

    final features =
        (snapshot.data['geojson'] as Map)['features'] as List<dynamic>;
    for (final f in features) {
      final props = (f as Map)['properties'] as Map;
      expect(props.containsKey('sender'), isFalse);
      expect(props.containsKey('anonymous'), isFalse);
    }
    final photoProps = (features.first as Map)['properties'] as Map;
    expect(photoProps['photo'], true);
    expect(photoProps['color'], '#15181B');

    expect(snapshot.photos.keys, contains('msg1'));
    expect(snapshot.photos['msg1']!.length, greaterThan(0));
  });

  test('publishes objects the key decrypts, then revokes them all', () async {
    await _seed(db);
    final store = InMemorySnapshotStore();
    final publisher = SnapshotPublisher(db, store);
    final group = await (db.select(
      db.groups,
    )..where((g) => g.id.equals('g1'))).getSingle();

    final url = await publisher.publish(group, now: DateTime.utc(2026, 7, 14));
    expect(url, contains('view.html?s='));

    final rows = await publisher.snapshotsFor('g1');
    expect(rows, hasLength(1));
    final id = rows.first.id;

    // The data object plus one photo object.
    expect(store.count, 2);
    final cipher = store.read('$id/data');
    expect(cipher, isNotNull);
    expect(store.read('$id/msg1'), isNotNull);

    // Decrypt with the key from the link fragment, as the browser does.
    final fragment = url.split('#').last;
    final key = base64Url.decode(base64.normalize(fragment));
    final clear = await GroupCipher.decryptJson(
      cipher!,
      Uint8List.fromList(key),
    );
    expect((clear['geojson'] as Map)['type'], 'FeatureCollection');

    await publisher.revoke(id);
    expect(await publisher.snapshotsFor('g1'), isEmpty);
    expect(store.count, 0);
  });
}
