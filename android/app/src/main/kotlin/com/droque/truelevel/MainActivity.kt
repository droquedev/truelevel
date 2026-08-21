package com.droque.truelevel

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val GRAVITY_CHANNEL = "com.droque.truelevel/gravity"
private const val HOST_CHANNEL = "com.droque.truelevel/host"
private const val PREFS_NAME = "truelevel"
private const val KEY_FLAT_PITCH = "flatPitch"
private const val KEY_FLAT_ROLL = "flatRoll"
private const val KEY_UPRIGHT = "upright"
private const val NO_SENSOR_CODE = "no_sensor"

/**
 * Hosts the two channels the app needs from Android: a stream of gravity
 * vectors, and a small method channel for calibration storage and the
 * keep-screen-on window flag. Using the platform directly keeps the app free
 * of sensor, preferences, and wakelock plugins.
 */
class MainActivity : FlutterActivity() {
    private var sensorManager: SensorManager? = null
    private var tiltSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private var listening = false

    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            eventSink?.success(
                listOf(
                    event.values[0].toDouble(),
                    event.values[1].toDouble(),
                    event.values[2].toDouble(),
                )
            )
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val manager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        sensorManager = manager
        // The fused gravity signal is steadier than raw acceleration; the
        // accelerometer is only a fallback for devices that lack it.
        tiltSensor = manager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
            ?: manager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, GRAVITY_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    if (tiltSensor == null) {
                        events.error(
                            NO_SENSOR_CODE,
                            "This device has no gravity or accelerometer sensor.",
                            null,
                        )
                        return
                    }
                    eventSink = events
                    startListening()
                }

                override fun onCancel(arguments: Any?) {
                    stopListening()
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HOST_CHANNEL)
            .setMethodCallHandler { call, result -> handleHostCall(call, result) }
    }

    private fun handleHostCall(call: MethodCall, result: MethodChannel.Result) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        when (call.method) {
            "loadCalibration" -> {
                if (!prefs.contains(KEY_FLAT_PITCH) && !prefs.contains(KEY_UPRIGHT)) {
                    result.success(null)
                } else {
                    result.success(
                        mapOf(
                            KEY_FLAT_PITCH to prefs.getFloat(KEY_FLAT_PITCH, 0f).toDouble(),
                            KEY_FLAT_ROLL to prefs.getFloat(KEY_FLAT_ROLL, 0f).toDouble(),
                            KEY_UPRIGHT to prefs.getFloat(KEY_UPRIGHT, 0f).toDouble(),
                        )
                    )
                }
            }

            "saveCalibration" -> {
                val values = call.arguments as? Map<*, *>
                if (values == null) {
                    result.error("bad_arguments", "Expected a map of offsets.", null)
                    return
                }
                prefs.edit()
                    .putFloat(KEY_FLAT_PITCH, values.readFloat(KEY_FLAT_PITCH))
                    .putFloat(KEY_FLAT_ROLL, values.readFloat(KEY_FLAT_ROLL))
                    .putFloat(KEY_UPRIGHT, values.readFloat(KEY_UPRIGHT))
                    .apply()
                result.success(null)
            }

            "clearCalibration" -> {
                prefs.edit().clear().apply()
                result.success(null)
            }

            "setKeepScreenOn" -> {
                val enabled = call.arguments as? Boolean ?: false
                if (enabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onResume() {
        super.onResume()
        if (eventSink != null) startListening()
    }

    override fun onPause() {
        stopListening()
        super.onPause()
    }

    override fun onDestroy() {
        stopListening()
        eventSink = null
        super.onDestroy()
    }

    private fun startListening() {
        val manager = sensorManager
        val sensor = tiltSensor
        if (listening || manager == null || sensor == null) return
        manager.registerListener(sensorListener, sensor, SensorManager.SENSOR_DELAY_GAME)
        listening = true
    }

    private fun stopListening() {
        if (!listening) return
        sensorManager?.unregisterListener(sensorListener)
        listening = false
    }
}

private fun Map<*, *>.readFloat(key: String): Float = (this[key] as? Number)?.toFloat() ?: 0f
