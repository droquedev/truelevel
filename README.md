# TrueLevel

An ad-free bubble level for Android, built with Flutter.

TrueLevel reads the device's gravity sensor directly through a platform channel and
ships with no third-party packages, no ads, no analytics, and no network access.
It shows a two-axis bubble when the phone lies flat and a single-axis vial when it
is held on edge, switching automatically, and lets you calibrate a zero point
against a surface you trust.

- Application ID: `com.droque.truelevel`
- Minimum Android version: API 24

## Building

```bash
flutter test
flutter build appbundle --release
```

Release builds need `android/key.properties` and the upload keystore it points
at; neither is in version control. Without them the release build falls back to
the debug key, which Play will not accept.

## Store artwork

The launcher icon and the Play listing images are drawn from the app's own
color scheme rather than kept as loose bitmaps:

```bash
flutter test tool/generate_store_assets.dart
java tool/FlattenPng.java store/feature_graphic.png
```

The second step strips the alpha channel, which Play rejects on the feature
graphic and on screenshots.
