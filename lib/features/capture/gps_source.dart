import 'package:fieldchat/features/capture/gps_gate.dart';

/// A source of GPS fixes for the capture gate. The real implementation wraps
/// the device GPS (geolocator); this interface keeps the composer testable and
/// runnable before device sensors are wired.
// Kept as an interface so the device GPS implementation can be swapped in.
// ignore: one_member_abstracts
abstract interface class GpsSource {
  /// A short burst of fixes for one capture, typically improving in accuracy.
  Stream<GpsFix> fixes();
}

/// A deterministic stand-in that emits a coarse fix sharpening to a fine one
/// around a fixed point. Used for development until the device GPS is wired.
class FakeGpsSource implements GpsSource {
  FakeGpsSource({this.lat = 27.7051, this.lng = 85.3051});

  final double lat;
  final double lng;

  @override
  Stream<GpsFix> fixes() async* {
    yield GpsFix(lat: lat, lng: lng, accuracyM: 14);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    yield GpsFix(lat: lat, lng: lng, accuracyM: 6);
  }
}
