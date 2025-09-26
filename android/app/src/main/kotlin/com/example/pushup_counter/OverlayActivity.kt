package com.example.pushup_counter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class OverlayActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pushup_counter/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "closeOverlay" -> {
                    finish()
                    result.success(null)
                }
                "startPushups" -> {
                    // Signal to main app to start pushups
                    // This will be handled by the main app
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}