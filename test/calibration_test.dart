import 'package:bubble_level/src/level/calibration.dart';
import 'package:bubble_level/src/level/host_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Calibration value', () {
    test('replacing the flat zero point keeps the upright one', () {
      const original = Calibration(flatPitch: 1, flatRoll: 2, upright: 3);
      final updated = original.withFlat(pitch: 9, roll: 8);

      expect(updated.flatPitch, 9);
      expect(updated.flatRoll, 8);
      expect(updated.upright, 3);
    });

    test('replacing the upright zero point keeps the flat one', () {
      const original = Calibration(flatPitch: 1, flatRoll: 2, upright: 3);
      final updated = original.withUpright(7);

      expect(updated.flatPitch, 1);
      expect(updated.flatRoll, 2);
      expect(updated.upright, 7);
    });

    test('round-trips through the host map form', () {
      const original = Calibration(flatPitch: 1.25, flatRoll: -0.5, upright: 4);
      expect(Calibration.fromMap(original.toMap()), original);
    });

    test('an absent stored value reads as no calibration', () {
      expect(Calibration.fromMap(null), Calibration.none);
    });
  });

  group('PlatformCalibrationStore', () {
    late List<MethodCall> calls;
    Map<String, double>? hostValue;

    setUp(() {
      calls = <MethodCall>[];
      hostValue = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(HostBridge.channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'loadCalibration':
            return hostValue;
          case 'saveCalibration':
            hostValue = (call.arguments as Map<Object?, Object?>)
                .map((k, v) => MapEntry(k! as String, v! as double));
            return null;
          case 'clearCalibration':
            hostValue = null;
            return null;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(HostBridge.channel, null);
    });

    test('saves and reloads a zero point through the host', () async {
      const store = PlatformCalibrationStore();
      const calibration = Calibration(flatPitch: 1.5, flatRoll: -2, upright: 0.25);

      await store.save(calibration);
      expect(await store.load(), calibration);
    });

    test('reads no calibration when the host has nothing stored', () async {
      const store = PlatformCalibrationStore();
      expect(await store.load(), Calibration.none);
    });

    test('clearing removes the stored zero point', () async {
      const store = PlatformCalibrationStore();

      await store.save(const Calibration(flatPitch: 3));
      await store.clear();

      expect(await store.load(), Calibration.none);
      expect(calls.map((c) => c.method), contains('clearCalibration'));
    });
  });

  group('HostBridge', () {
    test('forwards the keep-screen-on flag to the host', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(HostBridge.channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(HostBridge.channel, null);
      });

      const bridge = HostBridge();
      await bridge.setKeepScreenOn(true);
      await bridge.setKeepScreenOn(false);

      expect(calls.map((c) => c.method), <String>['setKeepScreenOn', 'setKeepScreenOn']);
      expect(calls.map((c) => c.arguments), <bool>[true, false]);
    });
  });
}
