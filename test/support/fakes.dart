import 'dart:async';

import 'package:bubble_level/src/level/calibration.dart';
import 'package:bubble_level/src/level/gravity_sample.dart';
import 'package:bubble_level/src/level/gravity_source.dart';

/// A gravity source driven by the test instead of by hardware.
class FakeGravitySource implements GravitySource {
  final StreamController<GravitySample> _controller =
      StreamController<GravitySample>.broadcast();

  @override
  Stream<GravitySample> get samples => _controller.stream;

  void emit(GravitySample sample) => _controller.add(sample);

  void emitError(Object error) => _controller.addError(error);

  Future<void> close() => _controller.close();
}

/// Calibration storage that lives only in memory.
class FakeCalibrationStore implements CalibrationStore {
  FakeCalibrationStore([this.stored = Calibration.none]);

  Calibration stored;
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<Calibration> load() async => stored;

  @override
  Future<void> save(Calibration calibration) async {
    stored = calibration;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    stored = Calibration.none;
    clearCount++;
  }
}
