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
import com.haoze.diting.core.rule.RuleDataset
import com.haoze.diting.core.rule.RuleSnapshotStore
import com.haoze.diting.log.DnsLogWriter
import com.haoze.diting.log.EngineDataPlane
import com.haoze.diting.log.EngineStats
import com.haoze.diting.log.LogRetention
import com.haoze.diting.log.PackageUids
import com.haoze.diting.log.RaceLogWriter
import com.haoze.diting.log.TrafficRateMonitor
import com.haoze.diting.tile.QuickSettingsTileUpdater
import tunnel.BatchLogCallback
import tunnel.Engine
import tunnel.RaceLogCallback
import tunnel.SocketProtector
import java.io.File

/// Full-tunnel VpnService: applies the config, then hands the TUN fd to Engine.startFull.
class DitingVpnService : VpnService() {
    private var tun: ParcelFileDescriptor? = null
    private var engine: Engine? = null
    private var dataPlane: EngineDataPlane? = null

    @Volatile
    private var worker: Thread? = null

    @Volatile
    private var stopping = false

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
        // Persisted so the quick settings tile (and a future reboot restore) can rebuild the same
        // start intent: Dart computes the config, the extras do not survive elsewhere.
        rememberStartConfig(
            dnsConfig = dnsConfig,
            proxyJson = intent.getStringExtra(EXTRA_OUTBOUND_PROXY).orEmpty(),
            bypassLan = intent.getBooleanExtra(EXTRA_BYPASS_LAN, true),
            ipv6Mode = intent.getStringExtra(EXTRA_IPV6_MODE) ?: "auto",
            excludedPackages = intent.getStringArrayListExtra(EXTRA_EXCLUDED_PACKAGES).orEmpty().toSet(),
            blockedPackages = intent.getStringArrayListExtra(EXTRA_BLOCKED_PACKAGES).orEmpty().toSet(),
            inspectionPackages = intent.getStringArrayListExtra(EXTRA_INSPECTION_PACKAGES).orEmpty().toSet(),
            inspectionEnabled = intent.getBooleanExtra(EXTRA_INSPECTION_ENABLED, false),
        )
        startTunnel(
            dnsConfig = dnsConfig,
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

    /// Stores the configuration of the current start so `restoreIntent` can replay it. Rules are
    /// not part of it: the service rebuilds the engine snapshot from the rule database.
    private fun rememberStartConfig(
        dnsConfig: String,
        proxyJson: String,
        bypassLan: Boolean,
        ipv6Mode: String,
        excludedPackages: Set<String>,
        blockedPackages: Set<String>,
        inspectionPackages: Set<String>,
        inspectionEnabled: Boolean,
    ) {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
            .putString(KEY_LAST_DNS_CONFIG, dnsConfig)
            .putString(KEY_LAST_OUTBOUND_PROXY, proxyJson)
            .putBoolean(KEY_LAST_BYPASS_LAN, bypassLan)
            .putString(KEY_LAST_IPV6_MODE, ipv6Mode)
            .putStringSet(KEY_LAST_EXCLUDED_PACKAGES, excludedPackages)
            .putStringSet(KEY_LAST_BLOCKED_PACKAGES, blockedPackages)
            .putStringSet(KEY_LAST_INSPECTION_PACKAGES, inspectionPackages)
            .putBoolean(KEY_LAST_INSPECTION_ENABLED, inspectionEnabled)
            .apply()
    }

    @Synchronized
    private fun startTunnel(
        dnsConfig: String,
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

            // Attached before startFull and assigned first, so a throw still reaches cleanup.
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

            // Order matters: reversed, the UID list from setMitmAllowedUIDs is silently dropped.
            if (inspectionEnabled) {
                val mitmDir = File(filesDir, MITM_DIR).apply { mkdirs() }
                val caPem = runCatching { goEngine.startStackMitm(mitmDir.absolutePath) }
                    .getOrDefault("")
                if (caPem.isBlank()) {
                    // No CA means no filter, so startFull builds a plain passthrough stack.
                    Log.w(TAG, "startStackMitm produced no CA; HTTPS inspection stays off")
                } else {
                    goEngine.setMitmAllowedUIDs(PackageUids.csv(this, inspectionPackages))
                }
            } else {
                // Inspect nobody: the Go setter logs "stack MITM is not active" - expected.
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
        // The window only matters while logs are written, and this service outlives the UI.
        LogRetention.start(
            context = this,
            databaseName = LOG_DATABASE,
            prefsName = LOG_PREFS,
            includeHttpAndTraffic = true,
        )
        worker = Thread({
            try {
                // Rules are built here, off the main thread: a stale index means a trie compile
                // that can take seconds, and onStartCommand would otherwise ANR the service.
                // Applied before startFull so the tunnel comes up with filtering already armed.
                try {
                    val snapshot = RuleSnapshotStore.buildSnapshotJson(this, RuleDataset.NORMAL)
                    val snapshotError = goEngine.applyRuleSnapshot(snapshot)
                    if (snapshotError.isNotBlank()) {
                        Log.w(TAG, "applyRuleSnapshot failed: $snapshotError")
                    }
                    val rewriteRules = RuleSnapshotStore.buildRewriteRulesJson(this, RuleDataset.NORMAL)
                    if (rewriteRules.isNotBlank()) {
                        goEngine.setRewriteRules(rewriteRules)
                    }
                } catch (t: Throwable) {
                    Log.e(TAG, "Unable to build rule snapshot", t)
                    if (!stopping) {
                        fail("规则加载失败：${t.message ?: t.javaClass.simpleName}")
                        return@Thread
                    }
                }
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

    /// Flushes buffered traffic / HTTP rows; runs after the engine stopped, so nothing appends
    private fun closeDataPlane() {
        val plane = dataPlane
        dataPlane = null
        runCatching { plane?.close() }
    }

    private fun releaseResources() {
        runCatching { tun?.close() }
        tun = null
        worker = null
        // Stopped too: the failure path returns before `isRunning` is set, leaking a ticker.
        stopSpeedTicker()
        TrafficRateMonitor.reset()
        // The sweep belongs to the tunnel's lifetime; otherwise it outlives the service.
        LogRetention.stop()
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
            // Android 12+ requires foreground promotion inside onStartCommand; failing is a crash.
            Log.e(TAG, "startForeground failed", t)
        }
    }

    private fun buildNotification(): Notification =
        VpnNotification.build(this, CHANNEL_ID, NOTIFICATION_ID, ACTION_STOP)

    /// Ticks the notification's speed line; a daemon thread, as this module has no coroutines
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

        private const val LOG_DATABASE = "diting_database"

        /// `RuleDataset.NORMAL.prefsName()`: `log_retention_days` is dataset-scoped
        private const val LOG_PREFS = "dns_vpn_prefs"

        const val ACTION_START = "com.haoze.diting.START_VPN"
        const val ACTION_STOP = "com.haoze.diting.STOP_VPN"

        const val EXTRA_DNS_CONFIG = "dns_config"
        const val EXTRA_OUTBOUND_PROXY = "outbound_proxy"
        const val EXTRA_BYPASS_LAN = "bypass_lan"
        const val EXTRA_IPV6_MODE = "ipv6_mode"
        const val EXTRA_EXCLUDED_PACKAGES = "excluded_packages"

        /// `blocked_app_packages`: converted to UIDs for `setBlockedUIDs`
        const val EXTRA_BLOCKED_PACKAGES = "blocked_packages"

        /// `http_inspection_app_packages`: converted to UIDs for `setMitmAllowedUIDs`
        const val EXTRA_INSPECTION_PACKAGES = "inspection_packages"

        /// Precomputed by Dart: without the CA every HTTPS request in those apps breaks
        const val EXTRA_INSPECTION_ENABLED = "inspection_enabled"

        private const val CHANNEL_ID = "diting_vpn"
        private const val NOTIFICATION_ID = 1001

    /// Speed refresh cadence: 1 s with the screen on (the readout is per-second), 10 s off
    private const val SCREEN_ON_INTERVAL_MS = 1000L
    private const val SCREEN_OFF_INTERVAL_MS = 10_000L
        private const val PREFS_NAME = "dns_vpn_prefs"
        private const val KEY_VPN_RUNNING = "vpn_running"
        private const val KEY_LOG_MODE = "dns_log_mode"

        // Last start configuration, replayed by the quick settings tile.
        private const val KEY_LAST_DNS_CONFIG = "last_dns_config"
        private const val KEY_LAST_OUTBOUND_PROXY = "last_outbound_proxy"
        private const val KEY_LAST_BYPASS_LAN = "last_bypass_lan"
        private const val KEY_LAST_IPV6_MODE = "last_ipv6_mode"
        private const val KEY_LAST_EXCLUDED_PACKAGES = "last_excluded_packages"
        private const val KEY_LAST_BLOCKED_PACKAGES = "last_blocked_packages"
        private const val KEY_LAST_INSPECTION_PACKAGES = "last_inspection_packages"
        private const val KEY_LAST_INSPECTION_ENABLED = "last_inspection_enabled"

        /// Same directory the legacy app used: an upgraded install keeps its trusted root CA
        private const val MITM_DIR = "go-mitm"

        // Not wired from Flutter yet; an explicit disabled config stops Go logging a parse failure.
        private const val DEFAULT_OUTBOUND_PROXY =
            """{"enabled":false,"protocol":"SOCKS5","host":"127.0.0.1","port":7890,"username":"","password":""}"""

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        private var activeEngine: Engine? = null

        /// Read-only handle for the diagnostics channel
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

        fun setPersistedRunning(context: Context, value: Boolean) {
            context.setRunningFlag(value)
            // The tile lives in another UI surface; it only repaints when told to re-read.
            QuickSettingsTileUpdater.requestTileUpdate(context)
        }

        fun status(context: Context): Map<String, Any?> = mapOf(
            "running" to isRunning,
            "persisted" to isPersistedRunning(context),
            "error" to lastError,
            "stats" to EngineStats.snapshot(activeEngine),
        )

        /// Second-resolution TX/RX rates; zeros while stopped, or the last tick if racing the stop
        
        
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

        /// Rebuilds the last start intent so the tile can restart the tunnel without Dart, which
        /// is where the DNS config is computed. Null until the service was started at least once.
        fun restoreIntent(context: Context): Intent? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val dnsConfig = prefs.getString(KEY_LAST_DNS_CONFIG, null)
            if (dnsConfig.isNullOrBlank()) return null
            return startIntent(
                context = context,
                dnsConfig = dnsConfig,
                proxyJson = prefs.getString(KEY_LAST_OUTBOUND_PROXY, null)
                    ?: DEFAULT_OUTBOUND_PROXY,
                bypassLan = prefs.getBoolean(KEY_LAST_BYPASS_LAN, true),
                ipv6Mode = prefs.getString(KEY_LAST_IPV6_MODE, null) ?: "auto",
                excludedPackages = prefs.getStringSet(KEY_LAST_EXCLUDED_PACKAGES, null)
                    .orEmpty().toList(),
                blockedPackages = prefs.getStringSet(KEY_LAST_BLOCKED_PACKAGES, null)
                    .orEmpty().toList(),
                inspectionPackages = prefs.getStringSet(KEY_LAST_INSPECTION_PACKAGES, null)
                    .orEmpty().toList(),
                inspectionEnabled = prefs.getBoolean(KEY_LAST_INSPECTION_ENABLED, false),
            )
        }
    }
}
