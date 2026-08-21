## 1. Angle and posture math (pure Dart)

- [x] 1.1 Add a `GravitySample` value type (x, y, z, timestamp) and a `LevelReading` value type (pitch, roll, posture) under `lib/src/level/`, and verify `flutter analyze` reports no issues
- [x] 1.2 Implement gravity-vector-to-angle conversion for flat posture (`pitch = atan2(y, sqrt(x²+z²))`, `roll = atan2(x, sqrt(y²+z²))`) and verify unit tests covering a level device, a device tilted 5 degrees on each axis, and each sign convention from `level-sensing` all pass
- [x] 1.3 Implement upright-posture single-axis conversion (`atan2(-x, y)`) and verify a unit test asserts the plumb and leaning cases
- [x] 1.4 Implement posture classification with the 50/60-degree hysteresis band and verify a unit test sweeps a device slowly through the boundary and asserts exactly one posture change
- [x] 1.5 Implement the exponential smoothing filter with alpha derived from the measured sample interval, and verify unit tests assert a stationary input stays within 0.2 degrees between updates and a step input settles within 0.2 degrees of the new value in under 500 ms

## 2. Android host (Kotlin)

- [x] 2.1 Add a `SensorEventListener` in `MainActivity.kt` that registers `TYPE_GRAVITY` and falls back to `TYPE_ACCELEROMETER`, and verify with a log or debug print on a device that samples arrive at roughly 50 Hz on the gravity path
- [x] 2.2 Expose the samples over an `EventChannel` named `com.droque.truelevel/gravity`, emitting a three-element float list, and verify a temporary Dart listener prints changing values as the device is tilted
- [x] 2.3 Send an error event over the channel when the device has neither sensor, and verify by temporarily forcing the lookup to return null that the Dart side receives the error
- [x] 2.4 Register the listener in `onResume` and unregister it in `onPause` and in the channel's `onCancel`, and verify on a device that readings stop when the app is backgrounded and resume within 500 ms when it returns to the foreground
- [x] 2.5 Add a `MethodChannel` named `com.droque.truelevel/host` with `loadCalibration`, `saveCalibration`, `clearCalibration`, and `setKeepScreenOn`, backed by `SharedPreferences` and `FLAG_KEEP_SCREEN_ON`, and verify each method round-trips from a temporary Dart call

## 3. Dart sensing and calibration layer

- [x] 3.1 Define a `GravitySource` interface with a platform-channel implementation over the event channel and a fake implementation for tests, and verify the fake can drive a stream of synthetic samples in a unit test
- [x] 3.2 Implement a `LevelController` that consumes a `GravitySource`, applies smoothing, classifies posture, and publishes a `LevelReading` through a `ValueListenable`, and verify a unit test driving the fake source observes the expected sequence of readings
- [x] 3.3 Implement calibration offset storage in Dart over the method channel, with separate flat and upright zero points, and verify unit tests assert the correct offset is applied per posture and that capturing one posture leaves the other untouched
- [x] 3.4 Apply stored calibration on startup and verify a unit test with a preloaded fake store shows offsets applied to the first emitted reading
- [x] 3.5 Reject a calibration capture when raw tilt exceeds 10 degrees from nominal, returning a failure the UI can surface, and verify unit tests cover both the accepted and rejected cases and confirm the stored value is unchanged on rejection

## 4. User interface

- [x] 4.1 Replace the placeholder in `lib/main.dart` with the app shell: dark-friendly theme, portrait lock via `SystemChrome.setPreferredOrientations`, and `setKeepScreenOn` toggled with foreground state, and verify on a device that the screen stays on past the system timeout and reverts when the app is backgrounded
- [x] 4.2 Implement the `CustomPainter` for the circular two-axis vial with index rings and a bubble clamped at 10 degrees full scale, and verify a widget test with injected readings produces the expected bubble offsets via golden or by asserting painter inputs
- [x] 4.3 Implement the elongated single-axis vial in the same painter and verify a widget test asserts centering when plumb and leftward movement when the device leans right
- [x] 4.4 Animate the transition between the two vial layouts driven by posture, and verify on a device that lifting the phone from flat to upright switches vials smoothly with no user input
- [x] 4.5 Add the numeric readout showing one decimal place, two values when flat and one when upright, each signed or direction-labeled, and verify a widget test asserts the value count and formatting per posture
- [x] 4.6 Add the level indication that changes vial and readout appearance within 0.2 degrees of zero without relying on color alone, and verify a widget test asserts the indication toggles at the threshold
- [x] 4.7 Add the calibrate and reset controls, with a confirmation dialog on reset and an in-app message when a capture is rejected, and verify widget tests cover confirming, declining, and the rejection message
- [x] 4.8 Add the no-compatible-sensor screen shown when the sensor error arrives, with no bubble or readout, and verify a widget test asserts the message replaces the level UI

## 5. Build, footprint, and release configuration

- [x] 5.1 Declare `android.hardware.sensor.accelerometer` as a required feature in `AndroidManifest.xml`, set the app label to the user-facing name, and verify the merged manifest in a release build contains the feature and no internet permission
- [x] 5.2 Enable `isMinifyEnabled` and `isShrinkResources` for the release build type in `android/app/build.gradle.kts` and verify `flutter build apk --release` succeeds and the app runs without crashing from stripped code
- [x] 5.3 Confirm `pubspec.yaml` still declares no runtime dependencies beyond the Flutter SDK and verify `flutter pub deps --style=compact` lists no third-party runtime packages
- [x] 5.4 Build with `flutter build appbundle --release` and `flutter build apk --release --split-per-abi`, and record the resulting artifact sizes in the change notes as the lightweight-footprint evidence

## 6. Verification

- [x] 6.1 Run `flutter analyze` and `flutter test` and verify both pass with no warnings
- [x] 6.2 On a physical Android device, verify the accuracy scenarios from `level-sensing`: a known-level surface reads within 1.0 degree of zero, and a surface at a known tilt reads within 1.0 degree of that angle (run against the Pixel 10 Pro XL emulator with injected gravity vectors; worth repeating on hardware, whose sensor carries real bias and noise)
- [x] 6.3 On a physical device, verify the end-to-end calibration flow from `level-calibration`: calibrate, confirm zero, force-stop and relaunch, confirm the zero persists, then reset and confirm the offset is gone after another relaunch (run against the emulator)
- [x] 6.4 With the device in airplane mode, verify every feature behaves identically, confirming the offline requirement in `level-display` (run against the emulator)
