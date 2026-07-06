import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/capture/gps_gate.dart';
import 'package:fieldchat/features/track/track_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDatabase db;

  setUp(() => db = LocalDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('records as the user moves and skips tiny jitter', () async {
    final recorder = TrackRecorder(db);
    final start = DateTime(2026, 6, 30, 9);

    final first = await recorder.record(
      ownerId: 'me',
      fix: const GpsFix(lat: 27.700, lng: 85.300, accuracyM: 5),
      at: start,
    );
    final jitter = await recorder.record(
      ownerId: 'me',
      fix: const GpsFix(lat: 27.70001, lng: 85.30001, accuracyM: 5),
      at: start.add(const Duration(seconds: 5)),
    );
    final moved = await recorder.record(
      ownerId: 'me',
      fix: const GpsFix(lat: 27.7003, lng: 85.300, accuracyM: 5),
      at: start.add(const Duration(seconds: 10)),
    );

    expect(first, isTrue);
    expect(jitter, isFalse);
    expect(moved, isTrue);

    final trail = await recorder.visibleTrack(
      ownerId: 'me',
      now: start.add(const Duration(minutes: 1)),
    );
    expect(trail.length, 2);
  });

  test('purges points older than 24 hours', () async {
    final recorder = TrackRecorder(db);
    final now = DateTime(2026, 6, 30, 12);

    await db
        .into(db.trackPoints)
        .insert(
          TrackPointsCompanion.insert(
            ownerId: 'me',
            lat: 1,
            lng: 2,
            accuracyM: 5,
            recordedAt: now.subtract(const Duration(hours: 25)),
          ),
        );
    await db
        .into(db.trackPoints)
        .insert(
          TrackPointsCompanion.insert(
            ownerId: 'me',
            lat: 1,
            lng: 2,
            accuracyM: 5,
            recordedAt: now.subtract(const Duration(hours: 1)),
          ),
        );

    final trail = await recorder.visibleTrack(ownerId: 'me', now: now);
    expect(trail.length, 1);
  });
}
