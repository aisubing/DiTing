package com.haoze.diting.platform

import android.content.Context

/// Reads the notification keys Flutter writes through the legacy prefs bridge. Both sides use
/// the container name `notification_settings_prefs` verbatim: pointing either at
/// `dns_vpn_prefs` keeps every UI test green while nothing changes.
object NotificationSettings {
    private const val PREFS = "notification_settings_prefs"

    private const val KEY_PERSISTENT = "persistent"
    private const val KEY_SPEED = "speed"
    private const val KEY_RUNNING_TEXT = "custom_running_text"
    private const val KEY_STOPPED_TEXT = "custom_stopped_text"

    fun persistent(context: Context): Boolean =
        prefs(context).getBoolean(KEY_PERSISTENT, true)

    fun showSpeed(context: Context): Boolean =
        prefs(context).getBoolean(KEY_SPEED, false)

    /// A blank custom string means the default: an empty body looks like a rendering bug
    fun contentText(context: Context, running: Boolean, fallback: String): String {
        val key = if (running) KEY_RUNNING_TEXT else KEY_STOPPED_TEXT
        val custom = prefs(context).getString(key, null).orEmpty()
        return custom.ifBlank { fallback }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(
        PREFS,
        Context.MODE_PRIVATE,
    )
}
