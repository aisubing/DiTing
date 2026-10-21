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

/**
 * Builds the full-tunnel foreground notification, ported from 1.4.3's
 * `normal/notification/VpnNotificationBuilder`.
 *
 * Extracted out of `DitingVpnService` for two reasons: the service was pushing
 * past the 550-line budget, and the notification is rebuilt every second when
 * the 实时速率 readout is on — keeping that loop next to the tunnel lifecycle
 * made both halves harder to follow.
 *
 * The channel id and the stop-action string stay owned by the service and are
 * passed in: they are already persisted in users' installs (an existing channel
 * id cannot be renamed without losing the user's importance setting), so this
 * object must not mint its own.
 *
 * What the old builder did and this keeps:
 * - **自定义文案**: `custom_running_text` replaces the status line when non-blank;
 * - **实时速率**: appends `↑ … ↓ …` on a second line, gated by the `speed` key;
 * - **通知常驻**: drives `setOngoing`, so turning it off makes the notification
 *   dismissible while the tunnel keeps running;
 * - `BigTextStyle` + `setOnlyAlertOnce` + `setShowWhen(false)` + `PRIORITY_LOW`,
 *   so a per-second refresh never re-alerts or re-orders itself.
 */
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
        // Blank custom text means "use the default", not "show nothing": an empty
        // notification body reads as a rendering bug.
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
            // Without an explicit BigTextStyle the two-line speed readout is
            // ellipsised into one truncated line.
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

    /** Re-renders the notification in place. No-op unless 实时速率 is on. */
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
