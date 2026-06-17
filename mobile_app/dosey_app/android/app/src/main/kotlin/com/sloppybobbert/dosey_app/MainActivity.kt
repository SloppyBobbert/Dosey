package com.sloppybobbert.dosey_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }
}
