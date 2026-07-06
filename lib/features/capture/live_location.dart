import 'package:fieldchat/features/capture/location_permission.dart';
import 'package:geolocator/geolocator.dart';

/// A continuous device location reading. The extras are null when the platform
/// or the current fix does not report them.
class LiveLocation {
  const LiveLocation({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    this.altitudeM,
    this.speedMps,
    this.headingDeg,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final double? altitudeM;
  final double? speedMps;
  final double? headingDeg;
}

/// A continuous stream of device location for the live GPS strip and detail
/// sheet. Kept behind an interface so widget tests can inject a fake.
// ignore: one_member_abstracts
abstract interface class LiveLocationSource {
  Stream<LiveLocation> watch();
}

/// Real device location. Requests permission on first listen, then emits every
/// fix the platform reports.
class GeolocatorLiveLocationSource implements LiveLocationSource {
  const GeolocatorLiveLocationSource();

  @override
  Stream<LiveLocation> watch() async* {
    if (!await ensureLocationPermission()) return;
    // No distance filter, so the reading keeps refreshing while stationary and
    // its accuracy stays current instead of freezing until the next move.
    await for (final position in Geolocator.getPositionStream(
      locationSettings: const LocationSettings(),
    )) {
      yield LiveLocation(
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
        altitudeM: position.altitude,
        speedMps: position.speed,
        headingDeg: position.heading,
      );
    }
  }
}

/// A stand-in that emits one fixed reading, so screens render without device
/// sensors in tests and development.
class FakeLiveLocationSource implements LiveLocationSource {
  const FakeLiveLocationSource({this.lat = 27.7051, this.lng = 85.3051});

  final double lat;
  final double lng;

  @override
  Stream<LiveLocation> watch() async* {
    yield LiveLocation(
      lat: lat,
      lng: lng,
      accuracyM: 12,
      altitudeM: 1300,
      speedMps: 0,
      headingDeg: 0,
    );
  }
}
