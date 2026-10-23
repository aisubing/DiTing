package com.haoze.diting.log

import android.content.Context
import tunnel.AppUidResolver
import tunnel.Engine
import tunnel.HttpLogCallback
import tunnel.TrafficCallback
import tunnel.UIDResolver

/// Owns the engine callbacks that feed the log tables; express mode registers only resolvers
class EngineDataPlane(
    private val context: Context,
    private val logMode: String,
) {
    private val uidCache = UidPackageCache(context)

    // Lazy: express mode must not start writer threads it never feeds.
    private val traffic: TrafficIngest by lazy {
        TrafficIngest(context, DnsLogWriter.DB_NORMAL, uidCache)
    }
    private val http: HttpRequestLogWriter by lazy {
        HttpRequestLogWriter(context, DnsLogWriter.DB_NORMAL) { logMode }
    }
    private var trafficAttached = false
    private var httpAttached = false

    /// UID -> package lookup for DNS/HTTP attribution and the firewall
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

    /// Per-UID byte deltas into `app_traffic_daily` (buffered 15s / 1MB). Full tunnel only
    fun attachTraffic(engine: Engine) {
        // Flag first: touching `traffic` starts its executor; a throw must leave it reachable.
        val writer = traffic
        trafficAttached = true
        engine.setTrafficCallback(object : TrafficCallback {
            override fun onTrafficStatsTick(jsonDeltas: String) {
                writer.onTick(jsonDeltas)
            }
        })
    }

    /// MITM events into `http_request_log` (10 rows / 500ms), only while a MITM filter is installed
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

    /// Flushes what was attached and releases the callback targets; called after the engine stops
    fun close() {
        if (trafficAttached) runCatching { traffic.close() }
        if (httpAttached) runCatching { http.close() }
        uidCache.clear()
    }
}
