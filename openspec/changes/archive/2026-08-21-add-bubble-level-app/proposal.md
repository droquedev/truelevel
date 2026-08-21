## Why

The repository is an empty Flutter scaffold ("Hello World!") with a stated goal of shipping a bubble (spirit) level for Android. Most bubble level apps on the Play Store are ad-supported, request unnecessary permissions, and ship tens of megabytes of SDKs for a tool that only needs one hardware sensor and a handful of trigonometry. This change defines a complete, ad-free, dependency-free bubble level that does one job accurately and installs small.

## What Changes

- Read device tilt directly from Android hardware (gravity sensor, with accelerometer fallback) and convert it to pitch and roll angles.
- Display a 2D bubble vial when the device lies flat and a single-axis vial when it is held upright or on edge, switching automatically based on measured orientation.
- Show a numeric angle readout in degrees alongside the bubble, and indicate clearly when the surface is level within tolerance.
- Let the user calibrate a zero point against a known-flat surface and reset it; the offset persists across app launches.
- Keep the screen on and the orientation locked to portrait while the app is in the foreground.
- Ship with no ads, no analytics, no network access, and no runtime permissions.
- Replace the placeholder `lib/main.dart` scaffold with the real app.

### Assumptions

Clarifying questions on scope were not answered before planning, so the following are recorded as decisions rather than open questions. They can be revised before implementation starts.

- Android only; iOS and web are out of scope for this change.
- Angles are reported in degrees only.
- No third-party pub packages are added; sensor access, calibration storage, and screen-awake behavior are all handled through a platform channel or existing Flutter/Android APIs.

## Capabilities

### New Capabilities

- `level-sensing`: Acquiring gravity/acceleration samples from Android hardware, smoothing them, and deriving pitch and roll angles plus a device posture (flat vs. upright).
- `level-display`: Rendering the bubble vials, numeric readout, level indication, and automatic mode switching, plus app-shell behavior (portrait lock, screen awake, theme).
- `level-calibration`: Capturing, applying, persisting, and clearing a user zero-point offset.

### Modified Capabilities

None. The project has no existing specs.

## Impact

- **Code**: `lib/main.dart` is replaced; new Dart source under `lib/` for sensing, calibration, and UI. New Kotlin code in `android/app/src/main/kotlin/com/droque/truelevel/` for the sensor event channel, calibration storage, and the keep-screen-on flag.
- **Build config**: `android/app/build.gradle.kts` gains release shrinking/minification settings and an ABI-split or app-bundle configuration to keep the artifact small. `AndroidManifest.xml` declares the accelerometer hardware feature as required.
- **Dependencies**: None added to `pubspec.yaml`. `flutter_lints` and `flutter_test` remain the only dev dependencies.
- **Permissions/network**: None requested; no `INTERNET` permission.
- **Testing**: New unit tests for the angle math, smoothing, posture selection, and calibration offset logic; widget tests for the display driven by injected sensor values.
