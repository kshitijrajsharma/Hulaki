import 'package:geolocator/geolocator.dart';

/// Ensures location services are on and permission is granted, prompting once
/// when the choice has not been made yet. Returns whether the app may read
/// location. Shared by the capture burst and the live-location stream.
Future<bool> ensureLocationPermission() async {
  if (!await Geolocator.isLocationServiceEnabled()) return false;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}
