import 'dart:convert';

import 'package:fieldchat/features/export/geojson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A square around Kathmandu, roughly 85.30..85.34 E by 27.70..27.73 N.
  final square = jsonEncode({
    'type': 'Feature',
    'geometry': {
      'type': 'Polygon',
      'coordinates': [
        [
          [85.30, 27.70],
          [85.34, 27.70],
          [85.34, 27.73],
          [85.30, 27.73],
          [85.30, 27.70],
        ],
      ],
    },
  });

  test('a point inside the polygon reads inside', () {
    expect(pointInAoi(square, 27.715, 85.320), isTrue);
  });

  test('a point outside the polygon reads outside', () {
    expect(pointInAoi(square, 27.750, 85.320), isFalse);
    expect(pointInAoi(square, 27.715, 85.290), isFalse);
  });

  test('geometry with no polygon never contains a point', () {
    final point = jsonEncode({
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [85.32, 27.71],
      },
    });
    expect(pointInAoi(point, 27.71, 85.32), isFalse);
  });
}
