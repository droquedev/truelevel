/// How the device is being held, which decides which vial is shown.
enum DevicePosture { flat, upright }

/// Calibrated tilt angles in degrees, together with the posture they were
/// measured in.
class LevelReading {
  const LevelReading({
    required this.pitch,
    required this.roll,
    required this.uprightTilt,
    required this.posture,
  });

  /// Positive when the top edge of the device is raised.
  final double pitch;

  /// Positive when the right edge of the device is raised.
  final double roll;

  /// Positive when a device held on edge leans to the right.
  final double uprightTilt;

  final DevicePosture posture;

  static const double levelToleranceDegrees = 0.2;

  /// The angles shown to the user: pitch and roll when flat, the single
  /// on-edge angle when upright.
  List<double> get displayedAngles => posture == DevicePosture.flat
      ? <double>[pitch, roll]
      : <double>[uprightTilt];

  bool get isLevel =>
      displayedAngles.every((a) => a.abs() <= levelToleranceDegrees);

  @override
  String toString() =>
      'LevelReading(pitch: $pitch, roll: $roll, upright: $uprightTilt, $posture)';
}
