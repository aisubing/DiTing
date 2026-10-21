package com.haoze.diting

import android.content.Intent
import com.haoze.diting.apps.AppsBridge
import com.haoze.diting.cert.CaInspectionBridge
import com.haoze.diting.net.DiagnosticsBridge
import com.haoze.diting.net.DnsLatencyBridge
import com.haoze.diting.platform.PlatformBridge
import com.haoze.diting.proxy.OutboundProxyBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var vpnBridge: VpnBridge? = null
    private var expressVpnBridge: ExpressVpnBridge? = null
    private var platformBridge: PlatformBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        LegacyPrefsBridge(applicationContext).register(messenger)
        vpnBridge = VpnBridge(this, messenger)
        expressVpnBridge = ExpressVpnBridge(this, messenger)
        DnsServerBridge(applicationContext, messenger)

        // 1.4.3 capabilities that had no Flutter counterpart: the real app
        // inventory, the MITM root CA, the outbound proxy (keystore-encrypted
        // credentials), and the network diagnostic tools.
        AppsBridge(applicationContext).register(messenger)
        CaInspectionBridge(applicationContext).register(messenger)
        OutboundProxyBridge(applicationContext).register(messenger)
        DiagnosticsBridge(applicationContext).register(messenger)

        // Round 3 parity work: the DNS speed test (`DnsLatencyTester`) and the
        // four OS-level settings (recents privacy, battery optimisation, crash
        // logs, text export). `PlatformBridge` needs the Activity to start
        // intents and to reach `ActivityManager.appTasks`, so it is handed in
        // here rather than constructed with `applicationContext` alone.
        DnsLatencyBridge(applicationContext).register(messenger)
        platformBridge = PlatformBridge(this).also { it.register(messenger) }
    }

    override fun onResume() {
        super.onResume()
        // 1.4.3 re-applied the recents-privacy flag on every resume: relaunching
        // from the app icon recreates the task entry, which silently resets
        // `excludeFromRecents`. `RecentsPrivacyController.apply()` was called
        // from the same place for the same reason.
        platformBridge?.reapplyRecentsPrivacy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (vpnBridge?.onActivityResult(requestCode, resultCode) == true) return
        expressVpnBridge?.onActivityResult(requestCode, resultCode)
    }
}
