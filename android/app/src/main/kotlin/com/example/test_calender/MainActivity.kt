package com.example.test_calender

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CalendarBridge.register(this, flutterEngine.dartExecutor.binaryMessenger)
        AppUpdater.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
