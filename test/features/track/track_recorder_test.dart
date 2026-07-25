import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/capture/gps_gate.dart';
import 'package:hulaki/features/track/track_recorder.dart';

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

  test('treats movement within a poor accuracy margin as noise', () async {
    final recorder = TrackRecorder(db);
    final start = DateTime(2026, 6, 30, 9);

    final first = await recorder.record(
      ownerId: 'me',
      fix: const GpsFix(lat: 27.700, lng: 85.300, accuracyM: 20),
      at: start,
    );
    // ~11 m north, inside the 20 m error, so read as jitter and dropped.
    final withinError = await recorder.record(
      ownerId: 'me',
      fix: const GpsFix(lat: 27.70010, lng: 85.300, accuracyM: 20),
      at: start.add(const Duration(seconds: 5)),
    );
    // ~22 m north, clear of the error, so recorded.
    final beyondError = await recorder.record(
      ownerId: 'me',
      fix: const GpsFix(lat: 27.70020, lng: 85.300, accuracyM: 20),
      at: start.add(const Duration(seconds: 10)),
    );

    expect(first, isTrue);
    expect(withinError, isFalse);
    expect(beyondError, isTrue);
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

  test('a longer retention keeps points the default would purge', () async {
    final recorder = TrackRecorder(db, retention: const Duration(days: 2));
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

    final trail = await recorder.visibleTrack(ownerId: 'me', now: now);
    expect(trail.length, 1);
  });
}
