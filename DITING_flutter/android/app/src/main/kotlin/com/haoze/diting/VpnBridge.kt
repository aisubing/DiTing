package com.haoze.diting

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import androidx.core.content.ContextCompat
import com.haoze.diting.normal.DitingVpnService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Dart-facing control plane for the normal-mode tunnel.
///
/// `prepare` may open the system consent dialog; its result is delivered to
/// Dart as an `onPrepareResult` callback so the UI can retry `start` without
/// polling.
class VpnBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepare" -> result.success(prepare())
            "start" -> result.success(start(call))
            "stop" -> {
                stop(activity)
                result.success(true)
            }
            "status" -> result.success(DitingVpnService.status(activity))
            else -> result.notImplemented()
        }
    }

    private fun prepare(): Boolean {
        val intent = VpnService.prepare(activity)
        if (intent == null) return true
        activity.startActivityForResult(intent, REQUEST_PREPARE)
        return false
    }

    private fun start(call: MethodCall): Map<String, Any?> {
        val dnsConfig = call.argument<String>("dnsConfig").orEmpty()
        if (dnsConfig.isBlank()) {
            return mapOf("started" to false, "needsPermission" to false, "error" to "缺少 DNS 配置")
        }
        val excluded = call.argument<List<String>>("excludedPackages").orEmpty()
        val intent = DitingVpnService.startIntent(
            context = activity,
            dnsConfig = dnsConfig,
            ruleSnapshot = call.argument<String>("ruleSnapshot").orEmpty(),
            rewriteRules = call.argument<String>("rewriteRules").orEmpty(),
            proxyJson = call.argument<String>("outboundProxy").orEmpty(),
            bypassLan = call.argument<Boolean>("bypassLan") ?: true,
            ipv6Mode = call.argument<String>("ipv6Mode") ?: "auto",
            excludedPackages = excluded,
            // Both lists are package names on the Dart side; the service turns
            // them into UIDs because Engine.setBlockedUIDs /
            // setMitmAllowedUIDs match the UID the packet path sees.
            blockedPackages = call.argument<List<String>>("blockedPackages").orEmpty(),
            inspectionPackages = call.argument<List<String>>("inspectionPackages").orEmpty(),
            // Already folded by Dart from https_inspection_ready &&
            // http_inspection_enabled && packages.isNotEmpty().
            inspectionEnabled = call.argument<Boolean>("inspectionEnabled") ?: false,
        )
        return try {
            ContextCompat.startForegroundService(activity, intent)
            mapOf("started" to true, "needsPermission" to false, "error" to null)
        } catch (t: Throwable) {
            mapOf(
                "started" to false,
                "needsPermission" to false,
                "error" to (t.message ?: t.javaClass.simpleName),
            )
        }
    }

    private fun stop(context: Context) {
        if (DitingVpnService.isRunning) {
            runCatching { context.startService(DitingVpnService.stopIntent(context)) }
        } else {
            runCatching { context.stopService(Intent(context, DitingVpnService::class.java)) }
            DitingVpnService.setPersistedRunning(context, false)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_PREPARE) return false
        channel.invokeMethod("onPrepareResult", resultCode == Activity.RESULT_OK)
        return true
    }

    companion object {
        const val CHANNEL = "com.haoze.diting/vpn"
        const val REQUEST_PREPARE = 0x5650
    }
}
