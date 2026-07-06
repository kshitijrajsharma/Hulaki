@Tags(['perf'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:flutter_test/flutter_test.dart';

/// Load test: a group holding many points must query and render fast. Run with
/// `flutter test --tags perf test/performance/load_test.dart`.
void main() {
  late LocalDatabase db;

  setUp(() => db = LocalDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(int count) async {
    await db
        .into(db.groups)
        .insert(
          GroupsCompanion.insert(
            id: 'g',
            name: 'Load',
            createdBy: 'u',
            encKey: 'k',
          ),
        );
    await db
        .into(db.hotKeys)
        .insert(
          HotKeysCompanion.insert(
            id: 'hk',
            groupId: 'g',
            label: 'Trash',
            colorValue: 0xFF15181B,
          ),
        );
    await db.batch((b) {
      for (var i = 0; i < count; i++) {
        b.insert(
          db.messages,
          MessagesCompanion.insert(
            id: 'm$i',
            groupId: 'g',
            senderId: 'u',
            kind: 'text',
            tagId: const Value('hk'),
            lat: Value(27.70 + i * 0.0001),
            lng: Value(85.30 + i * 0.0001),
            accuracyM: const Value(5),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + i),
          ),
        );
      }
    });
  }

  test('1000 points query and build a feature collection quickly', () async {
    await seed(1000);
    final hotKeys = await db.hotKeysFor('g');

    final queryWatch = Stopwatch()..start();
    final messages = await db.messagesFor('g');
    queryWatch.stop();

    final buildWatch = Stopwatch()..start();
    final collection = buildFeatureCollection(messages, hotKeys);
    buildWatch.stop();

    expect(messages.length, 1000);
    expect((collection['features'] as List).length, 1000);
    // Generous ceilings; these run in a few ms in practice.
    expect(queryWatch.elapsedMilliseconds, lessThan(500));
    expect(buildWatch.elapsedMilliseconds, lessThan(500));

    // Surface the numbers in the test output.
    // Surface the measured timing in the test log.
    // ignore: avoid_print
    print(
      'load: query ${queryWatch.elapsedMilliseconds}ms, '
      'build ${buildWatch.elapsedMilliseconds}ms for 1000 points',
    );
  });

  test('latest-message preview stays fast with a large group', () async {
    await seed(1000);
    final watch = Stopwatch()..start();
    final latest = await db.latestMessage('g');
    watch.stop();
    expect(latest, isNotNull);
    expect(watch.elapsedMilliseconds, lessThan(100));
    // Surface the measured timing in the test log.
    // ignore: avoid_print
    print('load: latestMessage ${watch.elapsedMilliseconds}ms over 1000 rows');
  });
}
