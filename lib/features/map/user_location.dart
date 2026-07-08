import 'package:fieldchat/features/capture/location_permission.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

Future<LatLng?> currentUserLatLng() async {
  if (!await ensureLocationPermission()) return null;
  final position = await Geolocator.getCurrentPosition();
  return LatLng(position.latitude, position.longitude);
}
