import 'dart:math' as math;

/// The unit system used to display distances and elevations.
enum UnitSystem { metric, imperial }

const double _feetPerMeter = 3.28084;
const double _milesPerMeter = 1 / 1609.344;

/// A distance for humans: meters below 1 km, kilometers above, or the imperial
/// equivalents. Whole numbers drop the decimal.
String formatDistance(double meters, UnitSystem units) {
  if (units == UnitSystem.imperial) {
    final feet = meters * _feetPerMeter;
    if (feet < 1000) return '${feet.round()} ft';
    return '${_trim(meters * _milesPerMeter)} mi';
  }
  if (meters < 1000) return '${meters.round()} m';
  return '${_trim(meters / 1000)} km';
}

/// An elevation for humans: meters or feet, rounded to whole units.
String formatElevation(double meters, UnitSystem units) {
  if (units == UnitSystem.imperial) {
    return '${(meters * _feetPerMeter).round()} ft';
  }
  return '${meters.round()} m';
}

String _trim(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toString();
}

/// A compass bearing turned into an eight-point cardinal label.
String cardinalFor(double headingDeg) {
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final normalized = (headingDeg % 360 + 360) % 360;
  final index = (normalized / 45).round() % 8;
  return points[index];
}

/// Degrees turned into radians for rotating a heading arrow.
double degreesToRadians(double degrees) => degrees * math.pi / 180;
