import 'dart:math' as math;

import 'package:bubble_level/src/level/gravity_sample.dart';

const double _g = 9.81;
const double _degreesToRadians = math.pi / 180;

/// Builds the gravity vector a face-up device reports when its top edge is
/// raised by [pitch] degrees and its right edge by [roll] degrees.
GravitySample flatSample({
  double pitch = 0,
  double roll = 0,
  Duration timestamp = Duration.zero,
}) {
  final p = pitch * _degreesToRadians;
  final r = roll * _degreesToRadians;
  return GravitySample(
    x: _g * math.sin(r),
    y: _g * math.sin(p) * math.cos(r),
    z: _g * math.cos(p) * math.cos(r),
    timestamp: timestamp,
  );
}

/// Builds the gravity vector a device standing on edge reports when it leans
/// [lean] degrees to the right.
GravitySample uprightSample({
  double lean = 0,
  Duration timestamp = Duration.zero,
}) {
  final l = lean * _degreesToRadians;
  return GravitySample(
    x: -_g * math.sin(l),
    y: _g * math.cos(l),
    z: 0,
    timestamp: timestamp,
  );
}

/// Builds a gravity vector whose screen plane sits [tilt] degrees from
/// horizontal, rotated about the device's x-axis.
GravitySample tiltedSample(double tilt, {Duration timestamp = Duration.zero}) {
  final t = tilt * _degreesToRadians;
  return GravitySample(
    x: 0,
    y: _g * math.sin(t),
    z: _g * math.cos(t),
    timestamp: timestamp,
  );
}
