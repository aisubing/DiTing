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
import com.haoze.diting.ui.localizedResource
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
        // 只建本服务要用的渠道，并且必须在造通知之前完成。
        AppNotificationChannels.ensureMonitorChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Android 12+：startForegroundService() 之后必须尽快成功 startForeground()。
        // 任何提前返回的分支都必须先把前台提升做完，否则一旦记录被拆除，AMS 会立刻
        // 抛出 ForegroundServiceDidNotStartInTimeException 杀掉进程。
        val promoted = startForegroundCompat()

        // 提升失败说明前台义务没兑现：此时绝不能 stopSelf()（会触发同一个崩溃），
        // 保持服务存活并等下一轮同步重试。
        if (!promoted) {
            Log.e(TAG, "startForeground() failed; keeping service alive to avoid foreground crash")
            return START_STICKY
        }
        VpnMonitorManager.onServicePromoted()

        // 提升已完成，此后 stopSelf() / stopService() 都是安全的。
        if (intent?.action == ACTION_STOP_MONITOR || shouldStopNow()) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        return START_STICKY
    }

    override fun onDestroy() {
        isServiceAlive = false
        VpnMonitorManager.onServiceDestroyed()
        stopForegroundCompat()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * 校验当前是否应当停止：显式停止请求，或设置/权限/VPN 状态不再允许常驻通知。
     */
    private fun shouldStopNow(): Boolean {
        if (VpnMonitorManager.isStopRequested()) return true
        return WorkModeStore.getAppWorkMode(this) == AppWorkMode.DNS ||
            !NotificationSettingsStore.isPersistentNotificationEnabled(this) ||
            !NotificationPermissionHelper.hasPermission(this) ||
            VpnMonitorManager.isVpnRunning(this)
    }

    /**
     * @return 是否成功进入前台状态。
     */
    private fun startForegroundCompat(): Boolean {
        val notification = buildStoppedNotification()
        val firstAttempt = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID_VPN_MONITOR,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID_VPN_MONITOR, notification)
            }
        }
        if (firstAttempt.isSuccess) return true

        Log.w(TAG, "Failed to startForeground with specialUse type, retrying fallback", firstAttempt.exceptionOrNull())
        val fallback = runCatching {
            startForeground(NOTIFICATION_ID_VPN_MONITOR, notification)
        }
        if (fallback.isSuccess) return true

        Log.e(TAG, "Failed to enter foreground", fallback.exceptionOrNull())
        return false
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
            localizedResource(this, R.string.vpn_disconnected)
        }

        return NotificationCompat.Builder(this, AppNotificationChannels.CHANNEL_VPN_MONITOR)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(localizedResource(this, R.string.app_name))
            .setContentText(contentText)
            .setContentIntent(openAppPendingIntent)
            .addAction(R.drawable.ic_play_arrow, localizedResource(this, R.string.vpn_start), openAppPendingIntent)
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
