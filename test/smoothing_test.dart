import 'dart:math' as math;

import 'package:bubble_level/src/level/angles.dart';
import 'package:bubble_level/src/level/smoothing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/samples.dart';

const Duration _samplePeriod = Duration(milliseconds: 20);

void main() {
  test('the first sample passes through so a reading appears immediately', () {
    final smoother = GravitySmoother();
    final smoothed = smoother.add(flatSample(pitch: 7));
    expect(pitchDegrees(smoothed), closeTo(7, 0.001));
  });

  test('a stationary noisy device moves less than 0.2 degrees per update', () {
    final smoother = GravitySmoother();
    final random = math.Random(1234);
    var elapsed = Duration.zero;
    double? previous;

    for (var i = 0; i < 500; i++) {
      elapsed += _samplePeriod;
      final noisy = flatSample(
        pitch: 3 + (random.nextDouble() - 0.5) * 0.6,
        roll: -2 + (random.nextDouble() - 0.5) * 0.6,
        timestamp: elapsed,
      );
      final pitch = pitchDegrees(smoother.add(noisy));
      if (previous != null) {
        expect((pitch - previous).abs(), lessThanOrEqualTo(0.2));
      }
      previous = pitch;
    }
  });

  test('a step change settles within 0.2 degrees in under 500 ms', () {
    final smoother = GravitySmoother();
    var elapsed = Duration.zero;

    smoother.add(flatSample(timestamp: elapsed));
    for (var i = 0; i < 10; i++) {
      elapsed += _samplePeriod;
      smoother.add(flatSample(timestamp: elapsed));
    }

    final settleDeadline = elapsed + const Duration(milliseconds: 500);
    late double pitch;
    while (elapsed < settleDeadline) {
      elapsed += _samplePeriod;
      pitch = pitchDegrees(smoother.add(flatSample(pitch: 20, timestamp: elapsed)));
    }

    expect((pitch - 20).abs(), lessThan(0.2));
  });

  test('samples that arrive twice as fast settle in the same wall time', () {
    double settledPitchAfter(Duration period) {
      final smoother = GravitySmoother();
      var elapsed = Duration.zero;
      smoother.add(flatSample(timestamp: elapsed));

      var pitch = 0.0;
      while (elapsed < const Duration(milliseconds: 300)) {
        elapsed += period;
        pitch = pitchDegrees(smoother.add(flatSample(pitch: 10, timestamp: elapsed)));
      }
      return pitch;
    }

    expect(
      settledPitchAfter(const Duration(milliseconds: 10)),
      closeTo(settledPitchAfter(const Duration(milliseconds: 20)), 0.1),
    );
  });

  test('reset lets the next sample pass through untouched', () {
    final smoother = GravitySmoother();
    smoother.add(flatSample(pitch: 10));
    smoother.add(flatSample(pitch: 10, timestamp: _samplePeriod));
    smoother.reset();

    final smoothed = smoother.add(flatSample(pitch: -4, timestamp: _samplePeriod * 2));
    expect(pitchDegrees(smoothed), closeTo(-4, 0.001));
  });
}
