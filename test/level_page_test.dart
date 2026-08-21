import 'package:bubble_level/src/level/calibration.dart';
import 'package:bubble_level/src/level/gravity_source.dart';
import 'package:bubble_level/src/level/level_controller.dart';
import 'package:bubble_level/src/ui/level_page.dart';
import 'package:bubble_level/src/ui/vial_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/samples.dart';

void main() {
  FakeGravitySource? source;
  late FakeCalibrationStore store;
  LevelController? controller;

  Future<void> pumpPage(
    WidgetTester tester, {
    Calibration stored = Calibration.none,
  }) async {
    final gravity = FakeGravitySource();
    source = gravity;
    store = FakeCalibrationStore(stored);
    final levelController = LevelController(source: gravity, store: store);
    controller = levelController;
    await levelController.start();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: LevelPage(controller: levelController),
      ),
    );
  }

  /// Drives the smoother to the given flat tilt and settles the UI.
  Future<void> holdFlat(
    WidgetTester tester, {
    double pitch = 0,
    double roll = 0,
  }) async {
    for (var i = 0; i < 100; i++) {
      source!.emit(
        flatSample(
          pitch: pitch,
          roll: roll,
          timestamp: Duration(milliseconds: 20 * i),
        ),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> holdUpright(WidgetTester tester, {double lean = 0}) async {
    for (var i = 0; i < 200; i++) {
      source!.emit(
        uprightSample(lean: lean, timestamp: Duration(milliseconds: 20 * i)),
      );
    }
    await tester.pumpAndSettle();
  }

  VialPainter painterOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(const Key('vial'))).painter!
          as VialPainter;

  tearDown(() async {
    await controller?.dispose();
    await source?.close();
    controller = null;
    source = null;
  });

  group('numeric readout', () {
    testWidgets('shows two one-decimal values when flat', (tester) async {
      await pumpPage(tester);
      await holdFlat(tester, pitch: 3.2, roll: -1.5);

      final values = tester.widgetList<AngleValue>(find.byType(AngleValue));
      expect(values.length, 2);
      expect(find.text('+3.2°'), findsOneWidget);
      expect(find.text('-1.5°'), findsOneWidget);
    });

    testWidgets('shows a single value when upright', (tester) async {
      await pumpPage(tester);
      await holdUpright(tester, lean: 2.4);

      expect(tester.widgetList<AngleValue>(find.byType(AngleValue)).length, 1);
      expect(find.text('+2.4°'), findsOneWidget);
    });

    test('formats a tiny negative reading as zero', () {
      expect(AngleValue.format(-0.01), '+0.0°');
      expect(AngleValue.format(-1.24), '-1.2°');
      expect(AngleValue.format(3.25), '+3.3°');
    });
  });

  group('level indication', () {
    testWidgets('appears within 0.2 degrees of zero', (tester) async {
      await pumpPage(tester);
      await holdFlat(tester, pitch: 0.1, roll: -0.1);

      expect(find.byKey(const Key('level-badge')), findsOneWidget);
      expect(find.text('LEVEL'), findsOneWidget);
    });

    testWidgets('disappears once an angle passes the threshold', (tester) async {
      await pumpPage(tester);
      await holdFlat(tester, pitch: 0.1);
      expect(find.byKey(const Key('level-badge')), findsOneWidget);

      await holdFlat(tester, pitch: 0.6);
      expect(find.byKey(const Key('level-badge')), findsNothing);
    });
  });

  group('vial', () {
    testWidgets('centres the bubble when the device is level', (tester) async {
      await pumpPage(tester);
      await holdFlat(tester);

      final offset = painterOf(tester).bubbleOffset(const Size(300, 300));
      expect(offset.dx, closeTo(0, 0.5));
      expect(offset.dy, closeTo(0, 0.5));
    });

    testWidgets('moves the bubble away from a raised corner', (tester) async {
      await pumpPage(tester);
      await holdFlat(tester, pitch: 5, roll: 5);

      final offset = painterOf(tester).bubbleOffset(const Size(300, 300));
      expect(offset.dx, lessThan(-10));
      expect(offset.dy, greaterThan(10));
    });

    testWidgets('keeps the bubble inside the vial past full scale',
        (tester) async {
      await pumpPage(tester);
      await holdFlat(tester, pitch: 40, roll: 40);

      const size = Size(300, 300);
      final painter = painterOf(tester);
      final travel = 150 - 150 * 0.2 - 150 * 0.05;
      expect(painter.bubbleOffset(size).distance, lessThanOrEqualTo(travel + 0.001));
    });

    testWidgets('centres the bubble when upright and plumb', (tester) async {
      await pumpPage(tester);
      await holdUpright(tester);

      final offset = painterOf(tester).bubbleOffset(const Size(300, 300));
      expect(offset.dx, closeTo(0, 0.5));
      expect(offset.dy, closeTo(0, 0.5));
    });

    testWidgets('moves the bubble left when an upright device leans right',
        (tester) async {
      await pumpPage(tester);
      await holdUpright(tester, lean: 5);

      final offset = painterOf(tester).bubbleOffset(const Size(300, 300));
      expect(offset.dx, lessThan(-10));
      expect(offset.dy, closeTo(0, 0.5));
    });

    testWidgets('morphs between the two vials as posture changes',
        (tester) async {
      await pumpPage(tester);
      await holdFlat(tester);
      expect(painterOf(tester).morph.value, 0);

      await holdUpright(tester);
      expect(painterOf(tester).morph.value, 1);

      await holdFlat(tester);
      expect(painterOf(tester).morph.value, 0);
    });

    testWidgets('animates rather than jumping between vials', (tester) async {
      await pumpPage(tester);
      await holdFlat(tester);

      for (var i = 0; i < 200; i++) {
        source!.emit(uprightSample(timestamp: Duration(milliseconds: 20 * i)));
      }
      await tester.idle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final midway = painterOf(tester).morph.value;
      expect(midway, greaterThan(0));
      expect(midway, lessThan(1));

      await tester.pumpAndSettle();
    });
  });

  group('calibration controls', () {
    testWidgets('calibrating zeroes the reading and confirms', (tester) async {
      await pumpPage(tester);
      await holdFlat(tester, pitch: 2.5, roll: 1.5);

      await tester.tap(find.byKey(const Key('calibrate-button')));
      await tester.pumpAndSettle();

      expect(find.text(calibrationSavedMessage), findsOneWidget);
      expect(find.text('+0.0°'), findsNWidgets(2));
      expect(store.stored.flatPitch, closeTo(2.5, 0.05));
    });

    testWidgets('refuses a capture on a steeply tilted surface',
        (tester) async {
      await pumpPage(tester);
      await holdFlat(tester, pitch: 15);

      await tester.tap(find.byKey(const Key('calibrate-button')));
      await tester.pumpAndSettle();

      expect(find.text(calibrationRejectedMessage), findsOneWidget);
      expect(store.saveCount, 0);
    });

    testWidgets('reset asks first and clears when confirmed', (tester) async {
      await pumpPage(tester, stored: const Calibration(flatPitch: 2));
      await holdFlat(tester, pitch: 2);
      expect(find.text('+0.0°'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('reset-button')));
      await tester.pumpAndSettle();
      expect(find.text('Reset calibration?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();

      expect(find.text(calibrationClearedMessage), findsOneWidget);
      expect(find.text('+2.0°'), findsOneWidget);
      expect(store.stored, Calibration.none);
    });

    testWidgets('reset leaves calibration alone when declined', (tester) async {
      await pumpPage(tester, stored: const Calibration(flatPitch: 2));
      await holdFlat(tester, pitch: 2);

      await tester.tap(find.byKey(const Key('reset-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(store.clearCount, 0);
      expect(find.text('+0.0°'), findsNWidgets(2));
    });
  });

  group('missing sensor', () {
    testWidgets('replaces the level with an explanation', (tester) async {
      await pumpPage(tester);
      await holdFlat(tester);
      expect(find.byKey(const Key('vial')), findsOneWidget);

      source!.emitError(const SensorUnavailableException());
      await tester.pumpAndSettle();

      expect(find.text(noSensorTitle), findsOneWidget);
      expect(find.byKey(const Key('vial')), findsNothing);
      expect(find.byType(AngleValue), findsNothing);
    });
  });
}
