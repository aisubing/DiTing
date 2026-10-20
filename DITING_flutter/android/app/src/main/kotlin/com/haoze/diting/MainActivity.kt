package com.haoze.diting

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LegacyPrefsBridge(applicationContext)
            .register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
