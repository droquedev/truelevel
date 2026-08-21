import 'package:bubble_level/src/ui/vial_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double travel = 100;

  group('flat vial', () {
    test('a level device leaves the bubble centred', () {
      expect(
        VialGeometry.flatBubbleOffset(pitch: 0, roll: 0, travel: travel),
        Offset.zero,
      );
    });

    test('a raised top-right corner pushes the bubble to the bottom left', () {
      final offset =
          VialGeometry.flatBubbleOffset(pitch: 4, roll: 3, travel: travel);
      expect(offset.dx, lessThan(0));
      expect(offset.dy, greaterThan(0));
    });

    test('a raised bottom-left corner pushes the bubble to the top right', () {
      final offset =
          VialGeometry.flatBubbleOffset(pitch: -4, roll: -3, travel: travel);
      expect(offset.dx, greaterThan(0));
      expect(offset.dy, lessThan(0));
    });

    test('displacement is proportional to tilt below full scale', () {
      final half = VialGeometry.flatBubbleOffset(pitch: 5, roll: 0, travel: travel);
      final quarter =
          VialGeometry.flatBubbleOffset(pitch: 2.5, roll: 0, travel: travel);
      expect(half.dy, closeTo(travel / 2, 0.001));
      expect(quarter.dy, closeTo(travel / 4, 0.001));
    });

    test('tilt beyond full scale stops at the inner edge', () {
      final offset =
          VialGeometry.flatBubbleOffset(pitch: 45, roll: 0, travel: travel);
      expect(offset.distance, closeTo(travel, 0.001));
    });

    test('a diagonal tilt beyond full scale stays inside the vial', () {
      final offset =
          VialGeometry.flatBubbleOffset(pitch: 30, roll: 30, travel: travel);
      expect(offset.distance, closeTo(travel, 0.001));
    });
  });

  group('upright vial', () {
    test('a plumb device leaves the bubble centred', () {
      expect(
        VialGeometry.uprightBubbleOffset(tilt: 0, travel: travel),
        Offset.zero,
      );
    });

    test('leaning right moves the bubble left and stays on the long axis', () {
      final offset = VialGeometry.uprightBubbleOffset(tilt: 5, travel: travel);
      expect(offset.dx, closeTo(-travel / 2, 0.001));
      expect(offset.dy, 0);
    });

    test('leaning left moves the bubble right', () {
      expect(
        VialGeometry.uprightBubbleOffset(tilt: 5, travel: travel).dx,
        lessThan(0),
      );
      expect(
        VialGeometry.uprightBubbleOffset(tilt: -5, travel: travel).dx,
        greaterThan(0),
      );
    });

    test('tilt beyond full scale stops at the end of the vial', () {
      expect(
        VialGeometry.uprightBubbleOffset(tilt: 40, travel: travel).dx,
        closeTo(-travel, 0.001),
      );
    });
  });
}
