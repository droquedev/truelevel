## Context

See `proposal.md` - Why. The starting point is an unmodified Flutter scaffold: `lib/main.dart` renders "Hello World!", `pubspec.yaml` has no dependencies beyond `flutter`, `flutter_test`, and `flutter_lints`, and `android/app/src/main/kotlin/com/example/bubble_level/MainActivity.kt` is the default empty `FlutterActivity`. Release builds are unminified and currently sign with the debug key.

Two constraints shape everything below. First, "super lightweight" is a hard requirement, so every dependency and every kilobyte of the release artifact must justify itself. Second, the behavior the app needs from Android - a fused gravity vector, a tiny key-value store, and a keep-screen-on window flag - is a handful of lines of platform code each, which changes the usual build-versus-depend calculus.

Requirements live in the delta specs under `specs/`; this document covers how to satisfy them.

## Goals / Non-Goals

**Goals:**

- Zero third-party pub dependencies in the shipped app; nothing beyond the Flutter SDK itself.
- A single narrow Dart/Kotlin boundary rather than one channel per feature.
- Angle math and calibration logic that is pure Dart and unit-testable without a device or sensor.
- A release APK that is small enough that the Flutter engine dominates its size.

**Non-Goals:**

- Cross-platform sensor abstraction. The platform code is written for Android only; adding iOS later means writing a second implementation behind the same Dart interface, and that is accepted.
- A general-purpose sensor or preferences layer. The channel exposes only what this app needs.
- Sensor fusion beyond what Android already provides. No gyroscope integration, no Kalman filter.

## Decisions

### Read the gravity sensor over a custom platform channel instead of adding `sensors_plus`

The obvious option is `sensors_plus`, which is well maintained and would remove the need for any Kotlin. It is rejected for two reasons. It exposes the raw accelerometer but not `TYPE_GRAVITY`, so the app would have to high-pass the accelerometer itself and would produce a noisier reading than the platform's own fused gravity signal, which many devices compute with hardware assistance. And it pulls a plugin - along with its iOS, web, Linux, macOS, and Windows implementations - into a build that only ever ships to Android.

The alternative chosen is an `EventChannel` backed by a `SensorEventListener` in the Android host. It registers `TYPE_GRAVITY` when present and falls back to `TYPE_ACCELEROMETER`, requests `SENSOR_DELAY_GAME` (roughly 50 Hz, enough headroom above the 20 Hz display requirement), and emits a three-float gravity vector. The cost is roughly 60 lines of Kotlin plus listener lifecycle handling; the benefit is a better signal and no dependency.

Sensor registration follows the Flutter engine's lifecycle rather than the channel's: the listener registers on `onListen` but also unregisters in `onPause` and re-registers in `onResume`, which is what satisfies the foreground-only requirement in `level-sensing`.

### One `MethodChannel` for calibration storage and the screen-awake flag

Persisting calibration would normally mean `shared_preferences`, and keeping the screen on would mean `wakelock_plus`. Both are single-purpose plugins wrapping an API that is one call away on the native side. Instead a single `MethodChannel` named `com.droque.truelevel/host` exposes four methods: `loadCalibration`, `saveCalibration`, `clearCalibration`, and `setKeepScreenOn`. The first three read and write three stored offsets - flat pitch, flat roll, and the upright in-plane angle - in the activity's `SharedPreferences`; the last toggles `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON`.

The alternative of writing a JSON file through `dart:io` was rejected because locating a writable directory portably is exactly what `path_provider` exists for, which puts a dependency back into the build.

### Angle math is pure Dart, fed by an injectable stream

Android reports gravity in a frame where `x` points at the right edge, `y` at the top edge, and `z` out of the screen, and a device lying flat and face up reads `(0, 0, +9.81)`. In that frame the gravity vector `(x, y, z)` converts to angles with `pitch = atan2(y, sqrt(x² + z²))` and `roll = atan2(x, sqrt(y² + z²))` in flat posture, which gives the signs `level-sensing` requires: pitch positive when the top edge is raised, roll positive when the right edge is raised. For a device on edge the in-plane angle is `atan2(-x, y)`, which reads zero when plumb and positive when the device leans right. Posture comes from the angle between the screen normal and vertical, `acos(|z| / |g|)`, with the 50/60-degree hysteresis band the spec requires.

All of this lives in plain Dart functions and a controller that consumes a `Stream<GravitySample>`. The platform channel is one implementation of that stream; tests supply a synthetic one. This is what makes the specs' numeric scenarios - settling time, noise band, hysteresis, calibration offsets - testable in `flutter test` with no device attached.

### Exponential smoothing rather than a moving average

A first-order low-pass filter, `out = out + alpha * (in - out)`, holds one float of state per axis and has no window to allocate. With samples arriving near 50 Hz, `alpha` around 0.15 puts the settling time near 250 ms, comfortably inside the spec's 500 ms while keeping a stationary device inside the 0.2-degree band. Alpha is derived from the measured sample interval rather than hardcoded per frame, so devices that deliver samples at a different rate behave the same. A moving average would smooth slightly better for the same lag but needs a ring buffer and gives no benefit worth the state.

### Bubble rendered with `CustomPainter`, driven by animation rather than raw sensor events

The vials, index marks, and bubble are drawn in a single `CustomPainter`. This avoids widget-tree churn, keeps the whole UI to a handful of widgets, and makes the flat-to-upright transition a matter of interpolating one animation value between two painted layouts.

The painter is repainted from a `ValueListenable` updated by the sensor stream, so sensor updates never rebuild the widget tree - they only repaint the canvas. Bubble displacement maps tilt to vial offset linearly with a 10-degree full scale and clamps at the vial's inner radius.

Portrait lock uses `SystemChrome.setPreferredOrientations`, which needs no platform code.

### Release build shrinks and splits

`android/app/build.gradle.kts` enables `isMinifyEnabled` and `isShrinkResources` on the release build type. Distribution assumes an app bundle so that ABI and density splitting happen at install time; an `--split-per-abi` APK build is documented as the fallback for sideloading, since a universal APK carries every ABI's copy of the engine.

**Measured footprint.** Per-ABI release APKs come out at 12.2 MB for armeabi-v7a, 14.8 MB for arm64-v8a, and 16.2 MB for x86_64; the universal APK and the app bundle both land at 42.5 MB because each carries all three copies of the engine, which is exactly why distribution goes through the bundle. Inside the arm64 APK, `libflutter.so` accounts for 11.7 MB and `libapp.so` for 3.4 MB, while everything the app itself contributes - all of its Kotlin plus androidx - fits in a 524 KB `classes.dex`. The engine dominates as intended and the app adds no measurable weight of its own.

The signed bundle is 44.7 MB, but roughly 58 MB of that file is `BUNDLE-METADATA` debug symbols and the ProGuard mapping, which Play keeps for crash symbolication and never delivers to a device. `flutter build appbundle` reports "failed to strip debug symbols" on this machine only because the check needs `apkanalyzer` from the Android cmdline-tools, which is not installed; the `.so.sym` entries it looks for are in fact present, so the delivered libraries are stripped.

## Risks / Trade-offs

- **Hand-written platform code has to handle lifecycle correctly, and a leaked `SensorEventListener` drains the battery** → Registration and unregistration are paired in `onResume`/`onPause` and in the `EventChannel` handler's `onCancel`, and the listener is the only piece of mutable state in the activity. A manual check that the reading stops when the app is backgrounded is called out in the tasks.
- **Fallback to the raw accelerometer produces a noisier reading than the gravity sensor** → The same smoothing filter runs on both paths, and the accelerometer path only matters on devices that lack a gravity sensor, which are rare. Behavior is otherwise identical, as `level-sensing` requires.
- **Absolute accuracy is bounded by the sensor's own bias, not by the app** → This is why calibration exists. The specs' accuracy scenarios are written against a 1.0-degree tolerance for uncalibrated readings, and the level indication threshold of 0.2 degrees is a relative measure against the calibrated zero.
- **Writing the Kotlin host by hand costs more implementation time than adding two pub packages** → Accepted deliberately; it is the direct cost of the lightweight goal, and the surface is small enough (about 120 lines total) to review in one sitting.
- **Portrait lock makes the app awkward in landscape** → Intentional. A level that re-orients while being tilted is unusable, and the specs require the orientation to stay fixed.
- **`minifyEnabled` can strip code reached only reflectively** → The Flutter Gradle plugin supplies the engine's ProGuard rules; the app's own Kotlin uses no reflection. A release-build smoke test on a device is part of the task list.

## Migration Plan

Not applicable. Nothing is deployed and there are no existing users or stored data; the change replaces a scaffold. The only removal is the placeholder `MainApp` widget in `lib/main.dart`.
