package com.haoze.diting.express

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.haoze.diting.MainActivity
import com.haoze.diting.R
import com.haoze.diting.core.rule.RuleDataset
import com.haoze.diting.core.rule.RuleSnapshotStore
import com.haoze.diting.log.DnsLogWriter
import com.haoze.diting.log.EngineDataPlane
import com.haoze.diting.log.EngineStats
import com.haoze.diting.log.LogRetention
import com.haoze.diting.log.RaceLogWriter
import tunnel.BatchLogCallback
import tunnel.Engine
import tunnel.RaceLogCallback
import tunnel.SocketProtector

/// Express-mode VpnService: same Go engine as normal mode, but the TUN only owns DNS routes.
class ExpressVpnService : VpnService() {
    private var tun: ParcelFileDescriptor? = null
    private var engine: Engine? = null
    private var dataPlane: EngineDataPlane? = null

    @Volatile
    private var worker: Thread? = null

    @Volatile
    private var stopping = false

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
            proxyJson = intent.getStringExtra(EXTRA_OUTBOUND_PROXY).orEmpty(),
            ipv6Mode = intent.getStringExtra(EXTRA_IPV6_MODE) ?: "auto",
            excludedPackages = intent.getStringArrayListExtra(EXTRA_EXCLUDED_PACKAGES).orEmpty().toSet(),
        )
        return START_NOT_STICKY
    }

    @Synchronized
    private fun startTunnel(
        dnsConfig: String,
        proxyJson: String,
        ipv6Mode: String,
        excludedPackages: Set<String>,
    ) {
        if (engine != null) {
            Log.i(TAG, "express tunnel already running; ignoring duplicate start")
            return
        }
        stopping = false
        lastError = null

        val pfd = ExpressRouteConfig.establish(this, excludedPackages, ipv6Mode)
        if (pfd == null) {
            fail("无法建立极速模式接口")
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
            val logMode = getSharedPreferences(SETTINGS_PREFS, MODE_PRIVATE)
                .getString(KEY_LOG_MODE, DnsLogWriter.MODE_ALL)
                ?: DnsLogWriter.MODE_ALL
            goEngine.setBatchLogCallback(object : BatchLogCallback {
                override fun onDNSQueryBatch(jsonLogs: String) {
                    DnsLogWriter.writeBatch(this@ExpressVpnService, DnsLogWriter.DB_EXPRESS, logMode, jsonLogs)
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
                        this@ExpressVpnService,
                        DnsLogWriter.DB_EXPRESS,
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

            // Resolvers only: no user traffic crosses the narrow TUN and there is no MITM stage.
            val plane = EngineDataPlane(this, logMode)
            dataPlane = plane
            plane.attachResolvers(goEngine)
        } catch (t: Throwable) {
            Log.e(TAG, "Unable to configure Go engine", t)
            releaseResources()
            fail("极速模式配置失败：${t.message ?: t.javaClass.simpleName}")
            return
        }

        isRunning = true
        setPersistedRunning(this, true)
        // Express has its own log file, so no HTTP or traffic tables.
        LogRetention.start(
            context = this,
            databaseName = LOG_DATABASE,
            prefsName = LOG_PREFS,
            includeHttpAndTraffic = false,
        )
        worker = Thread({
            try {
                // Rules are built here, off the main thread: a stale index means a trie compile
                // that can take seconds, and onStartCommand would otherwise ANR the service.
                // Applied before startFull so the tunnel comes up with filtering already armed.
                try {
                    val snapshot = RuleSnapshotStore.buildSnapshotJson(this, RuleDataset.EXPRESS)
                    val snapshotError = goEngine.applyRuleSnapshot(snapshot)
                    if (snapshotError.isNotBlank()) {
                        Log.w(TAG, "applyRuleSnapshot failed: $snapshotError")
                    }
                    val rewriteRules = RuleSnapshotStore.buildRewriteRulesJson(this, RuleDataset.EXPRESS)
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
                Log.i(TAG, "Go express tunnel exited")
            } catch (t: Throwable) {
                Log.e(TAG, "Go express tunnel crashed", t)
                if (!stopping) {
                    fail("极速模式运行异常：${t.message ?: t.javaClass.simpleName}")
                }
            }
        }, "diting-express-tunnel").also { it.start() }
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

    /// Drops the resolver callbacks; no log writers are attached in this mode
    private fun closeDataPlane() {
        val plane = dataPlane
        dataPlane = null
        runCatching { plane?.close() }
    }

    private fun releaseResources() {
        runCatching { tun?.close() }
        tun = null
        worker = null
        // Retention sweep is bound to the tunnel lifetime, not the process.
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
            Log.e(TAG, "startForeground failed", t)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, ExpressVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val label = applicationInfo.loadLabel(packageManager).toString()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("$label · 极速")
            .setContentText("极速模式运行中，仅接管 DNS 查询")
            .setContentIntent(openIntent)
            .addAction(0, "停止", stopIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "极速模式",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "保持 DNS 窄路由 VPN 运行"
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
        private const val TAG = "ExpressVpnService"

        /// Log database of this mode (RuleDataset.EXPRESS, version 2)
        private const val LOG_DATABASE = "diting_express"

        /// Separate retention window; not shared with normal mode
        private const val LOG_PREFS = "diting_express_prefs"

        const val ACTION_START = "com.haoze.diting.express.START_VPN"
        const val ACTION_STOP = "com.haoze.diting.express.STOP_VPN"

        const val EXTRA_DNS_CONFIG = "dns_config"
        const val EXTRA_OUTBOUND_PROXY = "outbound_proxy"
        const val EXTRA_IPV6_MODE = "ipv6_mode"
        const val EXTRA_EXCLUDED_PACKAGES = "excluded_packages"

        private const val CHANNEL_ID = "channel_express"
        private const val NOTIFICATION_ID = 2003
        private const val PREFS_NAME = "express_vpn_prefs"
        private const val KEY_VPN_RUNNING = "express_vpn_running"
        private const val KEY_LOG_MODE = "dns_log_mode"
        private const val SETTINGS_PREFS = "diting_express_prefs"

        private const val DEFAULT_OUTBOUND_PROXY =
            """{"enabled":false,"protocol":"SOCKS5","host":"127.0.0.1","port":7890,"username":"","password":""}"""

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        private var activeEngine: Engine? = null

        
        internal fun engineForDiagnostics(): Engine? = activeEngine

        @Volatile
        var lastError: String? = null

        fun isPersistedRunning(context: Context): Boolean =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_VPN_RUNNING, false)

        fun setPersistedRunning(context: Context, value: Boolean) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_VPN_RUNNING, value)
                .apply()
        }

        fun status(context: Context): Map<String, Any?> = mapOf(
            "running" to isRunning,
            "persisted" to isPersistedRunning(context),
            "error" to lastError,
            "stats" to EngineStats.snapshot(activeEngine),
        )

        fun startIntent(
            context: Context,
            dnsConfig: String,
            proxyJson: String,
            ipv6Mode: String,
            excludedPackages: List<String>,
        ): Intent = Intent(context, ExpressVpnService::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_DNS_CONFIG, dnsConfig)
            putExtra(EXTRA_OUTBOUND_PROXY, proxyJson)
            putExtra(EXTRA_IPV6_MODE, ipv6Mode)
            putStringArrayListExtra(EXTRA_EXCLUDED_PACKAGES, ArrayList(excludedPackages))
        }

        fun stopIntent(context: Context): Intent =
            Intent(context, ExpressVpnService::class.java).setAction(ACTION_STOP)
    }
}
