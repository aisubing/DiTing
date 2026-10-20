package com.haoze.diting.log

import android.content.Context
import tunnel.AppUidResolver
import tunnel.Engine
import tunnel.HttpLogCallback
import tunnel.TrafficCallback
import tunnel.UIDResolver

/// Owns the engine callbacks that give the legacy log tables real data, so each
/// VpnService needs one call per capability instead of four registrations.
///
/// What this closes: before it existed the Flutter port registered only
/// `setBatchLogCallback` and `setRaceLogCallback`. `setUIDResolver` /
/// `setAppUidResolver` were missing, so `engine_dns.go` had neither an
/// `appResolver` nor a UID pair and every `dns_log.packageName` stayed NULL;
/// `setTrafficCallback` and `setHttpLogCallback` were missing, so
/// `app_traffic_daily` and `http_request_log` had no producer at all.
///
/// The pieces are separable on purpose:
///  - [attachResolvers] is the only one express mode registers. Its narrow TUN
///    still parses DNS from the packet path, so package attribution works there
///    and `dns_log` (which exists in both databases) is the express log table.
///  - [attachTraffic] / [attachHttp] are full-tunnel only. `diting_express` has
///    neither table (`ExpressRulesDatabase` explicitly excludes
///    `AppTrafficDailyEntity` and `HttpRequestLogEntity`), and 1.4.3 never ran
///    traffic stats in express mode either — its own
///    `ExpressNotificationSettingsScreen` says express "operates exclusively on
///    DNS narrow TUN without full-tunnel traffic stats". Registering the
///    callbacks there would be per-second JSON parsing whose output can never be
///    persisted.
class EngineDataPlane(
    private val context: Context,
    private val logMode: String,
) {
    private val uidCache = UidPackageCache(context)

    // Created on first use: express mode must not spin up two writer threads it
    // will never feed.
    private val traffic: TrafficIngest by lazy {
        TrafficIngest(context, DnsLogWriter.DB_NORMAL, uidCache)
    }
    private val http: HttpRequestLogWriter by lazy {
        HttpRequestLogWriter(context, DnsLogWriter.DB_NORMAL) { logMode }
    }
    private var trafficAttached = false
    private var httpAttached = false

    /// UID → package. Feeds `dns_log.packageName`, `http_request_log.packageName`
    /// and the Go firewall's per-app matching.
    fun attachResolvers(engine: Engine) {
        engine.setUIDResolver(object : UIDResolver {
            override fun resolveUID(
                protocol: Long,
                localIP: String,
                localPort: Long,
                remoteIP: String,
                remotePort: Long,
            ): Long = uidCache.resolveUid(protocol, localIP, localPort, remoteIP, remotePort).toLong()
        })
        engine.setAppUidResolver(object : AppUidResolver {
            override fun packageForUid(uid: Long): String = uidCache.packageForUid(uid.toInt())
        })
    }

    /// Per-UID byte deltas → `app_traffic_daily` (buffered 15s / 1MB).
    ///
    /// The writer always targets `diting_database`; there is no express variant
    /// because the express file has no `app_traffic_daily` table.
    fun attachTraffic(engine: Engine) {
        // Flag first: reading `traffic` is what creates the executor thread and
        // its 15s timer, so a throw from setTrafficCallback must still leave the
        // writer reachable by close().
        val writer = traffic
        trafficAttached = true
        engine.setTrafficCallback(object : TrafficCallback {
            override fun onTrafficStatsTick(jsonDeltas: String) {
                writer.onTick(jsonDeltas)
            }
        })
    }

    /// MITM request events → `http_request_log` (buffered 10 rows / 500ms).
    /// Safe to register even when MITM is off: the Go side only calls
    /// `logHTTPEvent` when a stack MITM filter is installed.
    fun attachHttp(engine: Engine) {
        val writer = http
        httpAttached = true
        engine.setHttpLogCallback(object : HttpLogCallback {
            override fun onHttpEvent(
                packageName: String,
                authority: String,
                protocol: String,
                outcome: String,
                matchedRule: String,
            ) {
                writer.onEvent(packageName, authority, protocol, outcome, matchedRule)
            }
        })
    }

    /// Flushes whatever was attached and releases the callback targets. Called
    /// from every stop path, after the engine has stopped.
    fun close() {
        if (trafficAttached) runCatching { traffic.close() }
        if (httpAttached) runCatching { http.close() }
        uidCache.clear()
    }
}
