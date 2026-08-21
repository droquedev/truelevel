import 'dart:math' as math;

import 'gravity_sample.dart';
import 'level_reading.dart';

const double _radiansToDegrees = 180 / math.pi;

/// Tilt about the device's x-axis, positive when the top edge is raised.
double pitchDegrees(GravitySample sample) =>
    math.atan2(sample.y, math.sqrt(sample.x * sample.x + sample.z * sample.z)) *
    _radiansToDegrees;

/// Tilt about the device's y-axis, positive when the right edge is raised.
double rollDegrees(GravitySample sample) =>
    math.atan2(sample.x, math.sqrt(sample.y * sample.y + sample.z * sample.z)) *
    _radiansToDegrees;

/// Rotation within the plane of the screen for a device held on edge,
/// positive when the device leans to the right.
double uprightTiltDegrees(GravitySample sample) =>
    math.atan2(-sample.x, sample.y) * _radiansToDegrees;

/// How far the plane of the screen sits from horizontal: 0 when the device
/// lies flat either face up or face down, 90 when it stands on edge.
double tiltFromHorizontalDegrees(GravitySample sample) {
  final magnitude = sample.magnitude;
  if (magnitude == 0) return 0;
  return math.acos((sample.z.abs() / magnitude).clamp(0.0, 1.0)) *
      _radiansToDegrees;
}

/// Chooses between the flat and upright postures. The two thresholds differ so
/// that a device parked near the boundary keeps whichever posture it already
/// had instead of oscillating between them.
class PostureClassifier {
  static const double uprightEntryDegrees = 60;
  static const double flatEntryDegrees = 50;

  DevicePosture _posture = DevicePosture.flat;

  DevicePosture get posture => _posture;

  DevicePosture update(double tiltFromHorizontal) {
    if (_posture == DevicePosture.flat) {
      if (tiltFromHorizontal > uprightEntryDegrees) {
        _posture = DevicePosture.upright;
      }
    } else if (tiltFromHorizontal < flatEntryDegrees) {
      _posture = DevicePosture.flat;
    }
    return _posture;
  }
}
