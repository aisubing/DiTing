package com.haoze.diting.platform

import android.content.Context

/// Which foreground service is asking. The custom running text is shared, but the composed
/// default differs per mode because the legacy app worded them differently.
enum class NotificationMode(internal val defaultKey: String) {
    NORMAL("default_running_text"),
    EXPRESS("default_express_text"),
    SERVER("default_server_text"),
}

/// Reads the notification keys Flutter writes through the legacy prefs bridge. Both sides use
/// the container name `notification_settings_prefs` verbatim: pointing either at
/// `dns_vpn_prefs` keeps every UI test green while nothing changes.
object NotificationSettings {
    private const val PREFS = "notification_settings_prefs"

    private const val KEY_PERSISTENT = "persistent"
    private const val KEY_SPEED = "speed"
    private const val KEY_RUNNING_TEXT = "custom_running_text"

    fun persistent(context: Context): Boolean =
        prefs(context).getBoolean(KEY_PERSISTENT, true)

    fun showSpeed(context: Context): Boolean =
        prefs(context).getBoolean(KEY_SPEED, false)

    /// Custom text wins, then the legacy-style body Dart composed for this mode, then [fallback].
    /// A blank body looks like a rendering bug, hence the chain.
    fun runningText(context: Context, mode: NotificationMode, fallback: String): String {
        val prefs = prefs(context)
        val custom = prefs.getString(KEY_RUNNING_TEXT, null).orEmpty()
        if (custom.isNotBlank()) return custom
        return prefs.getString(mode.defaultKey, null).orEmpty().ifBlank { fallback }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(
        PREFS,
        Context.MODE_PRIVATE,
    )
}
