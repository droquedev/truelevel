import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../level/level_reading.dart';

/// Maps tilt angles onto bubble positions inside a vial.
class VialGeometry {
  const VialGeometry._();

  /// The tilt that pushes the bubble all the way to the edge of the vial.
  static const double fullScaleDegrees = 10;

  static double fraction(double degrees) =>
      (degrees / fullScaleDegrees).clamp(-1.0, 1.0);

  /// The bubble sits away from the raised side, so a raised top-right corner
  /// pushes it toward the bottom left of the vial.
  static Offset flatBubbleOffset({
    required double pitch,
    required double roll,
    required double travel,
  }) {
    final offset = Offset(-fraction(roll) * travel, fraction(pitch) * travel);
    final distance = offset.distance;
    if (distance <= travel || distance == 0) return offset;
    return offset * (travel / distance);
  }

  /// A device leaning right sends the bubble to the left of the vial.
  static Offset uprightBubbleOffset({
    required double tilt,
    required double travel,
  }) =>
      Offset(-fraction(tilt) * travel, 0);
}

/// Colors the vial is drawn with, taken from the app's color scheme.
@immutable
class VialPalette {
  const VialPalette({
    required this.surface,
    required this.outline,
    required this.marks,
    required this.bubble,
    required this.accent,
  });

  factory VialPalette.from(ColorScheme scheme) => VialPalette(
        surface: scheme.surfaceContainerHighest,
        outline: scheme.outlineVariant,
        marks: scheme.outline,
        bubble: scheme.primary,
        accent: scheme.tertiary,
      );

  final Color surface;
  final Color outline;
  final Color marks;
  final Color bubble;
  final Color accent;

  @override
  bool operator ==(Object other) =>
      other is VialPalette &&
      other.surface == surface &&
      other.outline == outline &&
      other.marks == marks &&
      other.bubble == bubble &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(surface, outline, marks, bubble, accent);
}

class _VialMetrics {
  const _VialMetrics({
    required this.center,
    required this.halfWidth,
    required this.halfHeight,
    required this.bubbleRadius,
    required this.travelX,
    required this.travelY,
  });

  final Offset center;
  final double halfWidth;
  final double halfHeight;
  final double bubbleRadius;
  final double travelX;
  final double travelY;
}

/// Draws the vial and its bubble.
///
/// The painter repaints from the reading notifier and the morph animation
/// directly, so a stream of sensor samples never rebuilds the widget tree.
class VialPainter extends CustomPainter {
  VialPainter({
    required this.reading,
    required this.morph,
    required this.palette,
  }) : super(repaint: Listenable.merge(<Listenable>[reading, morph]));

  /// 0 draws the circular two-axis vial, 1 the elongated single-axis vial.
  final Animation<double> morph;
  final ValueListenable<LevelReading?> reading;
  final VialPalette palette;

  static const double _bubbleRadiusFactor = 0.2;
  static const double _insetFactor = 0.05;
  static const double _uprightHeightFactor = 3.0;

  /// Where the bubble sits relative to the middle of the vial. Exposed so the
  /// mapping can be checked without rasterizing the canvas.
  Offset bubbleOffset(Size size) => _bubbleOffset(_metricsFor(size));

  _VialMetrics _metricsFor(Size size) {
    final t = morph.value;
    final halfWidth = math.min(size.width, size.height) / 2;
    final bubbleRadius = halfWidth * _bubbleRadiusFactor;
    final inset = halfWidth * _insetFactor;
    final uprightHalfHeight = bubbleRadius * _uprightHeightFactor / 2 + inset;
    final halfHeight = halfWidth + (uprightHalfHeight - halfWidth) * t;

    return _VialMetrics(
      center: size.center(Offset.zero),
      halfWidth: halfWidth,
      halfHeight: halfHeight,
      bubbleRadius: bubbleRadius,
      travelX: math.max(0, halfWidth - bubbleRadius - inset),
      travelY: math.max(0, halfHeight - bubbleRadius - inset),
    );
  }

  Offset _bubbleOffset(_VialMetrics metrics) {
    final value = reading.value;
    if (value == null) return Offset.zero;

    final flat = VialGeometry.flatBubbleOffset(
      pitch: value.pitch,
      roll: value.roll,
      travel: metrics.travelX,
    );
    final upright = VialGeometry.uprightBubbleOffset(
      tilt: value.uprightTilt,
      travel: metrics.travelX,
    );

    final t = morph.value;
    return Offset(
      flat.dx + (upright.dx - flat.dx) * t,
      (flat.dy * (1 - t)).clamp(-metrics.travelY, metrics.travelY),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = _metricsFor(size);
    final level = reading.value?.isLevel ?? false;
    final t = morph.value;

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: metrics.center,
        width: metrics.halfWidth * 2,
        height: metrics.halfHeight * 2,
      ),
      Radius.circular(metrics.halfHeight),
    );

    canvas.drawRRect(body, Paint()..color = palette.surface);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = level ? 5 : 2
        ..color = level ? palette.accent : palette.outline,
    );

    _paintFlatMarks(canvas, metrics, 1 - t);
    _paintUprightMarks(canvas, metrics, t);
    _paintBubble(canvas, metrics, level);
  }

  void _paintFlatMarks(Canvas canvas, _VialMetrics metrics, double opacity) {
    if (opacity <= 0.01) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = palette.marks.withValues(alpha: opacity * 0.8);

    canvas.drawCircle(metrics.center, metrics.bubbleRadius, paint);
    canvas.drawCircle(metrics.center, metrics.travelX * 0.55, paint);

    final tick = metrics.bubbleRadius * 0.5;
    for (final direction in <Offset>[
      const Offset(1, 0),
      const Offset(-1, 0),
      const Offset(0, 1),
      const Offset(0, -1),
    ]) {
      final outer = metrics.center + direction * metrics.halfWidth;
      canvas.drawLine(outer, outer - direction * tick, paint);
    }
  }

  void _paintUprightMarks(Canvas canvas, _VialMetrics metrics, double opacity) {
    if (opacity <= 0.01) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = palette.marks.withValues(alpha: opacity * 0.8);

    for (final side in <double>[-1, 1]) {
      final x = metrics.center.dx + side * metrics.bubbleRadius;
      canvas.drawLine(
        Offset(x, metrics.center.dy - metrics.halfHeight),
        Offset(x, metrics.center.dy + metrics.halfHeight),
        paint,
      );
    }
  }

  void _paintBubble(Canvas canvas, _VialMetrics metrics, bool level) {
    final center = metrics.center + _bubbleOffset(metrics);
    final color = level ? palette.accent : palette.bubble;

    canvas.drawCircle(
      center,
      metrics.bubbleRadius,
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      center,
      metrics.bubbleRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = level ? 3.5 : 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant VialPainter oldDelegate) =>
      oldDelegate.reading != reading ||
      oldDelegate.morph != morph ||
      oldDelegate.palette != palette;
}
