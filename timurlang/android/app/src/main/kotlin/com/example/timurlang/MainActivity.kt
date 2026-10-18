package com.example.timurlang

import android.content.Intent
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.timurlang/emergency_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bringToFront" -> {
                    val route = call.argument<String>("route") ?: "/sos"
                    bringAppToFront(route)
                    result.success(true)
                }
                "startBasecampService" -> {
                    val intent = Intent(this, BasecampMonitorService::class.java).apply {
                        putExtra("gunungId", call.argument<String>("gunungId") ?: "")
                        putExtra("basecampId", call.argument<String>("basecampId") ?: "")
                        putExtra("basecampName", call.argument<String>("basecampName") ?: "Basecamp")
                        putExtra("mountainName", call.argument<String>("mountainName") ?: "Gunung")
                        putExtra("supabaseUrl", call.argument<String>("supabaseUrl") ?: "")
                        putExtra("supabaseKey", call.argument<String>("supabaseKey") ?: "")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopBasecampService" -> {
                    val intent = Intent(this, BasecampMonitorService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val powerManager = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = android.net.Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                            }
                        } catch (e: Exception) {
                            // Fallback jika tidak didukung vendor
                        }
                    }
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun bringAppToFront(route: String = "/sos") {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }

            val intent = Intent(this, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                )
                putExtra("route", route)
            }
            startActivity(intent)
        }
    }
}
