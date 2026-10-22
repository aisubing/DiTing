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
        // 「更新与支持」的真实下载与安装：1.4.3 用 `AppUpdateManager` 写私有目录 +
        // `FileProvider` 调起安装器，两件事都没有 Dart 等价物。
        UpdateBridge(this).register(messenger)
        // 「软件背景」的选图与解码：`ACTION_OPEN_DOCUMENT` 需要 Activity 往返，
        // 大图也要用 `BitmapFactory` 采样，Dart 无法替代。
        backgroundBridge = BackgroundBridge(this).also { it.register(messenger) }
        // 名单头像的磁盘缓存：头像不随 APK 发布，联网取回后必须落盘，
        // 否则每次冷启动都要重下十几张图。Dart 侧没有 path_provider。
        RecognitionAvatarBridge(applicationContext).register(messenger)
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
        // 备份导出 / 恢复导入：都是文档选择器的往返。请求码 0x5701 / 0x5702
        // 与 VPN 的 0x5650 / 0x5651 不重叠，所以顺序无关，但仍放在前面，
        // 因为它要读 `data.data`（VPN 那两个只看 resultCode）。
        if (platformBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        if (backgroundBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        expressVpnBridge?.onActivityResult(requestCode, resultCode)
    }
}
