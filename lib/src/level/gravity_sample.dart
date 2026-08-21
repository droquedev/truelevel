import 'dart:math' as math;

/// A gravity vector sample in the Android sensor frame: `x` points toward the
/// right edge of the device, `y` toward the top edge, and `z` out of the
/// screen. A device lying flat and face up reads roughly (0, 0, 9.81).
class GravitySample {
  const GravitySample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  final double x;
  final double y;
  final double z;

  /// When the sample was observed, measured from an arbitrary origin.
  final Duration timestamp;

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  @override
  String toString() => 'GravitySample($x, $y, $z @ ${timestamp.inMilliseconds}ms)';
}
