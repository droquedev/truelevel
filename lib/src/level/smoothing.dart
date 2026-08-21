import 'dart:math' as math;

import 'gravity_sample.dart';

/// First-order low-pass filter over the gravity vector.
///
/// The per-sample weight comes from the interval between samples rather than
/// being fixed, so devices that deliver samples at different rates settle in
/// the same wall-clock time.
class GravitySmoother {
  GravitySmoother({this.timeConstant = const Duration(milliseconds: 90)});

  /// Time for the filter to close roughly 63% of the gap to a new value.
  final Duration timeConstant;

  double _x = 0;
  double _y = 0;
  double _z = 0;
  bool _primed = false;
  Duration _lastTimestamp = Duration.zero;

  void reset() {
    _primed = false;
    _lastTimestamp = Duration.zero;
  }

  /// Feeds a raw sample in and returns the smoothed vector. The first sample
  /// after construction or [reset] passes through untouched so that a reading
  /// appears immediately instead of easing in from zero.
  GravitySample add(GravitySample sample) {
    if (!_primed) {
      _primed = true;
      _x = sample.x;
      _y = sample.y;
      _z = sample.z;
      _lastTimestamp = sample.timestamp;
      return sample;
    }

    final alpha = _alphaFor(sample.timestamp - _lastTimestamp);
    _lastTimestamp = sample.timestamp;
    _x += alpha * (sample.x - _x);
    _y += alpha * (sample.y - _y);
    _z += alpha * (sample.z - _z);

    return GravitySample(x: _x, y: _y, z: _z, timestamp: sample.timestamp);
  }

  double _alphaFor(Duration interval) {
    final micros = interval.inMicroseconds;
    if (micros <= 0) return 0;
    final tau = timeConstant.inMicroseconds;
    if (tau <= 0) return 1;
    return 1 - math.exp(-micros / tau);
  }
}
