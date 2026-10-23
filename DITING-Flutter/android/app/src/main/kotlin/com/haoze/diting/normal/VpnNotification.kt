package com.haoze.diting.normal

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.haoze.diting.MainActivity
import com.haoze.diting.R
import com.haoze.diting.log.TrafficRateMonitor
import com.haoze.diting.platform.NotificationSettings

/// Builds the full-tunnel foreground notification. The channel id and stop action stay owned by
/// the service: a channel id cannot be renamed without losing the user's importance setting. The
/// notification is rebuilt every second while the speed readout is on, hence setOnlyAlertOnce.
object VpnNotification {
    fun build(
        context: Context,
        channelId: String,
        notificationId: Int,
        stopAction: String,
    ): Notification {
        val openIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stopIntent = PendingIntent.getService(
            context,
            1,
            Intent(context, DitingVpnService::class.java).setAction(stopAction),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val label = context.applicationInfo.loadLabel(context.packageManager).toString()
        
        val status = NotificationSettings.contentText(
            context,
            running = true,
            fallback = "VPN 正在运行",
        )
        val speed = if (NotificationSettings.showSpeed(context)) {
            val (tx, rx) = TrafficRateMonitor.snapshot()
            "\n" + TrafficRateMonitor.format(tx, rx)
        } else {
            ""
        }
        val body = status + speed
        return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(label)
            .setContentText(body)
            // Without an explicit BigTextStyle the two-line speed readout is ellipsised.
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(openIntent)
            .addAction(0, "停止", stopIntent)
            .setOngoing(NotificationSettings.persistent(context))
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    /// Re-renders the notification in place. No-op unless the speed readout is on
    fun refresh(
        context: Context,
        channelId: String,
        notificationId: Int,
        stopAction: String,
    ) {
        if (!NotificationSettings.showSpeed(context)) return
        runCatching {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            manager.notify(
                notificationId,
                build(context, channelId, notificationId, stopAction),
            )
        }
    }
}
