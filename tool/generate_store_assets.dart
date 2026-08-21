// Draws the launcher icon and the Play Store artwork from the same color
// scheme the app itself uses, so they cannot drift away from the UI. Vector
// drawing also gives a crisp result at every density instead of resampling one
// bitmap.
//
// Run it with:
//
//   flutter test tool/generate_store_assets.dart
//   java tool/FlattenPng.java store/feature_graphic.png
//
// The second step matters: Play rejects a feature graphic that carries an
// alpha channel, and everything dart:ui encodes is RGBA.
//
// This lives outside test/ so a normal `flutter test` run does not rewrite the
// artwork.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Density buckets Android expects, as multipliers of the baseline size.
const Map<String, double> _densities = <String, double>{
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

/// The emblem stays inside this fraction of an adaptive layer. Android only
/// guarantees the central 66 of 108 dp survives every launcher mask.
const double _adaptiveEmblem = 66 / 108;

/// Legacy icons are shown unmasked on the API 24-25 devices that still use
/// them, so the emblem can sit closer to the edge.
const double _legacyEmblem = 0.78;

const String _resDir = 'android/app/src/main/res';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate store assets', () async {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3DDC84),
      brightness: Brightness.dark,
    );

    for (final MapEntry<String, double> density in _densities.entries) {
      final double scale = density.value;

      await _write(
        '$_resDir/mipmap-${density.key}/ic_launcher.png',
        Size.square(48 * scale),
        (Canvas canvas, Size size) {
          _paintBackground(canvas, size, scheme, cornerRadius: size.width * 0.2);
          _paintEmblem(
            canvas,
            size.center(Offset.zero),
            scheme,
            extent: size.width * _legacyEmblem,
          );
        },
      );

      await _write(
        '$_resDir/mipmap-${density.key}/ic_launcher_foreground.png',
        Size.square(108 * scale),
        (Canvas canvas, Size size) => _paintEmblem(
          canvas,
          size.center(Offset.zero),
          scheme,
          extent: size.width * _adaptiveEmblem,
        ),
      );

      await _write(
        '$_resDir/mipmap-${density.key}/ic_launcher_monochrome.png',
        Size.square(108 * scale),
        (Canvas canvas, Size size) => _paintEmblem(
          canvas,
          size.center(Offset.zero),
          scheme,
          extent: size.width * _adaptiveEmblem,
          monochrome: true,
        ),
      );
    }

    // Play requires a 512px square icon; it applies its own rounding.
    await _write('store/play_store_icon.png', const Size.square(512), (
      Canvas canvas,
      Size size,
    ) {
      _paintBackground(canvas, size, scheme, cornerRadius: 0);
      _paintEmblem(
        canvas,
        size.center(Offset.zero),
        scheme,
        extent: size.width * 0.72,
      );
    });

    await _loadRoboto();
    await _write(
      'store/feature_graphic.png',
      const Size(1024, 500),
      (Canvas canvas, Size size) => _paintFeatureGraphic(canvas, size, scheme),
    );

    _writeBackgroundColor(scheme.surface);
  });
}

void _paintBackground(
  Canvas canvas,
  Size size,
  ColorScheme scheme, {
  required double cornerRadius,
}) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cornerRadius),
    ),
    Paint()..color = scheme.surface,
  );
}

/// The side-on tube of a classic spirit level, bubble dead centre - the
/// flat-and-level state, which is the one worth advertising.
void _paintEmblem(
  Canvas canvas,
  Offset center,
  ColorScheme scheme, {
  required double extent,
  bool monochrome = false,
}) {
  // A rectangle has to shrink to survive a circular launcher mask.
  final double width = extent * 0.92;
  final double halfWidth = width / 2;
  final double halfHeight = width * 0.21;
  final Color accent = monochrome ? Colors.white : scheme.primary;

  final RRect body = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: center,
      width: halfWidth * 2,
      height: halfHeight * 2,
    ),
    Radius.circular(halfHeight),
  );

  if (!monochrome) {
    canvas.drawRRect(body, Paint()..color = scheme.surfaceContainerHighest);
  }
  canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.07
      ..color = accent,
  );

  final Paint markPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * 0.035
    ..strokeCap = StrokeCap.round
    ..color = (monochrome ? Colors.white : scheme.outline)
        .withValues(alpha: monochrome ? 0.55 : 0.9);

  for (final double side in <double>[-1, 1]) {
    final double x = center.dx + side * halfHeight * 1.35;
    canvas.drawLine(
      Offset(x, center.dy - halfHeight * 0.62),
      Offset(x, center.dy + halfHeight * 0.62),
      markPaint,
    );
  }

  canvas.drawCircle(center, halfHeight * 0.62, Paint()..color = accent);
}

/// The 1024x500 banner at the top of the store listing. Play crops the edges
/// in some placements, so the whole lockup stays near the middle.
void _paintFeatureGraphic(Canvas canvas, Size size, ColorScheme scheme) {
  final Rect bounds = Offset.zero & size;

  canvas.drawRect(
    bounds,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF17281D), Color(0xFF0A0F0B)],
      ).createShader(bounds),
  );

  final double emblemExtent = size.height * 0.52;
  final TextPainter title = _text('TrueLevel', 78, FontWeight.w600, Colors.white);
  final TextPainter tagline = _text(
    'Ad-free bubble level',
    32,
    FontWeight.w400,
    scheme.primary,
  );

  const double gap = 52;
  final double textWidth = title.width > tagline.width
      ? title.width
      : tagline.width;
  final double lockupWidth = emblemExtent + gap + textWidth;
  final double left = (size.width - lockupWidth) / 2;
  final Offset emblemCenter = Offset(
    left + emblemExtent / 2,
    size.height / 2,
  );

  // A soft glow keeps the banner off a flat near-black, which reads as dead
  // space in the store's browse rows.
  canvas.drawCircle(
    emblemCenter,
    emblemExtent,
    Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          scheme.primary.withValues(alpha: 0.16),
          scheme.primary.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: emblemCenter, radius: emblemExtent),
      ),
  );

  _paintEmblem(canvas, emblemCenter, scheme, extent: emblemExtent);

  final double textLeft = left + emblemExtent + gap;
  final double blockHeight = title.height + 14 + tagline.height;
  final double top = (size.height - blockHeight) / 2;
  title.paint(canvas, Offset(textLeft, top));
  tagline.paint(canvas, Offset(textLeft, top + title.height + 14));
}

TextPainter _text(String value, double size, FontWeight weight, Color color) {
  return TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

/// `flutter test` ships a placeholder font that renders every glyph as a box,
/// so real type has to be registered before any text is drawn. Roboto is in
/// the engine cache next to the test binary.
Future<void> _loadRoboto() async {
  Directory? directory = File(Platform.resolvedExecutable).parent;
  Directory? fonts;
  while (fonts == null && directory!.path != directory.parent.path) {
    final Directory candidate = Directory(
      '${directory.path}/artifacts/material_fonts',
    );
    if (candidate.existsSync()) {
      fonts = candidate;
    }
    directory = directory.parent;
  }
  if (fonts == null) {
    throw StateError('Could not find material_fonts in the Flutter cache.');
  }

  final FontLoader loader = FontLoader('Roboto');
  for (final String name in <String>[
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]) {
    final File file = File('${fonts.path}/$name');
    if (file.existsSync()) {
      loader.addFont(
        Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await loader.load();
}

Future<void> _write(
  String path,
  Size size,
  void Function(Canvas canvas, Size size) paint,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  paint(Canvas(recorder), size);
  final ui.Image image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $path (${size.width.round()}x${size.height.round()})');
}

void _writeBackgroundColor(Color color) {
  final String hex = (color.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();
  File('$_resDir/values/ic_launcher_background.xml').writeAsStringSync(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <color name="ic_launcher_background">#FF$hex</color>\n'
    '</resources>\n',
  );
  // ignore: avoid_print
  print('background #FF$hex');
}
