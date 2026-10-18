package com.haoze.diting.notification

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat

/**
 * Notification permission helper: encapsulates the Android 13+ (API 33)
 * permission check and the jump to the system notification settings page.
 */
object NotificationPermissionHelper {

    /**
     * Returns whether the app has been granted the notification permission.
     */
    fun hasPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /**
     * Opens the system notification settings page for this app.
     *
     * `ACTION_APP_NOTIFICATION_SETTINGS` only exists from API 26, so on Android
     * 7.x the intent cannot resolve and `startActivity` throws. The app's own
     * details page accepts no extra and works on every supported version, so it
     * is used as the fallback instead of silently doing nothing.
     */
    fun openNotificationSettings(context: Context) {
        val opened = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            runCatching { context.startActivity(intent) }.isSuccess
        } else {
            false
        }
        if (!opened) {
            runCatching { context.startActivity(appDetailsIntent(context)) }
        }
    }

    private fun appDetailsIntent(context: Context): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
}
