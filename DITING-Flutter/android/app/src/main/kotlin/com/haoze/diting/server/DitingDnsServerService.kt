package com.haoze.diting.server

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.haoze.diting.MainActivity
import com.haoze.diting.R
import com.haoze.diting.core.rule.RuleDataset
import com.haoze.diting.core.rule.RuleSnapshotStore
import com.haoze.diting.log.DnsLogWriter
import com.haoze.diting.log.EngineStats
import com.haoze.diting.log.RaceLogWriter
import tunnel.BatchLogCallback
import tunnel.Engine
import tunnel.RaceLogCallback
import java.util.concurrent.atomic.AtomicInteger

/// LAN DNS server backed by the same Go engine as the tunnels. `startStandalone` returns
/// once both listeners are up, so unlike the VPN path it owns no thread. Config must be
/// applied before the bind: answering the first queries with an empty rule set leaks.
class DitingDnsServerService : Service() {
    private var engine: Engine? = null
    private val generation = AtomicInteger(0)
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): android.os.IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        promoteToForeground(intent?.getIntExtra(EXTRA_PORT, DEFAULT_PORT) ?: DEFAULT_PORT)
        if (intent?.action == ACTION_STOP) {
            stopEngine()
            return START_NOT_STICKY
        }
        val dnsConfig = intent?.getStringExtra(EXTRA_DNS_CONFIG)
        if (dnsConfig.isNullOrBlank()) {
            Log.w(TAG, "start intent without DNS config")
            stopEngine()
            return START_NOT_STICKY
        }
        if (isRunning) {
            Log.i(TAG, "server already running; ignoring duplicate start")
            return START_NOT_STICKY
        }
        // Persisted so a reboot can rebuild the same intent; the extras themselves die with it.
        // Rules are not part of it: the engine snapshot is rebuilt from the rule database
        // (legacy behavior), so a persisted snapshot would only go stale after rule edits.
        rememberStartConfig(
            port = intent.getIntExtra(EXTRA_PORT, DEFAULT_PORT),
            dnsConfig = dnsConfig,
            adBlockEnabled = intent.getBooleanExtra(EXTRA_AD_BLOCK_ENABLED, false),
        )
        startEngine(
            port = intent.getIntExtra(EXTRA_PORT, DEFAULT_PORT),
            dnsConfig = dnsConfig,
            adBlockEnabled = intent.getBooleanExtra(EXTRA_AD_BLOCK_ENABLED, false),
        )
        return START_NOT_STICKY
    }

    private fun startEngine(
        port: Int,
        dnsConfig: String,
        adBlockEnabled: Boolean,
    ) {
        val token = generation.incrementAndGet()
        acquireLocks()
        Thread({
            try {
                val created = Engine()
                created.applyDNSConfig(dnsConfig)
                // DNS_MODE keeps every rule inline (no trie files, like the legacy server mode);
                // built here in-process, so the rule set size never crosses the Binder limit.
                val error = created.applyRuleSnapshot(
                    RuleSnapshotStore.buildSnapshotJson(this, RuleDataset.DNS_MODE)
                )
                if (error.isNotBlank()) Log.w(TAG, "applyRuleSnapshot: $error")
                val rewriteRules = RuleSnapshotStore.buildRewriteRulesJson(this, RuleDataset.DNS_MODE)
                if (rewriteRules.isNotBlank()) {
                    created.setRewriteRules(rewriteRules)
                }
                created.setFilterDNS(adBlockEnabled)
                val logMode = if (
                    getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getBoolean(KEY_LOG_QUERIES, false)
                ) {
                    DnsLogWriter.MODE_ALL
                } else {
                    DnsLogWriter.MODE_OFF
                }
                created.setBatchLogCallback(object : BatchLogCallback {
                    override fun onDNSQueryBatch(jsonLogs: String) {
                        DnsLogWriter.writeBatch(
                            this@DitingDnsServerService,
                            DnsLogWriter.DB_NORMAL,
                            logMode,
                            jsonLogs,
                        )
                    }
                })
                created.setRaceLogCallback(object : RaceLogCallback {
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
                            this@DitingDnsServerService,
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
                created.startStandalone(port.toLong())
                if (generation.get() != token) {
                    Log.i(TAG, "discarding DNS engine: stop requested during start")
                    runCatching { created.stopStandalone() }
                    runCatching { created.stop() }
                    return@Thread
                }
                engine = created
                activeEngine = created
                isRunning = true
                lastError = null
                setServiceActive(this, true)
                Log.i(TAG, "standalone DNS server listening on 0.0.0.0:$port (UDP & TCP)")
            } catch (t: Throwable) {
                Log.e(TAG, "Unable to start standalone DNS server", t)
                if (generation.get() == token) {
                    fail("DNS 服务启动失败：${t.message ?: t.javaClass.simpleName}")
                }
            }
        }, "diting-dns-server").start()
    }

    private fun stopEngine() {
        generation.incrementAndGet()
        val current = engine
        engine = null
        activeEngine = null
        runCatching { current?.stopStandalone() }
            .onFailure { Log.w(TAG, "stopStandalone failed", it) }
        runCatching { current?.stop() }
        isRunning = false
        setServiceActive(this, false)
        releaseLocks()
        stopForegroundCompat()
        stopSelf()
    }

    private fun fail(message: String) {
        lastError = message
        isRunning = false
        activeEngine = null
        setServiceActive(this, false)
        releaseLocks()
        stopForegroundCompat()
        stopSelf()
    }

    override fun onDestroy() {
        generation.incrementAndGet()
        val current = engine
        engine = null
        activeEngine = null
        runCatching { current?.stopStandalone() }
        runCatching { current?.stop() }
        isRunning = false
        setServiceActive(this, false)
        releaseLocks()
        stopForegroundCompat()
        super.onDestroy()
    }

    /// Stores the running configuration so `DnsModeBootReceiver` can restart the service with the
    /// same settings; only the boolean flag survived a reboot before, so the restart had no config.
    private fun rememberStartConfig(
        port: Int,
        dnsConfig: String,
        adBlockEnabled: Boolean,
    ) {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
            .putInt(KEY_LOCAL_PORT, port)
            .putString(KEY_LAST_DNS_CONFIG, dnsConfig)
            .putBoolean(KEY_LAST_AD_BLOCK_ENABLED, adBlockEnabled)
            .apply()
    }

    private fun acquireLocks() {
        runCatching {
            if (wakeLock == null) {
                val power = getSystemService(Context.POWER_SERVICE) as? PowerManager
                wakeLock = power?.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "Diting:DnsServerWakeLock",
                )?.apply {
                    setReferenceCounted(false)
                    acquire()
                }
            }
            if (wifiLock == null) {
                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                @Suppress("DEPRECATION")
                wifiLock = wifi?.createWifiLock(
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                    "Diting:DnsServerWifiLock",
                )?.apply {
                    setReferenceCounted(false)
                    acquire()
                }
            }
        }.onFailure { Log.w(TAG, "Failed to acquire power/wifi locks", it) }
    }

    private fun releaseLocks() {
        runCatching { wakeLock?.takeIf { it.isHeld }?.release() }
        runCatching { wifiLock?.takeIf { it.isHeld }?.release() }
        wakeLock = null
        wifiLock = null
    }

    private fun promoteToForeground(port: Int) {
        val notification = buildNotification(port)
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

    private fun buildNotification(port: Int): Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, DitingDnsServerService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val label = applicationInfo.loadLabel(packageManager).toString()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("$label · 服务器模式运行中")
            .setContentText("正在监听端口 $port（UDP/TCP）")
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
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "服务器模式",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "显示服务器模式的运行状态"
                setShowBadge(false)
            },
        )
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
        private const val TAG = "DitingDnsServerService"
        private const val CHANNEL_ID = "channel_dns_mode"
        private const val NOTIFICATION_ID = 2002
        private const val DEFAULT_PORT = 1053
        private const val PREFS_NAME = "diting_dns_mode_prefs"
        private const val KEY_SERVICE_ACTIVE = "service_active"
        private const val KEY_LOCAL_PORT = "local_listen_port"
        private const val KEY_LOG_QUERIES = "log_queries"

        // Last start configuration, replayed by DnsModeBootReceiver after a reboot.
        private const val KEY_LAST_DNS_CONFIG = "last_dns_config"
        private const val KEY_LAST_AD_BLOCK_ENABLED = "last_ad_block_enabled"

        const val ACTION_START = "com.haoze.diting.server.START"
        const val ACTION_STOP = "com.haoze.diting.server.STOP"

        const val EXTRA_PORT = "port"
        const val EXTRA_DNS_CONFIG = "dns_config"
        const val EXTRA_AD_BLOCK_ENABLED = "ad_block_enabled"

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        private var activeEngine: Engine? = null

        /// Read-only handle for the diagnostics channel; never expose a setter
        internal fun engineForDiagnostics(): Engine? = activeEngine

        @Volatile
        var lastError: String? = null

        fun isServiceActive(context: Context): Boolean =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_SERVICE_ACTIVE, false)

        fun setServiceActive(context: Context, active: Boolean) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_SERVICE_ACTIVE, active)
                .apply()
        }

        fun status(context: Context): Map<String, Any?> = mapOf(
            "running" to isRunning,
            "persisted" to isServiceActive(context),
            "error" to lastError,
            "stats" to EngineStats.snapshot(activeEngine),
            "port" to context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getInt(KEY_LOCAL_PORT, DEFAULT_PORT),
        )

        fun startIntent(
            context: Context,
            port: Int,
            dnsConfig: String,
            adBlockEnabled: Boolean,
        ): Intent = Intent(context, DitingDnsServerService::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_PORT, port)
            putExtra(EXTRA_DNS_CONFIG, dnsConfig)
            putExtra(EXTRA_AD_BLOCK_ENABLED, adBlockEnabled)
        }

        fun stopIntent(context: Context): Intent =
            Intent(context, DitingDnsServerService::class.java).setAction(ACTION_STOP)

        /// Rebuilds the last start intent from preferences; null when none was ever stored,
        /// which means the service ran in a build without config persistence.
        fun restoreIntent(context: Context): Intent? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val dnsConfig = prefs.getString(KEY_LAST_DNS_CONFIG, null)
            if (dnsConfig.isNullOrBlank()) return null
            return startIntent(
                context = context,
                port = prefs.getInt(KEY_LOCAL_PORT, DEFAULT_PORT),
                dnsConfig = dnsConfig,
                adBlockEnabled = prefs.getBoolean(KEY_LAST_AD_BLOCK_ENABLED, false),
            )
        }
    }
}
