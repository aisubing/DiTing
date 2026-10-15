package com.haoze.diting.notification

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.haoze.diting.MainActivity
import com.haoze.diting.R
import com.haoze.diting.ui.mode.AppWorkMode
import com.haoze.diting.ui.mode.WorkModeStore

/**
 * Foreground monitor service that keeps a persistent notification with a
 * quick-connect shortcut in the shade while the VPN is not running.
 */
class VpnMonitorService : Service() {

    override fun onCreate() {
        super.onCreate()
        isServiceAlive = true
        AppNotificationChannels.createAllChannels(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Android 12+ requires startForeground() promptly after startForegroundService().
        // Stop requests or failing preconditions MUST still call startForeground() first
        // before stopping to avoid ForegroundServiceDidNotStartInTimeException.
        startForegroundCompat()

        if (intent?.action == ACTION_STOP_MONITOR) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        // Validate the enable setting, notification permission, and VPN state
        if (WorkModeStore.getAppWorkMode(this) == AppWorkMode.DNS ||
            !NotificationSettingsStore.isPersistentNotificationEnabled(this) ||
            !NotificationPermissionHelper.hasPermission(this) ||
            VpnMonitorManager.isVpnRunning(this)
        ) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        return START_STICKY
    }

    override fun onDestroy() {
        isServiceAlive = false
        stopForegroundCompat()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startForegroundCompat() {
        val notification = buildStoppedNotification()
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID_VPN_MONITOR,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID_VPN_MONITOR, notification)
            }
        }.onFailure { e ->
            Log.w(TAG, "Failed to startForeground with specialUse type, retrying fallback", e)
            runCatching {
                startForeground(NOTIFICATION_ID_VPN_MONITOR, notification)
            }.onFailure { e2 ->
                Log.e(TAG, "Failed to enter foreground", e2)
            }
        }
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
            androidx.core.app.NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID_VPN_MONITOR)
        }
    }

    private fun buildStoppedNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_AUTO_START_VPN, true)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            1,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val customText = NotificationSettingsStore.getCustomStoppedText(this)
        val contentText = if (customText.isNotBlank()) {
            customText
        } else {
            getString(R.string.vpn_disconnected)
        }

        return NotificationCompat.Builder(this, AppNotificationChannels.CHANNEL_VPN_MONITOR)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(contentText)
            .setContentIntent(openAppPendingIntent)
            .addAction(R.drawable.ic_play_arrow, getString(R.string.vpn_start), openAppPendingIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    companion object {
        private const val TAG = "VpnMonitorService"
        const val NOTIFICATION_ID_VPN_MONITOR = 1002
        private const val ACTION_STOP_MONITOR = "com.haoze.diting.notification.STOP_MONITOR"

        @Volatile
        var isServiceAlive: Boolean = false
            internal set

        fun startIntent(context: Context): Intent {
            return Intent(context, VpnMonitorService::class.java)
        }

        fun stopIntent(context: Context): Intent {
            return Intent(context, VpnMonitorService::class.java).setAction(ACTION_STOP_MONITOR)
        }
    }
}
