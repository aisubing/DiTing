package com.haoze.diting

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var vpnBridge: VpnBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LegacyPrefsBridge(applicationContext)
            .register(flutterEngine.dartExecutor.binaryMessenger)
        vpnBridge = VpnBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        vpnBridge?.onActivityResult(requestCode, resultCode)
    }
}
