package com.haoze.diting.express

import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import com.haoze.diting.crash.CrashBreadcrumbs
import com.haoze.diting.data.RuleDataset
import com.haoze.diting.express.notification.ExpressNotificationBuilder
import com.haoze.diting.notification.VpnMonitorManager
import com.haoze.diting.ui.DnsResolutionMode
import com.haoze.diting.ui.PermissionDisclosureSettings
import com.haoze.diting.ui.settings.AppRulesSettingsStore
import com.haoze.diting.ui.settings.DnsCacheSettingsStore
import com.haoze.diting.ui.settings.ResolutionSettingsStore
import com.haoze.diting.ui.settings.SystemSettingsStore
import com.haoze.diting.core.dns.DnsProtocol
import com.haoze.diting.core.dns.DnsProvider
import com.haoze.diting.ui.floating.FloatingLogOverlayController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.net.DatagramSocket
import java.net.Socket

/**
 * Pure Kotlin VpnService implementation dedicated to Express Mode.
 *
 * Implements narrow DNS TUN routing, public DNS hijacking, lightweight
 * DNS engine resolution, and independent foreground notifications.
 */
class ExpressVpnService : VpnService() {

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val tunnelManager = ExpressTunnelManager()
    // Invalidates an in-flight start when a stop lands mid-start; see the class doc.
    private val lifecycleGuard = ExpressLifecycleGuard()
    private lateinit var floatingLogOverlay: FloatingLogOverlayController

    private var startIntent: Intent? = null
    private var wasStopped = false
    private var activeProviders: List<DnsProvider> = emptyList()
    private var activeResolutionMode: DnsResolutionMode = DnsResolutionMode.SINGLE
    private var defaultsSeedJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        isServiceAlive = true
        activeService = this
        floatingLogOverlay = FloatingLogOverlayController(this, RuleDataset.EXPRESS)
        ExpressNotificationBuilder.ensureChannel(this)
        // Seed off the main thread: on first launch this opens the Express DB,
        // rebuilds the trie indexes and syncs WorkManager. It must not block
        // onCreate(), otherwise startForeground() may miss the Android 12+
        // foreground-service start deadline.
        defaultsSeedJob = serviceScope.launch {
            ExpressDefaultsSeeder.ensureInitialized(this@ExpressVpnService)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ExpressVpnIntents.ACTION_STOP -> stopVpn()
            ExpressVpnIntents.ACTION_REFRESH_CONFIG -> refreshConfig(intent)
            ExpressVpnIntents.ACTION_SYNC_RULES -> tunnelManager.syncRules(serviceScope)
            ExpressVpnIntents.ACTION_CLEAR_CACHE -> tunnelManager.clearCache()
            ExpressVpnIntents.ACTION_REFRESH_FLOATING_LOG -> {
                if (::floatingLogOverlay.isInitialized) floatingLogOverlay.refreshSettings()
            }
            ExpressVpnIntents.ACTION_FLOATING_LOG_APP_STATE -> {
                val foreground = intent.getBooleanExtra(ExpressVpnIntents.EXTRA_APP_FOREGROUND, true)
                SystemSettingsStore.setMainActivityForeground(this, foreground)
                if (::floatingLogOverlay.isInitialized) floatingLogOverlay.setAppInForeground(foreground)
            }
            else -> startVpn(intent)
        }
        return START_STICKY
    }

    private fun startVpn(intent: Intent?) {
        if (tunnelManager.vpnInterface != null) {
            ExpressVpnController.onServiceStateChanged(this, true)
            return
        }
        val startToken = lifecycleGuard.beginStart()
        startIntent = intent
        activeResolutionMode = ResolutionSettingsStore.getDnsResolutionMode(this, RuleDataset.EXPRESS)
        activeProviders = resolveActiveProviders(intent)

        CrashBreadcrumbs.record("ExpressVPN", "Starting Express VPN, mode=${activeResolutionMode.name}")

        // Bring service to foreground immediately to fulfill Android 8.0+ system requirement
        updateForegroundNotification()

        val ipv6Mode = SystemSettingsStore.getIpv6Mode(this, RuleDataset.EXPRESS)
        val pfd = tunnelManager.establishVpnInterface(this, ipv6Mode) ?: run {
            Log.e(TAG, "Failed to establish VPN interface")
            PermissionDisclosureSettings.updateVpnGrant(this, false)
            ExpressVpnController.onServiceStateChanged(this, false)
            stopForegroundCompat()
            stopSelf()
            return
        }

        // Rule caches must be loaded before the TUN reader answers queries, so
        // start() is suspending and runs here rather than blocking onStartCommand.
        serviceScope.launch(Dispatchers.IO) {
            defaultsSeedJob?.join()
            val started = tunnelManager.start(
                service = this@ExpressVpnService,
                pfd = pfd,
                scope = serviceScope,
                providersProvider = { activeProviders },
                resolutionModeProvider = { activeResolutionMode },
                blockResponseModeProvider = { AppRulesSettingsStore.getBlockResponseMode(this@ExpressVpnService, RuleDataset.EXPRESS) },
                domainRulesEnabledProvider = { AppRulesSettingsStore.isDomainRulesEnabled(this@ExpressVpnService, RuleDataset.EXPRESS) },
                cachePolicyProvider = { DnsCacheSettingsStore.getDnsCachePolicy(this@ExpressVpnService, RuleDataset.EXPRESS) },
                dnsLogModeProvider = { SystemSettingsStore.getDnsLogMode(this@ExpressVpnService, RuleDataset.EXPRESS) }
            )
            // A stop that landed while the rule caches loaded already closed the
            // interface and reported the service stopped. Publishing "running"
            // here would resurrect a data plane over a closed descriptor, so tear
            // the start down instead of reporting a tunnel nobody can use.
            if (!lifecycleGuard.canPublishRunning(startToken)) {
                if (started) tunnelManager.stop()
                runCatching { pfd.close() }
                Log.i(TAG, "Discarding Express tunnel: service stopped while starting")
                return@launch
            }
            if (!started) {
                Log.e(TAG, "Failed to start Express tunnel data plane")
                runCatching { pfd.close() }
                ExpressVpnController.onServiceStateChanged(this@ExpressVpnService, false)
                stopForegroundCompat()
                stopSelf()
                return@launch
            }

            updateForegroundNotification()
            floatingLogOverlay.setVpnRunning(true)
            VpnMonitorManager.onVpnStarted(this@ExpressVpnService)
            ExpressVpnController.onServiceStateChanged(this@ExpressVpnService, true)
        }
    }

    private fun updateForegroundNotification() {
        val notification = ExpressNotificationBuilder.build(
            this,
            activeProviders,
            activeResolutionMode
        )
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    ExpressNotificationBuilder.NOTIFICATION_ID_EXPRESS_VPN,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(
                    ExpressNotificationBuilder.NOTIFICATION_ID_EXPRESS_VPN,
                    notification
                )
            }
        }.onFailure {
            runCatching {
                startForeground(
                    ExpressNotificationBuilder.NOTIFICATION_ID_EXPRESS_VPN,
                    notification
                )
            }
        }
    }

    private fun refreshConfig(intent: Intent?) {
        activeResolutionMode = ResolutionSettingsStore.getDnsResolutionMode(this, RuleDataset.EXPRESS)
        activeProviders = resolveActiveProviders(intent)
        updateForegroundNotification()
    }

    private fun stopForegroundCompat() {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        }
        runCatching {
            NotificationManagerCompat.from(this).cancel(ExpressNotificationBuilder.NOTIFICATION_ID_EXPRESS_VPN)
        }
    }

    private fun stopVpn() {
        CrashBreadcrumbs.record("ExpressVPN", "stopVpn called")
        lifecycleGuard.onStopRequested()
        wasStopped = true
        if (::floatingLogOverlay.isInitialized) floatingLogOverlay.setVpnRunning(false)
        ExpressVpnController.onServiceStateChanged(this, false)
        tunnelManager.stop()
        stopForegroundCompat()
        VpnMonitorManager.onVpnStopped(this)
        stopSelf()
    }

    override fun onRevoke() {
        super.onRevoke()
        Log.w(TAG, "VPN permission revoked, stopping ExpressVpnService")
        PermissionDisclosureSettings.updateVpnGrant(this, false)
        wasStopped = false
        stopVpn()
    }

    override fun onDestroy() {
        CrashBreadcrumbs.record("ExpressVPN", "ExpressVpnService onDestroy")
        lifecycleGuard.onStopRequested()
        if (::floatingLogOverlay.isInitialized) floatingLogOverlay.destroy()
        isServiceAlive = false
        if (activeService === this) activeService = null
        ExpressVpnController.onServiceStateChanged(this, false)
        tunnelManager.stop()
        serviceScope.cancel()
        stopForegroundCompat()
        if (!wasStopped) {
            VpnMonitorManager.onVpnStopped(this)
        }
        super.onDestroy()
    }

    private fun resolveActiveProviders(intent: Intent?): List<DnsProvider> {
        val protocol = DnsProtocol.fromStorage(intent?.getStringExtra(ExpressVpnIntents.EXTRA_DNS_PROTOCOL))
        val url = intent?.getStringExtra(ExpressVpnIntents.EXTRA_DOH_URL)
        if (!url.isNullOrBlank()) {
            val name = intent.getStringExtra(ExpressVpnIntents.EXTRA_DNS_NAME)?.takeIf { it.isNotBlank() } ?: "自定义"
            return listOf(
                DnsProvider(
                    id = DnsProvider.runtimeCustomProviderId(url),
                    name = name,
                    protocol = DnsProtocol.DOH,
                    url = url,
                    isPreset = false
                )
            )
        }
        if (protocol == DnsProtocol.DOT || protocol == DnsProtocol.DNS) {
            val host = intent?.getStringExtra(ExpressVpnIntents.EXTRA_DNS_HOST)
            if (!host.isNullOrBlank()) {
                val port = intent.getIntExtra(ExpressVpnIntents.EXTRA_DNS_PORT, DnsProvider.DEFAULT_DOT_PORT)
                val name = intent.getStringExtra(ExpressVpnIntents.EXTRA_DNS_NAME)?.takeIf { it.isNotBlank() } ?: "自定义"
                return listOf(
                    DnsProvider(
                        id = DnsProvider.runtimeCustomProviderId("$host:$port"),
                        name = name,
                        protocol = protocol,
                        host = host,
                        port = port,
                        isPreset = false
                    )
                )
            }
        }
        val mode = ResolutionSettingsStore.getDnsResolutionMode(this, RuleDataset.EXPRESS)
        when (mode) {
            DnsResolutionMode.SINGLE -> Unit
            DnsResolutionMode.SMART_PREDICTION,
            DnsResolutionMode.PARALLEL_RACE -> {
                val ids = if (mode == DnsResolutionMode.SMART_PREDICTION) {
                    ResolutionSettingsStore.getSmartPredictionProviderIds(this, RuleDataset.EXPRESS)
                } else {
                    ResolutionSettingsStore.getParallelRaceProviderIds(this, RuleDataset.EXPRESS)
                }
                val raceProviders = DnsProvider.loadRuntimeProviders(this, RuleDataset.EXPRESS).filter { it.id in ids }
                if (raceProviders.size >= 2) return raceProviders
            }
            DnsResolutionMode.PRIMARY_BACKUP -> {
                val byId = DnsProvider.loadRuntimeProviders(this, RuleDataset.EXPRESS).associateBy { it.id }
                val ordered = ResolutionSettingsStore.getPrimaryBackupProviderIds(this, RuleDataset.EXPRESS).mapNotNull(byId::get)
                if (ordered.size >= 2) return ordered
            }
        }
        return listOf(DnsProvider.loadSelected(this, RuleDataset.EXPRESS))
    }

    companion object {
        private const val TAG = "ExpressVpnService"

        @Volatile
        var isServiceAlive: Boolean = false
            internal set

        @Volatile
        private var activeService: ExpressVpnService? = null

        fun protectSocket(socket: Socket): Boolean =
            activeService?.protect(socket) ?: false

        fun protectDatagramSocket(socket: DatagramSocket): Boolean =
            activeService?.protect(socket) ?: false

        fun protectFd(fd: Int): Boolean =
            activeService?.protect(fd) ?: false
    }
}
