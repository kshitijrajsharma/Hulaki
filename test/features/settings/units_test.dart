import 'package:fieldchat/features/settings/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDistance', () {
    test('metric shows meters below a kilometre', () {
      expect(formatDistance(240, UnitSystem.metric), '240 m');
    });

    test('metric shows kilometres above, trimming whole values', () {
      expect(formatDistance(2000, UnitSystem.metric), '2 km');
      expect(formatDistance(2140, UnitSystem.metric), '2.1 km');
    });

    test('imperial shows feet below a mile then miles', () {
      expect(formatDistance(30, UnitSystem.imperial), '98 ft');
      expect(formatDistance(1609.344, UnitSystem.imperial), '1 mi');
    });
  });

  group('formatElevation', () {
    test('rounds to whole metres or feet', () {
      expect(formatElevation(1337.4, UnitSystem.metric), '1337 m');
      expect(formatElevation(1000, UnitSystem.imperial), '3281 ft');
    });
  });

  group('cardinalFor', () {
    test('maps bearings to eight points and wraps around', () {
      expect(cardinalFor(0), 'N');
      expect(cardinalFor(45), 'NE');
      expect(cardinalFor(90), 'E');
      expect(cardinalFor(200), 'S');
      expect(cardinalFor(359), 'N');
      expect(cardinalFor(-45), 'NW');
    });
  });
}
