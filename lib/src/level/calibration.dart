import 'host_bridge.dart';

/// Zero points captured by the user, held separately per posture so that
/// calibrating on a table does not disturb the on-edge reference.
class Calibration {
  const Calibration({this.flatPitch = 0, this.flatRoll = 0, this.upright = 0});

  static const Calibration none = Calibration();

  final double flatPitch;
  final double flatRoll;
  final double upright;

  Calibration withFlat({required double pitch, required double roll}) =>
      Calibration(flatPitch: pitch, flatRoll: roll, upright: upright);

  Calibration withUpright(double tilt) =>
      Calibration(flatPitch: flatPitch, flatRoll: flatRoll, upright: tilt);

  Map<String, double> toMap() => <String, double>{
        'flatPitch': flatPitch,
        'flatRoll': flatRoll,
        'upright': upright,
      };

  static Calibration fromMap(Map<String, double>? offsets) => offsets == null
      ? none
      : Calibration(
          flatPitch: offsets['flatPitch'] ?? 0,
          flatRoll: offsets['flatRoll'] ?? 0,
          upright: offsets['upright'] ?? 0,
        );

  @override
  bool operator ==(Object other) =>
      other is Calibration &&
      other.flatPitch == flatPitch &&
      other.flatRoll == flatRoll &&
      other.upright == upright;

  @override
  int get hashCode => Object.hash(flatPitch, flatRoll, upright);

  @override
  String toString() =>
      'Calibration(flatPitch: $flatPitch, flatRoll: $flatRoll, upright: $upright)';
}

abstract class CalibrationStore {
  Future<Calibration> load();
  Future<void> save(Calibration calibration);
  Future<void> clear();
}

/// Persists calibration in the host activity's shared preferences.
class PlatformCalibrationStore implements CalibrationStore {
  const PlatformCalibrationStore({this.bridge = const HostBridge()});

  final HostBridge bridge;

  @override
  Future<Calibration> load() async =>
      Calibration.fromMap(await bridge.loadCalibration());

  @override
  Future<void> save(Calibration calibration) =>
      bridge.saveCalibration(calibration.toMap());

  @override
  Future<void> clear() => bridge.clearCalibration();
}
