import 'package:bubble_level/src/level/calibration.dart';
import 'package:bubble_level/src/level/gravity_source.dart';
import 'package:bubble_level/src/level/level_controller.dart';
import 'package:bubble_level/src/level/level_reading.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/samples.dart';

/// Lets the controller's stream subscription run.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeGravitySource source;
  late FakeCalibrationStore store;
  late LevelController controller;

  Future<LevelController> startWith(Calibration stored) async {
    source = FakeGravitySource();
    store = FakeCalibrationStore(stored);
    controller = LevelController(source: source, store: store);
    await controller.start();
    return controller;
  }

  tearDown(() async {
    await controller.dispose();
    await source.close();
  });

  group('readings', () {
    test('publishes pitch, roll and posture from the sample stream', () async {
      await startWith(Calibration.none);

      source.emit(flatSample(pitch: 3, roll: -2));
      await settle();

      final reading = controller.reading.value!;
      expect(reading.pitch, closeTo(3, 0.01));
      expect(reading.roll, closeTo(-2, 0.01));
      expect(reading.posture, DevicePosture.flat);
    });

    test('follows the device from flat into upright posture', () async {
      await startWith(Calibration.none);

      source.emit(flatSample());
      await settle();
      expect(controller.reading.value!.posture, DevicePosture.flat);

      for (var i = 0; i < 200; i++) {
        source.emit(uprightSample(lean: 4, timestamp: Duration(milliseconds: 20 * i)));
      }
      await settle();

      final reading = controller.reading.value!;
      expect(reading.posture, DevicePosture.upright);
      expect(reading.uprightTilt, closeTo(4, 0.1));
    });

    test('reports a sensor-unavailable error instead of a reading', () async {
      await startWith(Calibration.none);

      source.emitError(const SensorUnavailableException());
      await settle();

      expect(controller.sensorUnavailable.value, isTrue);
      expect(controller.reading.value, isNull);
    });
  });

  group('calibration', () {
    test('capturing while flat zeroes the displayed angles', () async {
      await startWith(Calibration.none);

      source.emit(flatSample(pitch: 1.4, roll: -0.8));
      await settle();

      expect(await controller.calibrate(), CalibrationOutcome.captured);

      final reading = controller.reading.value!;
      expect(reading.pitch, closeTo(0, 0.001));
      expect(reading.roll, closeTo(0, 0.001));
      expect(reading.isLevel, isTrue);
      expect(store.stored.flatPitch, closeTo(1.4, 0.01));
    });

    test('a known tilt still measures correctly after calibration', () async {
      await startWith(Calibration.none);

      source.emit(flatSample(pitch: 1.0));
      await settle();
      await controller.calibrate();

      for (var i = 1; i <= 200; i++) {
        source.emit(flatSample(pitch: 6.0, timestamp: Duration(milliseconds: 20 * i)));
      }
      await settle();

      expect(controller.reading.value!.pitch, closeTo(5.0, 0.1));
    });

    test('capturing flat leaves the upright zero point untouched', () async {
      await startWith(const Calibration(upright: 2.5));

      source.emit(flatSample(pitch: 1.0, roll: 1.0));
      await settle();
      await controller.calibrate();

      expect(store.stored.upright, 2.5);
      expect(store.stored.flatPitch, closeTo(1.0, 0.01));
    });

    test('capturing upright leaves the flat zero point untouched', () async {
      await startWith(const Calibration(flatPitch: 1.5, flatRoll: -0.5));

      for (var i = 0; i < 200; i++) {
        source.emit(uprightSample(lean: 3, timestamp: Duration(milliseconds: 20 * i)));
      }
      await settle();
      expect(await controller.calibrate(), CalibrationOutcome.captured);

      expect(store.stored.flatPitch, 1.5);
      expect(store.stored.flatRoll, -0.5);
      expect(store.stored.upright, closeTo(3, 0.1));
      expect(controller.reading.value!.uprightTilt, closeTo(0, 0.001));
    });

    test('a stored zero point applies to the first reading after start', () async {
      await startWith(const Calibration(flatPitch: 2.0, flatRoll: 1.0));

      source.emit(flatSample(pitch: 2.0, roll: 1.0));
      await settle();

      final reading = controller.reading.value!;
      expect(reading.pitch, closeTo(0, 0.01));
      expect(reading.roll, closeTo(0, 0.01));
      expect(controller.hasCalibration.value, isTrue);
    });

    test('starting with no stored calibration reports none', () async {
      await startWith(Calibration.none);
      expect(controller.hasCalibration.value, isFalse);
    });

    test('reset clears the offset and the stored value', () async {
      await startWith(const Calibration(flatPitch: 2.0));

      source.emit(flatSample(pitch: 2.0));
      await settle();
      expect(controller.reading.value!.pitch, closeTo(0, 0.01));

      await controller.resetCalibration();

      expect(controller.reading.value!.pitch, closeTo(2.0, 0.01));
      expect(store.stored, Calibration.none);
      expect(store.clearCount, 1);
      expect(controller.hasCalibration.value, isFalse);
    });
  });

  group('implausible calibration', () {
    test('is refused when the flat surface is steeper than 10 degrees', () async {
      await startWith(const Calibration(flatPitch: 1.0));

      source.emit(flatSample(pitch: 14));
      await settle();

      expect(await controller.calibrate(), CalibrationOutcome.rejectedTooSteep);
      expect(store.saveCount, 0);
      expect(store.stored.flatPitch, 1.0);
      expect(controller.calibration.flatPitch, 1.0);
    });

    test('is refused when an upright device leans more than 10 degrees', () async {
      await startWith(const Calibration(upright: 1.0));

      for (var i = 0; i < 200; i++) {
        source.emit(uprightSample(lean: 15, timestamp: Duration(milliseconds: 20 * i)));
      }
      await settle();

      expect(await controller.calibrate(), CalibrationOutcome.rejectedTooSteep);
      expect(store.saveCount, 0);
      expect(store.stored.upright, 1.0);
    });

    test('is accepted just inside the allowed range', () async {
      await startWith(Calibration.none);

      source.emit(flatSample(pitch: 9));
      await settle();

      expect(await controller.calibrate(), CalibrationOutcome.captured);
      expect(store.saveCount, 1);
    });

    test('is refused before any reading has arrived', () async {
      await startWith(Calibration.none);
      expect(await controller.calibrate(), CalibrationOutcome.noReading);
    });
  });
}
