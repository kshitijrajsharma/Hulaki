import 'dart:math';

/// Great-circle distance in metres between two coordinates (haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * pi / 180.0;

/// Planar area in square metres of a polygon ring given as parallel latitude
/// and longitude lists. Uses the shoelace formula on an equirectangular
/// projection about the ring's mean latitude. Returns 0 for fewer than three
/// points. The ring is treated as closed; a repeated last point is harmless.
double ringAreaSqMeters(List<double> lats, List<double> lngs) {
  if (lats.length != lngs.length) {
    throw ArgumentError('lats and lngs must have equal length');
  }
  final count = lats.length;
  if (count < 3) return 0;
  const metersPerDegLat = 111320.0;
  final meanLat = lats.reduce((a, b) => a + b) / count;
  final metersPerDegLng = metersPerDegLat * cos(_toRadians(meanLat));
  var sum = 0.0;
  for (var i = 0; i < count; i++) {
    final j = (i + 1) % count;
    final xi = lngs[i] * metersPerDegLng;
    final yi = lats[i] * metersPerDegLat;
    final xj = lngs[j] * metersPerDegLng;
    final yj = lats[j] * metersPerDegLat;
    sum += xi * yj - xj * yi;
  }
  return sum.abs() / 2;
}
