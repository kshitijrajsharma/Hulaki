import 'dart:async';

import 'package:fieldchat/features/capture/gps_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gate = GpsGate(maxWait: Duration(seconds: 2));

  test('commits the better fix when accuracy improves', () async {
    final result = await gate.acquire(
      Stream.fromIterable(const [
        GpsFix(lat: 27.700, lng: 85.300, accuracyM: 12),
        GpsFix(lat: 27.7001, lng: 85.3001, accuracyM: 5),
      ]),
    );
    expect(result.pending, isFalse);
    expect(result.accuracyM, 5);
  });

  test('a placed point is located but carries no accuracy', () {
    const result = GeoResult.placed(27.7051, 85.3051);
    expect(result.pending, isFalse);
    expect(result.lat, 27.7051);
    expect(result.lng, 85.3051);
    expect(result.accuracyM, isNull);
    expect(result.altitudeM, isNull);
    expect(result.headingDeg, isNull);
  });

  test('a fix carries altitude and heading through GeoResult', () {
    final result = GeoResult.fix(
      const GpsFix(
        lat: 27.7,
        lng: 85.3,
        accuracyM: 6,
        altitudeM: 1320,
        headingDeg: 47,
      ),
    );
    expect(result.altitudeM, 1320);
    expect(result.headingDeg, 47);
  });

  test('keeps the first fix when nothing reaches the target', () async {
    final result = await gate.acquire(
      Stream.fromIterable(const [GpsFix(lat: 1, lng: 2, accuracyM: 20)]),
    );
    expect(result.accuracyM, 20);
    expect(result.pending, isFalse);
  });

  test('picks the best of several when none reach the target', () async {
    final result = await gate.acquire(
      Stream.fromIterable(const [
        GpsFix(lat: 1, lng: 2, accuracyM: 20),
        GpsFix(lat: 1, lng: 2, accuracyM: 14),
      ]),
    );
    expect(result.accuracyM, 14);
  });

  test('returns pending when no fix arrives', () async {
    final result = await gate.acquire(const Stream<GpsFix>.empty());
    expect(result.pending, isTrue);
    expect(result.lat, isNull);
  });

  test('caps the wait and commits the best fix so far', () async {
    const fast = GpsGate(
      targetAccuracyM: 1,
      maxWait: Duration(milliseconds: 40),
    );
    final controller = StreamController<GpsFix>();
    final future = fast.acquire(controller.stream);
    controller.add(const GpsFix(lat: 1, lng: 2, accuracyM: 11));

    final result = await future;
    expect(result.accuracyM, 11);
    await controller.close();
  });
}
