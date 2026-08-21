import 'dart:async';

import 'package:flutter/services.dart';

import 'gravity_sample.dart';

/// Raised on the sample stream when the device exposes no usable tilt sensor.
class SensorUnavailableException implements Exception {
  const SensorUnavailableException();

  @override
  String toString() => 'SensorUnavailableException';
}

/// A stream of gravity vectors. The app depends on this rather than on the
/// platform channel so that tests can drive synthetic motion.
abstract class GravitySource {
  Stream<GravitySample> get samples;
}

/// Reads the Android host's gravity (or accelerometer) stream.
class PlatformGravitySource implements GravitySource {
  PlatformGravitySource();

  static const EventChannel channel =
      EventChannel('com.droque.truelevel/gravity');
  static const String noSensorCode = 'no_sensor';

  /// Sample intervals are measured on arrival rather than sent with each
  /// event, which keeps the payload to three numbers at roughly 50 Hz.
  final Stopwatch _clock = Stopwatch();

  @override
  Stream<GravitySample> get samples {
    if (!_clock.isRunning) _clock.start();
    return channel.receiveBroadcastStream().transform(
          StreamTransformer<dynamic, GravitySample>.fromHandlers(
            handleData: (event, sink) {
              final values = (event as List<Object?>).cast<num>();
              sink.add(
                GravitySample(
                  x: values[0].toDouble(),
                  y: values[1].toDouble(),
                  z: values[2].toDouble(),
                  timestamp: _clock.elapsed,
                ),
              );
            },
            handleError: (error, stackTrace, sink) {
              if (error is PlatformException && error.code == noSensorCode) {
                sink.addError(const SensorUnavailableException(), stackTrace);
              } else {
                sink.addError(error, stackTrace);
              }
            },
          ),
        );
  }
}
