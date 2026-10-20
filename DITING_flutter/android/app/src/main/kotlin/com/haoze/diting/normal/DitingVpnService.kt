package com.haoze.diting.normal

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
import com.haoze.diting.log.DnsLogWriter
import com.haoze.diting.log.EngineStats
import com.haoze.diting.log.RaceLogWriter
import tunnel.BatchLogCallback
import tunnel.Engine
import tunnel.RaceLogCallback
import tunnel.SocketProtector

/// Full-tunnel VpnService backed by the unchanged 1.4.3 Go engine.
///
/// The Dart layer owns every policy decision; this service only applies the
/// DNS config / rule snapshot / rewrite map it receives, then hands the TUN
/// descriptor to `Engine.startFull`. All engine knobs must be set before
/// `startFull`, because the Go call blocks for the lifetime of the tunnel.
class DitingVpnService : VpnService() {
    private var tun: ParcelFileDescriptor? = null
    private var engine: Engine? = null

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
            ruleSnapshot = intent.getStringExtra(EXTRA_RULE_SNAPSHOT).orEmpty(),
            rewriteRules = intent.getStringExtra(EXTRA_REWRITE_RULES).orEmpty(),
            proxyJson = intent.getStringExtra(EXTRA_OUTBOUND_PROXY).orEmpty(),
            bypassLan = intent.getBooleanExtra(EXTRA_BYPASS_LAN, true),
            ipv6Mode = intent.getStringExtra(EXTRA_IPV6_MODE) ?: "auto",
            excludedPackages = intent.getStringArrayListExtra(EXTRA_EXCLUDED_PACKAGES).orEmpty().toSet(),
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
        } catch (t: Throwable) {
            Log.e(TAG, "Unable to configure Go engine", t)
            releaseResources()
            fail("隧道配置失败：${t.message ?: t.javaClass.simpleName}")
            return
        }

        isRunning = true
        setPersistedRunning(this, true)
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
        releaseResources()
        isRunning = false
        setPersistedRunning(this, false)
        stopForegroundCompat()
        stopSelf()
    }

    private fun releaseResources() {
        runCatching { tun?.close() }
        tun = null
        worker = null
    }

    private fun fail(message: String) {
        lastError = message
        isRunning = false
        activeEngine = null
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
        if (engine != null || isRunning) {
            stopping = true
            val current = engine
            engine = null
            activeEngine = null
            runCatching { current?.stop() }
            runCatching { current?.stopStackMitm() }
            runCatching { current?.releaseTun() }
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
            Intent(this, DitingVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val label = applicationInfo.loadLabel(packageManager).toString()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(label)
            .setContentText("VPN 正在运行")
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

        private const val CHANNEL_ID = "diting_vpn"
        private const val NOTIFICATION_ID = 1001
        private const val PREFS_NAME = "dns_vpn_prefs"
        private const val KEY_VPN_RUNNING = "vpn_running"
        private const val KEY_LOG_MODE = "dns_log_mode"

        // Outbound proxy is not wired from Flutter yet; an explicit disabled
        // config keeps the Go side from logging a parse failure on every start.
        private const val DEFAULT_OUTBOUND_PROXY =
            """{"enabled":false,"protocol":"SOCKS5","host":"127.0.0.1","port":7890,"username":"","password":""}"""

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        private var activeEngine: Engine? = null

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

        fun startIntent(
            context: Context,
            dnsConfig: String,
            ruleSnapshot: String,
            rewriteRules: String,
            proxyJson: String,
            bypassLan: Boolean,
            ipv6Mode: String,
            excludedPackages: List<String>,
        ): Intent = Intent(context, DitingVpnService::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_DNS_CONFIG, dnsConfig)
            putExtra(EXTRA_RULE_SNAPSHOT, ruleSnapshot)
            putExtra(EXTRA_REWRITE_RULES, rewriteRules)
            putExtra(EXTRA_OUTBOUND_PROXY, proxyJson)
            putExtra(EXTRA_BYPASS_LAN, bypassLan)
            putExtra(EXTRA_IPV6_MODE, ipv6Mode)
            putStringArrayListExtra(EXTRA_EXCLUDED_PACKAGES, ArrayList(excludedPackages))
        }

        fun stopIntent(context: Context): Intent =
            Intent(context, DitingVpnService::class.java).setAction(ACTION_STOP)
    }
}
