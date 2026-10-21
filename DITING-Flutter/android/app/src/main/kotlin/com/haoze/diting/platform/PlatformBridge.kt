package com.haoze.diting.platform

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native side of `com.haoze.diting/platform`: the four OS-level settings that
 * 1.4.3 had and the Flutter port lost.
 *
 * Each one is a *system* call with no Dart equivalent:
 *
 * - **后台隐藏** — `RecentsPrivacyController.apply()` sets `excludeFromRecents`
 *   on every task. 1.4.3 ran it from `MainActivity.onCreate` / `onResume`; here
 *   the Dart layer flips the pref and asks this bridge to apply it immediately,
 *   and [reapplyRecentsPrivacy] covers the resume path.
 * - **忽略电池优化** — `PowerManager.isIgnoringBatteryOptimizations` plus the
 *   `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` intent.
 * - **崩溃日志** — 1.4.3's crash handler wrote to `filesDir/crash/`; the Flutter
 *   port had a fake `_crashLogCount = 3`. This bridge enumerates and clears the
 *   real directory.
 * - **导出 CSV** — writes to the app's external files dir and returns the path.
 *
 * Notification settings are **not** handled here: they live in
 * `notification_settings_prefs` and are consumed by the foreground services
 * (`DitingVpnService` / `ExpressVpnService`) through [NotificationSettings],
 * exactly how 1.4.3 wired them. A method channel would only add a hop.
 *
 * The Activity is required for the battery-optimisation intent (it must be
 * started from a UI context) and for the task-list enumeration.
 */
class PlatformBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/platform"

        /** Crash records, matching 1.4.3's `filesDir/crash`. */
        private const val CRASH_DIR = "crash"

        /** Exports go here; visible to the user through the system file picker. */
        private const val EXPORT_DIR = "exports"

        /** Key 1.4.3's `SystemSettingsStore` used for 后台隐藏. */
        private const val HIDE_FROM_RECENTS_KEY = "hide_from_recents_enabled"

        /** Both stores share the global UI container (`dns_vpn_prefs`). */
        private const val UI_PREFS = "dns_vpn_prefs"
    }

    private val context: Context get() = activity

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    /**
     * Re-applies 后台隐藏 from the persisted pref.
     *
     * Called from `MainActivity.onResume`. Reading the pref here (instead of
     * having Dart push the value) keeps the two ends from drifting: the setting
     * survives process death and the first resume after a cold start has no Dart
     * call to rely on.
     */
    fun reapplyRecentsPrivacy() {
        runCatching {
            val hide = context
                .getSharedPreferences(UI_PREFS, Context.MODE_PRIVATE)
                .getBoolean(HIDE_FROM_RECENTS_KEY, false)
            applyRecentsPrivacyInternal(hide)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "applyRecentsPrivacy" -> applyRecentsPrivacy(call, result)
            "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
            "requestIgnoreBatteryOptimizations" -> requestIgnoreBatteryOptimizations(result)
            "crashLogCount" -> result.success(crashDir().listFiles()?.size ?: 0)
            "clearCrashLogs" -> clearCrashLogs(result)
            "exportText" -> exportText(call, result)
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------- 后台隐藏

    private fun applyRecentsPrivacy(call: MethodCall, result: MethodChannel.Result) {
        val hide = call.argument<Boolean>("hide") ?: false
        result.success(applyRecentsPrivacyInternal(hide))
    }

    /**
     * Sets `excludeFromRecents` on every task of this app.
     *
     * Returns false when no task list is reachable (the app is not in the
     * recents list yet). That is not an error: the pref is already persisted, and
     * [reapplyRecentsPrivacy] on the next resume will apply it.
     */
    private fun applyRecentsPrivacyInternal(hide: Boolean): Boolean = runCatching {
        val manager = context.getSystemService(ActivityManager::class.java) ?: return false
        manager.appTasks.forEach { task ->
            runCatching { task.setExcludeFromRecents(hide) }
        }
        true
    }.getOrDefault(false)

    // --------------------------------------------------- 忽略电池优化

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return false
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun requestIgnoreBatteryOptimizations(result: MethodChannel.Result) {
        // Newer Android no longer shows a dialog for this action; it opens the
        // optimisation list instead. Falling back to the settings screen keeps
        // the button useful on every version rather than failing silently.
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:${context.packageName}"))
        val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            direct.resolveActivity(context.packageManager) != null
        ) {
            direct
        } else {
            fallback
        }
        val ok = runCatching { activity.startActivity(intent) }.isSuccess
        result.success(ok)
    }

    // --------------------------------------------------------- 崩溃日志

    private fun crashDir(): File = File(context.filesDir, CRASH_DIR).apply { mkdirs() }

    private fun clearCrashLogs(result: MethodChannel.Result) {
        val dir = crashDir()
        var removed = 0
        dir.listFiles()?.forEach { file ->
            if (file.isFile && file.delete()) removed++
        }
        result.success(removed)
    }

    // ----------------------------------------------------------- 导出

    /**
     * Writes [content] to `getExternalFilesDir/exports/<name>` and returns the
     * absolute path.
     *
     * No `Activity` and no SAF picker: the Dart side already renders a "已导出到
     * …" message with the path, and the file lands in the app-scoped external
     * directory, which is readable over USB and by any file manager the user
     * grants. A picker would need `onActivityResult` plumbing for no extra
     * capability.
     */
    private fun exportText(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
            ?.takeIf { it.isNotBlank() }
            ?.replace(Regex("[^A-Za-z0-9._-]"), "_")
            ?: "diting-export.txt"
        val content = call.argument<String>("content").orEmpty()
        val root = context.getExternalFilesDir(null) ?: context.filesDir
        val dir = File(root, EXPORT_DIR).apply { mkdirs() }
        val file = File(dir, name)
        runCatching { file.writeText(content) }.fold(
            onSuccess = { result.success(file.absolutePath) },
            onFailure = { result.error("export_failed", it.message, null) },
        )
    }
}
