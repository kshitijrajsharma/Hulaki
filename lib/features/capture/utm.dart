import 'package:proj4dart/proj4dart.dart' as proj4;

/// A position projected into the UTM zone that contains it.
class UtmCoordinate {
  const UtmCoordinate({
    required this.zone,
    required this.hemisphere,
    required this.easting,
    required this.northing,
  });

  final int zone;
  final String hemisphere;
  final double easting;
  final double northing;

  /// Compact grid reference, e.g. "45N 340120E 3065430N".
  String get label =>
      '$zone$hemisphere ${easting.round()}E ${northing.round()}N';
}

/// Projects WGS84 lat/lon into its UTM zone using proj4dart.
UtmCoordinate latLonToUtm(double lat, double lng) {
  final zone = (((lng + 180) / 6).floor() % 60) + 1;
  final north = lat >= 0;
  final code = 'EPSG:${(north ? 32600 : 32700) + zone}';
  final utm =
      proj4.Projection.get(code) ??
      proj4.Projection.add(
        code,
        '+proj=utm +zone=$zone${north ? '' : ' +south'} '
        '+datum=WGS84 +units=m +no_defs',
      );
  final projected = proj4.Projection.WGS84.transform(
    utm,
    proj4.Point(x: lng, y: lat),
  );
  return UtmCoordinate(
    zone: zone,
    hemisphere: north ? 'N' : 'S',
    easting: projected.x,
    northing: projected.y,
  );
}
