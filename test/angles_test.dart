import 'package:bubble_level/src/level/angles.dart';
import 'package:bubble_level/src/level/level_reading.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/samples.dart';

void main() {
  group('flat posture angles', () {
    test('a level device reads zero on both axes', () {
      final sample = flatSample();
      expect(pitchDegrees(sample), closeTo(0, 0.001));
      expect(rollDegrees(sample), closeTo(0, 0.001));
    });

    test('raising the top edge by 5 degrees gives a pitch of +5', () {
      final sample = flatSample(pitch: 5);
      expect(pitchDegrees(sample), closeTo(5, 0.001));
      expect(rollDegrees(sample), closeTo(0, 0.001));
    });

    test('lowering the top edge by 5 degrees gives a pitch of -5', () {
      expect(pitchDegrees(flatSample(pitch: -5)), closeTo(-5, 0.001));
    });

    test('raising the right edge by 5 degrees gives a roll of +5', () {
      final sample = flatSample(roll: 5);
      expect(rollDegrees(sample), closeTo(5, 0.001));
      expect(pitchDegrees(sample), closeTo(0, 0.001));
    });

    test('lowering the right edge by 5 degrees gives a roll of -5', () {
      expect(rollDegrees(flatSample(roll: -5)), closeTo(-5, 0.001));
    });

    test('a raised top-right corner is positive on both axes', () {
      final sample = flatSample(pitch: 4, roll: 3);
      expect(pitchDegrees(sample), greaterThan(0));
      expect(rollDegrees(sample), greaterThan(0));
    });
  });

  group('upright posture angle', () {
    test('a plumb device reads zero', () {
      expect(uprightTiltDegrees(uprightSample()), closeTo(0, 0.001));
    });

    test('leaning right is positive', () {
      expect(uprightTiltDegrees(uprightSample(lean: 6)), closeTo(6, 0.001));
    });

    test('leaning left is negative', () {
      expect(uprightTiltDegrees(uprightSample(lean: -6)), closeTo(-6, 0.001));
    });
  });

  group('tilt from horizontal', () {
    test('is zero when face up and 180-degree symmetric when face down', () {
      expect(tiltFromHorizontalDegrees(flatSample()), closeTo(0, 0.001));
      expect(tiltFromHorizontalDegrees(tiltedSample(180)), closeTo(0, 0.001));
    });

    test('is 90 when the device stands on edge', () {
      expect(tiltFromHorizontalDegrees(uprightSample()), closeTo(90, 0.001));
    });

    test('tracks the rotation angle in between', () {
      expect(tiltFromHorizontalDegrees(tiltedSample(30)), closeTo(30, 0.001));
    });
  });

  group('posture classification', () {
    test('starts flat and stays flat below the upright threshold', () {
      final classifier = PostureClassifier();
      expect(classifier.update(0), DevicePosture.flat);
      expect(classifier.update(49), DevicePosture.flat);
      expect(classifier.update(55), DevicePosture.flat);
    });

    test('switches to upright past 60 degrees', () {
      final classifier = PostureClassifier();
      expect(classifier.update(61), DevicePosture.upright);
    });

    test('stays upright until the device returns within 50 degrees', () {
      final classifier = PostureClassifier();
      classifier.update(90);
      expect(classifier.update(55), DevicePosture.upright);
      expect(classifier.update(51), DevicePosture.upright);
      expect(classifier.update(49), DevicePosture.flat);
    });

    test('a slow sweep through the boundary changes posture exactly once', () {
      final classifier = PostureClassifier();
      classifier.update(90);

      final transitions = <DevicePosture>[];
      var previous = classifier.posture;
      for (var tilt = 90.0; tilt >= 0; tilt -= 0.5) {
        final posture = classifier.update(tilt);
        if (posture != previous) {
          transitions.add(posture);
          previous = posture;
        }
      }

      expect(transitions, <DevicePosture>[DevicePosture.flat]);
    });

    test('hovering inside the hysteresis band never changes posture', () {
      final classifier = PostureClassifier();
      classifier.update(90);

      for (var i = 0; i < 50; i++) {
        expect(classifier.update(i.isEven ? 52 : 58), DevicePosture.upright);
      }
    });
  });
}
