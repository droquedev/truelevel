import 'package:flutter/material.dart';

import '../level/level_controller.dart';
import '../level/level_reading.dart';
import 'vial_painter.dart';

const String calibrationSavedMessage = 'Zero point saved for this position.';
const String calibrationRejectedMessage =
    'This surface is too far from level to use as a reference.';
const String calibrationClearedMessage = 'Calibration cleared.';
const String noReadingMessage = 'Waiting for a reading from the sensor.';
const String noSensorTitle = 'No compatible tilt sensor';

class LevelPage extends StatefulWidget {
  const LevelPage({required this.controller, super.key});

  final LevelController controller;

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final CurvedAnimation _morphCurve = CurvedAnimation(
    parent: _morph,
    curve: Curves.easeInOut,
  );

  double _morphTarget = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.reading.addListener(_followPosture);
    _followPosture();
  }

  @override
  void dispose() {
    widget.controller.reading.removeListener(_followPosture);
    _morphCurve.dispose();
    _morph.dispose();
    super.dispose();
  }

  void _followPosture() {
    final reading = widget.controller.reading.value;
    if (reading == null) return;

    final target = reading.posture == DevicePosture.upright ? 1.0 : 0.0;
    if (target == _morphTarget) return;
    _morphTarget = target;
    _morph.animateTo(target);
  }

  Future<void> _calibrate() async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await widget.controller.calibrate();
    if (!mounted) return;

    final message = switch (outcome) {
      CalibrationOutcome.captured => calibrationSavedMessage,
      CalibrationOutcome.rejectedTooSteep => calibrationRejectedMessage,
      CalibrationOutcome.noReading => noReadingMessage,
    };
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reset() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset calibration?'),
        content: const Text(
          'The level will go back to raw sensor readings with no zero point '
          'applied.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.controller.resetCalibration();
    if (!mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text(calibrationClearedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.controller.sensorUnavailable,
          builder: (context, unavailable, _) =>
              unavailable ? const _NoSensorView() : _buildLevel(context),
        ),
      ),
    );
  }

  Widget _buildLevel(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AspectRatio(
                aspectRatio: 1,
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('vial'),
                    painter: VialPainter(
                      reading: widget.controller.reading,
                      morph: _morphCurve,
                      palette: VialPalette.from(Theme.of(context).colorScheme),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder<LevelReading?>(
          valueListenable: widget.controller.reading,
          builder: (context, reading, _) => _Readout(reading: reading),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FilledButton.icon(
                key: const Key('calibrate-button'),
                onPressed: _calibrate,
                icon: const Icon(Icons.adjust),
                label: const Text('Calibrate'),
              ),
              const SizedBox(width: 12),
              TextButton(
                key: const Key('reset-button'),
                onPressed: _reset,
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.reading});

  final LevelReading? reading;

  @override
  Widget build(BuildContext context) {
    final value = reading;
    if (value == null) {
      return const SizedBox(
        height: 96,
        child: Center(child: Text(noReadingMessage)),
      );
    }

    final angles = value.posture == DevicePosture.flat
        ? <AngleValue>[
            AngleValue(label: 'PITCH', degrees: value.pitch),
            AngleValue(label: 'ROLL', degrees: value.roll),
          ]
        : <AngleValue>[AngleValue(label: 'TILT', degrees: value.uprightTilt)];

    return SizedBox(
      height: 96,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (final angle in angles)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: angle,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _LevelBadge(isLevel: value.isLevel),
        ],
      ),
    );
  }
}

/// One angle in the readout, shown signed so the direction of the tilt is
/// readable without interpreting the bubble.
class AngleValue extends StatelessWidget {
  const AngleValue({required this.label, required this.degrees, super.key});

  final String label;
  final double degrees;

  static String format(double degrees) {
    final value = degrees.abs() < 0.05 ? 0.0 : degrees;
    final sign = value < 0 ? '-' : '+';
    return '$sign${value.abs().toStringAsFixed(1)}°';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
        ),
        Text(
          format(degrees),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// The level indication. It changes shape and adds a label rather than only
/// changing color, so it reads without relying on color perception.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.isLevel});

  final bool isLevel;

  @override
  Widget build(BuildContext context) {
    if (!isLevel) return const SizedBox(height: 28);

    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('level-badge'),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 6),
          Text(
            'LEVEL',
            style: TextStyle(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSensorView extends StatelessWidget {
  const _NoSensorView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      key: const Key('no-sensor'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.sensors_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(noSensorTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'This device does not report gravity or acceleration, so it '
              'cannot be used as a level.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
