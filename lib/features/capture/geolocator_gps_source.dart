import 'package:fieldchat/features/capture/gps_gate.dart';
import 'package:fieldchat/features/capture/gps_source.dart';
import 'package:fieldchat/features/capture/location_permission.dart';
import 'package:geolocator/geolocator.dart';

/// Real device GPS. Emits a short burst of fixes for one capture so the gate
/// can lock the spot fast and sharpen it. Requests permission on first use.
class GeolocatorGpsSource implements GpsSource {
  const GeolocatorGpsSource();

  @override
  Stream<GpsFix> fixes() async* {
    if (!await ensureLocationPermission()) return;

    const settings = LocationSettings();
    var emitted = 0;
    await for (final position in Geolocator.getPositionStream(
      locationSettings: settings,
    )) {
      yield GpsFix(
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
        altitudeM: position.altitude,
      );
      if (++emitted >= 5) break;
    }
  }
}
