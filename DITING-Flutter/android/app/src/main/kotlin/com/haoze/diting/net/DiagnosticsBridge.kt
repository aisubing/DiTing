package com.haoze.diting.net

import android.content.Context
import com.haoze.diting.platform.ChannelResults
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Native side of `com.haoze.diting/diagnostics`: the four network-tool panels.
 *
 * 1.4.3 implemented these in Kotlin (`NetworkPingTool`,
 * `NetworkTraceRouteTool`, `NetworkInfoProbe`, `TunnelDiagnosticsResolver`);
 * the Flutter port degraded them to canned numbers. Executing `ping` /
 * `traceroute` and enumerating link properties needs a native process or a
 * platform service, so the results come back as plain maps.
 *
 * Contract frozen by `lib/data/native/diagnostics_bridge.dart`:
 * - `ping(target,count,timeoutSeconds)`
 * - `traceRoute(target,maxHops)`
 * - `lookupDns(domain,viaTunnel,ipv4)`
 * - `networkInfo`
 *
 * No method needs an `Activity`: the probes never touch UI (no consent dialog,
 * no file picker), so one `Context` is enough. An `Activity` parameter was
 * considered and dropped as an unused dependency.
 *
 * Probes run on a worker pool and every result is posted back to the platform
 * thread. `ping` with 20 counts can take most of a minute; blocking the platform
 * thread for that would freeze the whole Flutter UI, and answering from a worker
 * thread is not allowed by `MethodChannel.Result`.
 */
class DiagnosticsBridge(private val context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/diagnostics"

        /**
         * Unbounded, like 1.4.3's `Executors.newCachedThreadPool()`: the UI
         * already disables the run button while a probe is in flight, so the pool
         * size is bounded in practice by the four panels.
         */
        private val workers = Executors.newCachedThreadPool { runnable ->
            Thread(runnable, "diting-diagnostics").apply { isDaemon = true }
        }
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ping" -> {
                val target = call.argument<String>("target").orEmpty()
                val count = call.argument<Int>("count") ?: PingProbe.DEFAULT_COUNT
                val timeout = call.argument<Int>("timeoutSeconds")
                    ?: PingProbe.DEFAULT_TIMEOUT_SECONDS
                workers.execute {
                    val value = runCatching { PingProbe.ping(target, count, timeout) }
                    ChannelResults.ship(result, value, "ping_failed")
                }
            }
            "traceRoute" -> {
                val target = call.argument<String>("target").orEmpty()
                val maxHops = call.argument<Int>("maxHops") ?: TraceProbe.DEFAULT_MAX_HOPS
                workers.execute {
                    val value = runCatching { TraceProbe.trace(target, maxHops) }
                    ChannelResults.ship(result, value, "traceroute_failed")
                }
            }
            "lookupDns" -> {
                val domain = call.argument<String>("domain").orEmpty()
                val viaTunnel = call.argument<Boolean>("viaTunnel") ?: false
                val ipv4 = call.argument<Boolean>("ipv4") ?: true
                // 空串 = 系统解析器（1.4.3 的 `DnsServerMode.SYSTEM`），非空 =
                // 自定义 DNS 服务器（`DnsServerMode.CUSTOM`）。两个模式合并成一个
                // 可选参数，原生侧不必再猜用户选了哪个。
                val server = call.argument<String>("server").orEmpty().trim()
                workers.execute {
                    // A lookup never throws for a bad domain: every failure is
                    // expressed as source=error plus a readable message, because
                    // the Dart model renders `error` inline next to the answers.
                    val value = runCatching {
                        if (!viaTunnel && server.isNotEmpty()) {
                            DnsLookupProbe.customServerLookup(domain, server, ipv4)
                        } else {
                            DnsLookupProbe.lookup(domain, viaTunnel, ipv4)
                        }
                    }
                    ChannelResults.ship(result, value, "lookup_failed")
                }
            }
            // One synchronous ConnectivityManager read; no pool hop needed.
            "networkInfo" -> {
                val value = runCatching { NetInfoProbe.snapshot(context) }
                ChannelResults.ship(result, value, "network_info_failed")
            }
            else -> result.notImplemented()
        }
    }
}
