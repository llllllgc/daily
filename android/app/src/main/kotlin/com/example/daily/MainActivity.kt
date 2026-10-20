package com.example.daily

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceSettingsChannel = "daily/device_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceSettingsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                        result.success(true)
                    } else {
                        val powerManager =
                            getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(
                            powerManager.isIgnoringBatteryOptimizations(packageName),
                        )
                    }
                }

                "openBatterySettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                        )
                        result.success(null)
                    } catch (_: Exception) {
                        startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = android.net.Uri.parse("package:$packageName")
                            },
                        )
                        result.success(null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
