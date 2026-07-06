import 'dart:math';

import 'package:fieldchat/core/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ringAreaSqMeters', () {
    test('returns 0 for fewer than three points', () {
      expect(ringAreaSqMeters([27.7], [85.3]), 0);
      expect(ringAreaSqMeters([27.7, 27.71], [85.3, 85.31]), 0);
    });

    test('computes area of a ~100m square within one percent', () {
      const lat = 27.7;
      const dLat = 100 / 111320.0;
      final metersPerDegLng = 111320.0 * cos(lat * pi / 180);
      final dLng = 100 / metersPerDegLng;
      final lats = [lat, lat + dLat, lat + dLat, lat];
      final lngs = [85.3, 85.3, 85.3 + dLng, 85.3 + dLng];
      expect(ringAreaSqMeters(lats, lngs), closeTo(10000, 100));
    });

    test('is winding-order independent', () {
      final lats = [27.70, 27.71, 27.71, 27.70];
      final lngs = [85.30, 85.30, 85.31, 85.31];
      final cw = ringAreaSqMeters(lats, lngs);
      final ccw = ringAreaSqMeters(
        lats.reversed.toList(),
        lngs.reversed.toList(),
      );
      expect(cw, closeTo(ccw, 1e-6));
    });

    test('a tiny triangle falls below the 100 sqm floor', () {
      final lats = [27.7000, 27.70001, 27.70000];
      final lngs = [85.3000, 85.30000, 85.30001];
      expect(ringAreaSqMeters(lats, lngs), lessThan(100));
    });

    test('throws when list lengths differ', () {
      expect(
        () => ringAreaSqMeters([27.7, 27.71], [85.3]),
        throwsArgumentError,
      );
    });
  });
}
