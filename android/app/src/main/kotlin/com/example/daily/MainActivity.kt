package com.example.daily

import java.io.ByteArrayOutputStream
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var fileResult: MethodChannel.Result? = null
    private var exportContent: String? = null
    private val deviceSettingsChannel = "daily/device_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily/data").setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    getSharedPreferences("daily_widget", Context.MODE_PRIVATE).edit().putString("content", call.argument<String>("content")).apply()
                    DailyWidgetProvider.refresh(this)
                    result.success(null)
                }
                "exportBackup", "importBackup" -> {
                    if (fileResult != null) { result.error("busy", "文件选择器正在使用", null) }
                    else {
                        fileResult = result
                        try {
                            if (call.method == "exportBackup") {
                                exportContent = call.argument<String>("content")
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply { addCategory(Intent.CATEGORY_OPENABLE); type = "application/json"; putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "Daily.json") }, 7301)
                            } else {
                                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply { addCategory(Intent.CATEGORY_OPENABLE); type = "*/*"; putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "application/octet-stream", "text/plain")) }, 7302)
                            }
                        } catch (error: Exception) { fileResult = null; exportContent = null; result.error("file", error.localizedMessage, null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
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
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7301 && requestCode != 7302) return
        val callback = fileResult ?: return
        fileResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { exportContent = null; callback.success(if (requestCode == 7301) false else null); return }
        try {
            if (requestCode == 7301) {
                val content = exportContent ?: throw IllegalStateException("缺少备份内容")
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(content.toByteArray(Charsets.UTF_8)) } ?: throw IllegalStateException("无法写入文件")
                callback.success(true)
            } else {
                val bytes = contentResolver.openInputStream(uri)?.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        if (output.size() + read > 50 * 1024 * 1024) throw IllegalArgumentException("备份文件过大")
                        output.write(buffer, 0, read)
                    }
                    output.toByteArray()
                } ?: throw IllegalStateException("无法读取文件")
                if (bytes.size > 50 * 1024 * 1024) throw IllegalArgumentException("备份文件过大")
                callback.success(String(bytes, Charsets.UTF_8))
            }
        } catch (error: Exception) { callback.error("file", error.localizedMessage, null) }
        finally { exportContent = null }
    }

}
