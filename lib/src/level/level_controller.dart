import 'dart:async';

import 'package:flutter/foundation.dart';

import 'angles.dart';
import 'calibration.dart';
import 'gravity_sample.dart';
import 'gravity_source.dart';
import 'level_reading.dart';
import 'smoothing.dart';

/// What happened when the user asked to capture a zero point.
enum CalibrationOutcome { captured, rejectedTooSteep, noReading }

/// Turns a stream of gravity samples into calibrated readings the UI can show.
class LevelController {
  LevelController({required this.source, required this.store});

  /// A reference surface further than this from nominal is not usable as a
  /// zero point, so a capture against it is refused.
  static const double maxCalibrationTiltDegrees = 10;

  final GravitySource source;
  final CalibrationStore store;
  final GravitySmoother _smoother = GravitySmoother();
  final PostureClassifier _classifier = PostureClassifier();

  final ValueNotifier<LevelReading?> reading = ValueNotifier<LevelReading?>(null);
  final ValueNotifier<bool> sensorUnavailable = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasCalibration = ValueNotifier<bool>(false);

  Calibration _calibration = Calibration.none;
  LevelReading? _rawReading;
  double _rawTiltFromHorizontal = 0;
  StreamSubscription<GravitySample>? _subscription;

  Calibration get calibration => _calibration;

  /// Loads any stored zero point before the first sample is processed, so the
  /// very first reading shown is already calibrated.
  Future<void> start() async {
    _calibration = await store.load();
    hasCalibration.value = _calibration != Calibration.none;
    _subscription = source.samples.listen(_onSample, onError: _onError);
  }

  Future<CalibrationOutcome> calibrate() async {
    final raw = _rawReading;
    if (raw == null) return CalibrationOutcome.noReading;

    if (raw.posture == DevicePosture.flat) {
      if (_rawTiltFromHorizontal > maxCalibrationTiltDegrees) {
        return CalibrationOutcome.rejectedTooSteep;
      }
      _calibration = _calibration.withFlat(pitch: raw.pitch, roll: raw.roll);
    } else {
      if (raw.uprightTilt.abs() > maxCalibrationTiltDegrees) {
        return CalibrationOutcome.rejectedTooSteep;
      }
      _calibration = _calibration.withUpright(raw.uprightTilt);
    }

    await store.save(_calibration);
    hasCalibration.value = _calibration != Calibration.none;
    reading.value = _applyCalibration(raw);
    return CalibrationOutcome.captured;
  }

  Future<void> resetCalibration() async {
    _calibration = Calibration.none;
    await store.clear();
    hasCalibration.value = false;
    final raw = _rawReading;
    if (raw != null) reading.value = _applyCalibration(raw);
  }

  void _onSample(GravitySample sample) {
    final smoothed = _smoother.add(sample);
    _rawTiltFromHorizontal = tiltFromHorizontalDegrees(smoothed);
    final raw = LevelReading(
      pitch: pitchDegrees(smoothed),
      roll: rollDegrees(smoothed),
      uprightTilt: uprightTiltDegrees(smoothed),
      posture: _classifier.update(_rawTiltFromHorizontal),
    );
    _rawReading = raw;
    sensorUnavailable.value = false;
    reading.value = _applyCalibration(raw);
  }

  void _onError(Object error) {
    if (error is SensorUnavailableException) {
      sensorUnavailable.value = true;
      reading.value = null;
    }
  }

  LevelReading _applyCalibration(LevelReading raw) => LevelReading(
        pitch: raw.pitch - _calibration.flatPitch,
        roll: raw.roll - _calibration.flatRoll,
        uprightTilt: raw.uprightTilt - _calibration.upright,
        posture: raw.posture,
      );

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    reading.dispose();
    sensorUnavailable.dispose();
    hasCalibration.dispose();
  }
}
