import 'package:flutter/services.dart';

/// The app's only method-call boundary to Android: calibration storage and the
/// keep-screen-on window flag.
class HostBridge {
  const HostBridge();

  static const MethodChannel channel =
      MethodChannel('com.droque.truelevel/host');

  /// Returns the stored offsets, or null when nothing has been calibrated yet.
  Future<Map<String, double>?> loadCalibration() =>
      channel.invokeMapMethod<String, double>('loadCalibration');

  Future<void> saveCalibration(Map<String, double> offsets) =>
      channel.invokeMethod<void>('saveCalibration', offsets);

  Future<void> clearCalibration() =>
      channel.invokeMethod<void>('clearCalibration');

  Future<void> setKeepScreenOn(bool enabled) =>
      channel.invokeMethod<void>('setKeepScreenOn', enabled);
}
