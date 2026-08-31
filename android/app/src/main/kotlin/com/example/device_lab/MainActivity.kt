package com.example.device_lab

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "devicelab/device_info"
        ).setMethodCallHandler {call , result ->
            when (call.method) {
                "ping" -> result.success("Pong from native android")
            }

        }
    }
}
