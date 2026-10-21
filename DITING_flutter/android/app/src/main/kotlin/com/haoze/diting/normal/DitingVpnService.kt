package com.haoze.diting.normal

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import com.haoze.diting.R
import com.haoze.diting.log.DnsLogWriter
import com.haoze.diting.log.EngineDataPlane
import com.haoze.diting.log.EngineStats
import com.haoze.diting.log.PackageUids
import com.haoze.diting.log.RaceLogWriter
import com.haoze.diting.log.TrafficRateMonitor
import tunnel.BatchLogCallback
import tunnel.Engine
import tunnel.RaceLogCallback
import tunnel.SocketProtector
import java.io.File

/// Full-tunnel VpnService backed by the unchanged 1.4.3 Go engine.
///
/// The Dart layer owns every policy decision; this service only applies the
/// DNS config / rule snapshot / rewrite map it receives, then hands the TUN
/// descriptor to `Engine.startFull`. All engine knobs must be set before
/// `startFull`, because the Go call blocks for the lifetime of the tunnel.
class DitingVpnService : VpnService() {
    private var tun: ParcelFileDescriptor? = null
    private var engine: Engine? = null
    private var dataPlane: EngineDataPlane? = null

    @Volatile
    private var worker: Thread? = null

    @Volatile
    private var stopping = false

    /// Notification speed-refresh loop; `null` until the tunnel actually starts.
    @Volatile
    private var speedTicker: Thread? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        promoteToForeground()
        if (intent?.action == ACTION_STOP) {
            stopTunnel()
            return START_NOT_STICKY
        }
        val dnsConfig = intent?.getStringExtra(EXTRA_DNS_CONFIG)
        if (dnsConfig.isNullOrBlank()) {
            Log.w(TAG, "start intent without DNS config")
            stopTunnel()
            return START_NOT_STICKY
        }
        startTunnel(
            dnsConfig = dnsConfig,
            ruleSnapshot = intent.getStringExtra(EXTRA_RULE_SNAPSHOT).orEmpty(),
            rewriteRules = intent.getStringExtra(EXTRA_REWRITE_RULES).orEmpty(),
            proxyJson = intent.getStringExtra(EXTRA_OUTBOUND_PROXY).orEmpty(),
            bypassLan = intent.getBooleanExtra(EXTRA_BYPASS_LAN, true),
            ipv6Mode = intent.getStringExtra(EXTRA_IPV6_MODE) ?: "auto",
            excludedPackages = intent.getStringArrayListExtra(EXTRA_EXCLUDED_PACKAGES).orEmpty().toSet(),
            blockedPackages = intent.getStringArrayListExtra(EXTRA_BLOCKED_PACKAGES).orEmpty().toSet(),
            inspectionPackages = intent.getStringArrayListExtra(EXTRA_INSPECTION_PACKAGES).orEmpty().toSet(),
            inspectionEnabled = intent.getBooleanExtra(EXTRA_INSPECTION_ENABLED, false),
        )
        return START_NOT_STICKY
    }

    @Synchronized
    private fun startTunnel(
        dnsConfig: String,
        ruleSnapshot: String,
        rewriteRules: String,
        proxyJson: String,
        bypassLan: Boolean,
        ipv6Mode: String,
        excludedPackages: Set<String>,
        blockedPackages: Set<String>,
        inspectionPackages: Set<String>,
        inspectionEnabled: Boolean,
    ) {
        if (engine != null) {
            Log.i(TAG, "tunnel already running; ignoring duplicate start")
            return
        }
        stopping = false
        lastError = null

        val pfd = VpnRouteConfig.establish(this, excludedPackages, bypassLan, ipv6Mode)
        if (pfd == null) {
            fail("无法建立 VPN 接口")
            return
        }
        tun = pfd

        val goEngine = try {
            Engine()
        } catch (t: Throwable) {
            Log.e(TAG, "Unable to load Go engine", t)
            releaseResources()
            fail("Go 引擎加载失败：${t.message ?: t.javaClass.simpleName}")
            return
        }
        engine = goEngine
        activeEngine = goEngine

        try {
            val proxyError = goEngine.configureOutboundProxy(
                proxyJson.ifBlank { DEFAULT_OUTBOUND_PROXY }
            )
            require(proxyError.isBlank()) { proxyError }
            goEngine.applyDNSConfig(dnsConfig)
            if (ruleSnapshot.isNotBlank()) {
                val snapshotError = goEngine.applyRuleSnapshot(ruleSnapshot)
                if (snapshotError.isNotBlank()) {
                    Log.w(TAG, "applyRuleSnapshot failed: $snapshotError")
                }
            }
            if (rewriteRules.isNotBlank()) {
                goEngine.setRewriteRules(rewriteRules)
            }
            val logMode = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                .getString(KEY_LOG_MODE, DnsLogWriter.MODE_ALL)
                ?: DnsLogWriter.MODE_ALL
            goEngine.setBatchLogCallback(object : BatchLogCallback {
                override fun onDNSQueryBatch(jsonLogs: String) {
                    DnsLogWriter.writeBatch(this@DitingVpnService, DnsLogWriter.DB_NORMAL, logMode, jsonLogs)
                }
            })
            goEngine.setRaceLogCallback(object : RaceLogCallback {
                override fun onRaceResult(
                    queryName: String,
                    queryType: Long,
                    strategy: String,
                    providerCount: Long,
                    success: Boolean,
                    elapsedMs: Long,
                    selectedProviderID: String,
                    selectedElapsedMs: Long,
                    winnerProviderID: String,
                    winnerElapsedMs: Long,
                    fallbackUsed: Boolean,
                    fallbackSuccess: Boolean,
                    errorMessage: String,
                ) {
                    RaceLogWriter.write(
                        this@DitingVpnService,
                        DnsLogWriter.DB_NORMAL,
                        queryName = queryName,
                        queryType = queryType.toInt(),
                        strategy = strategy,
                        providerCount = providerCount.toInt(),
                        success = success,
                        elapsedMs = elapsedMs,
                        selectedProviderId = selectedProviderID,
                        selectedElapsedMs = selectedElapsedMs,
                        winnerProviderId = winnerProviderID,
                        winnerElapsedMs = winnerElapsedMs,
                        fallbackUsed = fallbackUsed,
                        fallbackSuccess = fallbackSuccess,
                        errorMessage = errorMessage,
                    )
                }
            })
            goEngine.setFilterDNS(true)
            goEngine.setUseTcpStack(true)

            // Data plane: UID attribution for dns_log.packageName plus the two
            // log tables that had no producer at all. Everything is registered
            // before startFull, because the Go call blocks for the tunnel's
            // lifetime and the first DNS query can arrive immediately.
            //
            // The field is assigned before the attach calls so a throw below
            // still reaches closeDataPlane() from the catch block: the writers
            // own executor threads and a 15s timer, which must not outlive a
            // failed start.
            val plane = EngineDataPlane(this, logMode)
            dataPlane = plane
            plane.attachResolvers(goEngine)
            plane.attachTraffic(goEngine)
            plane.attachHttp(goEngine)

            // Per-app firewall: the engine matches UIDs, not package names.
            val blockedUidCsv = PackageUids.csv(this, blockedPackages)
            if (blockedUidCsv.isNotEmpty()) {
                goEngine.setBlockedUIDs(blockedUidCsv)
            }

            // HTTPS inspection. Order matters: startStackMitm materialises the
            // root CA and installs the filter that setMitmAllowedUIDs writes
            // into; called in the other order the UID list is silently dropped
            // (engine_mitm.go logs "stack MITM is not active" and returns).
            if (inspectionEnabled) {
                val mitmDir = File(filesDir, MITM_DIR).apply { mkdirs() }
                val caPem = runCatching { goEngine.startStackMitm(mitmDir.absolutePath) }
                    .getOrDefault("")
                if (caPem.isBlank()) {
                    // No CA means no filter, so startFull builds a plain
                    // passthrough stack. Leaving the UID list unset matches that.
                    Log.w(TAG, "startStackMitm produced no CA; HTTPS inspection stays off")
                } else {
                    goEngine.setMitmAllowedUIDs(PackageUids.csv(this, inspectionPackages))
                }
            } else {
                // Explicit "inspect nobody". This Engine is fresh, so the list is
                // already empty; the call is defence in depth for any future
                // engine reuse. Side effect worth knowing: with no MITM filter
                // the Go setter logs "MITM: SetAllowedUIDs called but stack MITM
                // is not active" on GoLog — expected on every inspection-off
                // start, not a fault.
                goEngine.setMitmAllowedUIDs("")
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Unable to configure Go engine", t)
            releaseResources()
            fail("隧道配置失败：${t.message ?: t.javaClass.simpleName}")
            return
        }

        isRunning = true
        setPersistedRunning(this, true)
        startSpeedTicker()
        worker = Thread({
            try {
                goEngine.startFull(pfd.fd.toLong(), SocketProtector { fd ->
                    protect(fd.toInt())
                })
                Log.i(TAG, "Go tunnel exited")
            } catch (t: Throwable) {
                Log.e(TAG, "Go tunnel crashed", t)
                if (!stopping) {
                    fail("隧道运行异常：${t.message ?: t.javaClass.simpleName}")
                }
            }
        }, "diting-tunnel").also { it.start() }
    }

    @Synchronized
    private fun stopTunnel() {
        stopping = true
        val current = engine
        engine = null
        activeEngine = null
        runCatching { current?.stop() }
            .onFailure { Log.w(TAG, "engine.stop failed", it) }
        runCatching { current?.stopStackMitm() }
        runCatching { current?.releaseTun() }
        closeDataPlane()
        releaseResources()
        isRunning = false
        setPersistedRunning(this, false)
        stopForegroundCompat()
        stopSelf()
    }

    /// Flushes the buffered traffic / HTTP rows. Runs after the engine has
    /// stopped so no callback can append to a writer that is closing.
    private fun closeDataPlane() {
        val plane = dataPlane
        dataPlane = null
        runCatching { plane?.close() }
    }

    private fun releaseResources() {
        runCatching { tun?.close() }
        tun = null
        worker = null
        // The ticker spins on `isRunning`, but stop it explicitly as well: the
        // failure path drops straight out of `onStartCommand` where `isRunning`
        // was never set, and a leaked thread would keep re-notifying.
        stopSpeedTicker()
        TrafficRateMonitor.reset()
    }

    private fun fail(message: String) {
        lastError = message
        isRunning = false
        activeEngine = null
        closeDataPlane()
        setPersistedRunning(this, false)
        releaseResources()
        stopForegroundCompat()
        stopSelf()
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN permission revoked")
        stopTunnel()
        super.onRevoke()
    }

    override fun onDestroy() {
        if (engine != null || isRunning || dataPlane != null) {
            stopping = true
            val current = engine
            engine = null
            activeEngine = null
            runCatching { current?.stop() }
            runCatching { current?.stopStackMitm() }
            runCatching { current?.releaseTun() }
            closeDataPlane()
            releaseResources()
            isRunning = false
            setPersistedRunning(this, false)
            stopForegroundCompat()
        }
        super.onDestroy()
    }

    private fun promoteToForeground() {
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (t: Throwable) {
            // Android 12+ requires foreground promotion inside onStartCommand;
            // a failure here would otherwise surface as a process crash.
            Log.e(TAG, "startForeground failed", t)
        }
    }

    private fun buildNotification(): Notification =
        VpnNotification.build(this, CHANNEL_ID, NOTIFICATION_ID, ACTION_STOP)

    /**
     * Ticks the notification's speed line while the tunnel runs.
     *
     * 1.4.3 used `VpnSpeedMonitor`, a coroutine that polled a `StateFlow` and only
     * re-notified when the formatted string changed. Same idea here, on a plain
     * daemon thread because this module has no coroutine dependency:
     *
     * - the screen-off interval is longer (nobody reads a notification while the
     *   display is dark, and waking to redraw it costs battery);
     * - [VpnNotification.refresh] itself no-ops when 实时速率 is disabled, so the
     *   loop costs one pref read per tick when the feature is off.
     */
    private fun startSpeedTicker() {
        if (speedTicker != null) return
        speedTicker = Thread({
            val power = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
            while (isRunning && !stopping) {
                val onScreen = power?.isInteractive ?: true
                try {
                    Thread.sleep(if (onScreen) SCREEN_ON_INTERVAL_MS else SCREEN_OFF_INTERVAL_MS)
                } catch (interrupted: InterruptedException) {
                    return@Thread
                }
                VpnNotification.refresh(this, CHANNEL_ID, NOTIFICATION_ID, ACTION_STOP)
            }
        }, "diting-speed-ticker").apply {
            isDaemon = true
            start()
        }
    }

    private fun stopSpeedTicker() {
        speedTicker?.interrupt()
        speedTicker = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "VPN 服务",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "保持 VPN 隧道运行"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    companion object {
        private const val TAG = "DitingVpnService"

        const val ACTION_START = "com.haoze.diting.START_VPN"
        const val ACTION_STOP = "com.haoze.diting.STOP_VPN"

        const val EXTRA_DNS_CONFIG = "dns_config"
        const val EXTRA_RULE_SNAPSHOT = "rule_snapshot"
        const val EXTRA_REWRITE_RULES = "rewrite_rules"
        const val EXTRA_OUTBOUND_PROXY = "outbound_proxy"
        const val EXTRA_BYPASS_LAN = "bypass_lan"
        const val EXTRA_IPV6_MODE = "ipv6_mode"
        const val EXTRA_EXCLUDED_PACKAGES = "excluded_packages"

        /// `blocked_app_packages`: converted to UIDs for `setBlockedUIDs`.
        const val EXTRA_BLOCKED_PACKAGES = "blocked_packages"

        /// `http_inspection_app_packages`: converted to UIDs for
        /// `setMitmAllowedUIDs`.
        const val EXTRA_INSPECTION_PACKAGES = "inspection_packages"

        /// Precomputed by Dart as `https_inspection_ready &&
        /// http_inspection_enabled && packages.isNotEmpty()`, because the CA must
        /// be installed before intercepting or every HTTPS request in the
        /// selected apps breaks.
        const val EXTRA_INSPECTION_ENABLED = "inspection_enabled"

        private const val CHANNEL_ID = "diting_vpn"
        private const val NOTIFICATION_ID = 1001

    /// Notification speed refresh cadence: 1 s while the screen is on (the
    /// readout is a per-second figure), 10 s while it is off.
    private const val SCREEN_ON_INTERVAL_MS = 1000L
    private const val SCREEN_OFF_INTERVAL_MS = 10_000L
        private const val PREFS_NAME = "dns_vpn_prefs"
        private const val KEY_VPN_RUNNING = "vpn_running"
        private const val KEY_LOG_MODE = "dns_log_mode"

        /// Same directory as 1.4.3's `GoInspectionCaManager.certificateDirectory`,
        /// so an upgraded install keeps using its already-trusted root CA
        /// instead of minting a new one the user would have to install again.
        private const val MITM_DIR = "go-mitm"

        // Outbound proxy is not wired from Flutter yet; an explicit disabled
        // config keeps the Go side from logging a parse failure on every start.
        private const val DEFAULT_OUTBOUND_PROXY =
            """{"enabled":false,"protocol":"SOCKS5","host":"127.0.0.1","port":7890,"username":"","password":""}"""

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        private var activeEngine: Engine? = null

        /** Read-only handle for the diagnostics channel; never expose a setter. */
        internal fun engineForDiagnostics(): Engine? = activeEngine

        @Volatile
        var lastError: String? = null

        fun isPersistedRunning(context: Context): Boolean =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_VPN_RUNNING, false)

        private fun Context.setRunningFlag(value: Boolean) {
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_VPN_RUNNING, value)
                .apply()
        }

        fun setPersistedRunning(context: Context, value: Boolean) =
            context.setRunningFlag(value)

        fun status(context: Context): Map<String, Any?> = mapOf(
            "running" to isRunning,
            "persisted" to isPersistedRunning(context),
            "error" to lastError,
            "stats" to EngineStats.snapshot(activeEngine),
        )

        /**
         * Second-resolution TX/RX rates for the dashboard's 实时速率 readout.
         *
         * Returns zeros when the tunnel is not running: [TrafficRateMonitor] is
         * reset on every stop, but a caller racing the stop path could still read
         * the last tick's numbers, and showing a speed while "已停止" is exactly
         * the kind of plausible-looking fake this port keeps removing.
         */
        fun trafficRates(): Map<String, Any?> {
            if (!isRunning) {
                return mapOf("running" to false, "txBps" to 0L, "rxBps" to 0L)
            }
            val (tx, rx) = TrafficRateMonitor.snapshot()
            return mapOf("running" to true, "txBps" to tx, "rxBps" to rx)
        }

        fun startIntent(
            context: Context,
            dnsConfig: String,
            ruleSnapshot: String,
            rewriteRules: String,
            proxyJson: String,
            bypassLan: Boolean,
            ipv6Mode: String,
            excludedPackages: List<String>,
            blockedPackages: List<String> = emptyList(),
            inspectionPackages: List<String> = emptyList(),
            inspectionEnabled: Boolean = false,
        ): Intent = Intent(context, DitingVpnService::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_DNS_CONFIG, dnsConfig)
            putExtra(EXTRA_RULE_SNAPSHOT, ruleSnapshot)
            putExtra(EXTRA_REWRITE_RULES, rewriteRules)
            putExtra(EXTRA_OUTBOUND_PROXY, proxyJson)
            putExtra(EXTRA_BYPASS_LAN, bypassLan)
            putExtra(EXTRA_IPV6_MODE, ipv6Mode)
            putStringArrayListExtra(EXTRA_EXCLUDED_PACKAGES, ArrayList(excludedPackages))
            putStringArrayListExtra(EXTRA_BLOCKED_PACKAGES, ArrayList(blockedPackages))
            putStringArrayListExtra(EXTRA_INSPECTION_PACKAGES, ArrayList(inspectionPackages))
            putExtra(EXTRA_INSPECTION_ENABLED, inspectionEnabled)
        }

        fun stopIntent(context: Context): Intent =
            Intent(context, DitingVpnService::class.java).setAction(ACTION_STOP)
    }
}
