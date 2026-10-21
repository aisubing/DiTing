package com.haoze.diting.platform

import android.content.Context

/**
 * Reads the notification keys 1.4.3's `notification/NotificationSettingsStore`
 * wrote, so the foreground services can honour them.
 *
 * The Flutter layer writes these four keys through the legacy prefs bridge; the
 * services read the same file here. Both sides use the container name
 * `notification_settings_prefs` verbatim — pointing either side at
 * `dns_vpn_prefs` would keep every UI test green while the notification never
 * changed.
 *
 * Read-side only on purpose: the settings screen owns the writes, and a second
 * writer is how the two ends drift apart.
 */
object NotificationSettings {
    private const val PREFS = "notification_settings_prefs"

    private const val KEY_PERSISTENT = "persistent"
    private const val KEY_SPEED = "speed"
    private const val KEY_RUNNING_TEXT = "custom_running_text"
    private const val KEY_STOPPED_TEXT = "custom_stopped_text"

    /** 1.4.3 default: a persistent notification is shown. */
    fun persistent(context: Context): Boolean =
        prefs(context).getBoolean(KEY_PERSISTENT, true)

    /** 1.4.3 default: the notification does **not** show live speed. */
    fun showSpeed(context: Context): Boolean =
        prefs(context).getBoolean(KEY_SPEED, false)

    /**
     * Content text for the current service state.
     *
     * An empty custom string means "use the default", not "show nothing": 1.4.3
     * treated blank as unset, and a notification with an empty body looks like a
     * rendering bug.
     */
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
