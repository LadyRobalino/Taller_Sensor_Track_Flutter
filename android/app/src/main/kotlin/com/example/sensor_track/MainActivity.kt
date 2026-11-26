package com.example.sensor_track

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.location.LocationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sensor_track/hardware")
            .setMethodCallHandler { call, result ->
                if (call.method != "availableSensors") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                val location = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                result.success(mapOf(
                    "accelerometer" to (sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                    "gyroscope" to (sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null),
                    "gps" to location.allProviders.contains(LocationManager.GPS_PROVIDER)
                ))
            }
    }
}
