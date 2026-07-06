import 'package:flutter_compass/flutter_compass.dart';

/// The device compass heading in degrees from magnetic north, or null while the
/// sensor has no reading. Kept behind an interface so tests can inject a fake.
// ignore: one_member_abstracts
abstract interface class CompassSource {
  Stream<double?> headings();
}

/// Real magnetometer heading. Emits null on devices without a compass.
class FlutterCompassSource implements CompassSource {
  const FlutterCompassSource();

  @override
  Stream<double?> headings() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream<double?>.empty();
    return events.map((event) => event.heading);
  }
}

/// A stand-in that emits one fixed heading, so the capture path resolves
/// without sensors in tests and development.
class FakeCompassSource implements CompassSource {
  const FakeCompassSource({this.headingDeg = 0});

  final double? headingDeg;

  @override
  Stream<double?> headings() => Stream<double?>.value(headingDeg);
}
