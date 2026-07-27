package com.sloppybobbert.dosey_app

import android.Manifest
import android.app.KeyguardManager
import android.app.NotificationManager
import android.bluetooth.BluetoothManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sloppybobbert.dosey_app/android_platform"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkVersion" -> result.success(Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sloppybobbert.dosey_app/timezone"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalTimezone" -> result.success(TimeZone.getDefault().id)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sloppybobbert.dosey_app/apple_auth"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "signIn" -> result.error(
                    "APPLE_SIGN_IN_UNAVAILABLE",
                    "Apple sign-in is only available on iOS in this prototype.",
                    null
                )
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sloppybobbert.dosey_app/screen_awake"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenAwake" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "wakeScreen" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        setTurnScreenOn(true)
                        window.decorView.post { setTurnScreenOn(false) }
                    } else {
                        @Suppress("DEPRECATION")
                        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
                        window.decorView.post {
                            @Suppress("DEPRECATION")
                            window.clearFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sloppybobbert.dosey_app/robot_phone_setup"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(robotPhoneSetupStatus())
                "openBluetoothSettings" -> result.success(openSettings(Intent(Settings.ACTION_BLUETOOTH_SETTINGS)))
                "openWifiSettings" -> result.success(openSettings(Intent(Settings.ACTION_WIFI_SETTINGS)))
                "openNotificationSettings" -> result.success(openNotificationSettings())
                "openBatteryOptimizationSettings" -> result.success(
                    openSettings(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                )
                "openSecuritySettings" -> result.success(openSettings(Intent(Settings.ACTION_SECURITY_SETTINGS)))
                "openAppDetails" -> result.success(openAppDetails())
                else -> result.notImplemented()
            }
        }
    }

    private fun robotPhoneSetupStatus(): Map<String, String> {
        val bluetoothPermissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        val bluetooth = if (!bluetoothPermissionGranted) {
            "permissionRequired"
        } else {
            val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            if (manager.adapter?.isEnabled == true) "ready" else "actionRequired"
        }
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return mapOf(
            "bluetooth" to bluetooth,
            "wifi" to if (wifiManager.isWifiEnabled) "ready" else "actionRequired",
            "notifications" to if (
                Build.VERSION.SDK_INT < Build.VERSION_CODES.N || notificationManager.areNotificationsEnabled()
            ) "ready" else "actionRequired",
            "batteryOptimization" to if (powerManager.isIgnoringBatteryOptimizations(packageName)) {
                "ready"
            } else {
                "actionRequired"
            },
            "secureLock" to if (keyguardManager.isDeviceSecure) "actionRequired" else "ready",
        )
    }

    private fun openNotificationSettings(): Boolean {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        return openSettings(intent)
    }

    private fun openAppDetails(): Boolean {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName"),
        )
        return openSettings(intent)
    }

    private fun openSettings(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
