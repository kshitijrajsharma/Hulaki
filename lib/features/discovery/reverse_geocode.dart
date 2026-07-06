import 'package:flutter/services.dart' show PlatformException;
import 'package:geocoding/geocoding.dart';

/// Resolves a coordinate to a human place name (city or district) for the
/// nearby list. Results are cached per rounded coordinate so the platform
/// geocoder is queried once per area. Returns null when the device cannot
/// resolve the point (offline or no match), and the caller shows distance only.
class ReverseGeocoder {
  ReverseGeocoder._();

  static final Map<String, String?> _cache = {};

  static Future<String?> placeName(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    if (_cache.containsKey(key)) return _cache[key];
    final name = await _lookup(lat, lng);
    _cache[key] = name;
    return name;
  }

  static Future<String?> _lookup(double lat, double lng) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final mark = marks.first;
      for (final part in [
        mark.locality,
        mark.subLocality,
        mark.subAdministrativeArea,
        mark.administrativeArea,
      ]) {
        if (part != null && part.isNotEmpty) return part;
      }
      return null;
    } on PlatformException {
      return null;
    }
  }
}
