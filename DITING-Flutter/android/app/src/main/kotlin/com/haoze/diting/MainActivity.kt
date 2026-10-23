package com.haoze.diting

import android.content.Intent
import com.haoze.diting.apps.AppsBridge
import com.haoze.diting.cert.CaInspectionBridge
import com.haoze.diting.net.DiagnosticsBridge
import com.haoze.diting.net.DnsLatencyBridge
import com.haoze.diting.platform.BackgroundBridge
import com.haoze.diting.platform.PlatformBridge
import com.haoze.diting.platform.RecognitionAvatarBridge
import com.haoze.diting.platform.UpdateBridge
import com.haoze.diting.proxy.OutboundProxyBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var vpnBridge: VpnBridge? = null
    private var expressVpnBridge: ExpressVpnBridge? = null
    private var platformBridge: PlatformBridge? = null
    private var backgroundBridge: BackgroundBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        LegacyPrefsBridge(applicationContext).register(messenger)
        vpnBridge = VpnBridge(this, messenger)
        expressVpnBridge = ExpressVpnBridge(this, messenger)
        DnsServerBridge(applicationContext, messenger)

        AppsBridge(applicationContext).register(messenger)
        CaInspectionBridge(applicationContext).register(messenger)
        OutboundProxyBridge(applicationContext).register(messenger)
        DiagnosticsBridge(applicationContext).register(messenger)

        // Needs an Activity: starts intents and reaches ActivityManager.appTasks.
        DnsLatencyBridge(applicationContext).register(messenger)
        platformBridge = PlatformBridge(this).also { it.register(messenger) }
        UpdateBridge(this).register(messenger)
        backgroundBridge = BackgroundBridge(this).also { it.register(messenger) }
        RecognitionAvatarBridge(applicationContext).register(messenger)
    }

    override fun onResume() {
        super.onResume()
        // Relaunching from the app icon recreates the task entry, resetting excludeFromRecents.
        platformBridge?.reapplyRecentsPrivacy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (vpnBridge?.onActivityResult(requestCode, resultCode) == true) return
        // Codes never collide with the VPN ones: this reads data.data, those read only resultCode.
        if (platformBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        if (backgroundBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        expressVpnBridge?.onActivityResult(requestCode, resultCode)
    }
}
