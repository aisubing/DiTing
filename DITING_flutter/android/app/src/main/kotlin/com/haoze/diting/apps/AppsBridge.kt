package com.haoze.diting.apps

import android.content.Context
import android.content.pm.ApplicationInfo
import com.haoze.diting.platform.ChannelResults
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Native side of `com.haoze.diting/apps`: the real installed-app inventory.
 *
 * 1.4.3 enumerated apps with `PackageManager` behind `QUERY_ALL_PACKAGES`
 * (`InstalledAppPickerComponents.loadInstalledApps`). The Flutter port lost the
 * permission in the Manifest migration and every picker silently fell back to
 * `mockInstalledApps`, so this bridge restores the real list.
 *
 * Read-only by design: selection state stays in SharedPreferences
 * (`blocked_app_packages`, `excluded_app_packages`,
 * `http_inspection_app_packages`, `app_allowlist_rules_json`), which
 * [com.haoze.diting.LegacyPrefsBridge] already writes.
 *
 * Contract frozen by `lib/data/native/apps_bridge.dart`:
 * - `listInstalled` -> `List<{packageName,label,isSystem,uid}>`
 * - `resolveUids(packages)` -> `Map<packageName, uid>`, absent when uninstalled
 * - `isSelf(packageName)` -> `Boolean`
 */
class AppsBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/apps"

        /**
         * `getInstalledPackages` takes hundreds of milliseconds on a loaded
         * device; on the platform thread that is visible jank in the picker
         * sheet. One shared serial worker also keeps a page-enter racing a
         * pull-to-refresh from interleaving two enumerations.
         */
        private val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "diting-apps").apply { isDaemon = true }
        }
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listInstalled" -> worker.execute { listInstalledChecked().ship(result) }
            "resolveUids" -> {
                val packages = call.argument<List<String>>("packages").orEmpty()
                worker.execute { runCatching { resolveUids(packages) }.ship(result) }
            }
            // Cheap, and validation paths want it synchronously.
            "isSelf" -> result.success(isSelf(call.argument<String>("packageName").orEmpty()))
            else -> result.notImplemented()
        }
    }

    /**
     * Enumerates apps, distinguishing "none visible" from "not allowed".
     *
     * This distinction is the whole reason 1.4.3 had
     * `AppListPermissionHelper.canQueryInstalledApps`: on AOSP the Manifest knob
     * `QUERY_ALL_PACKAGES` is enough, but HyperOS/MIUI, ColorOS and EMUI gate the
     * list behind a *runtime* permission (`com.android.permission.GET_INSTALLED_APPS`)
     * that the user must grant. `getInstalledApplications` then returns only this
     * app's own packages — still a successful call, so returning that list would
     * render as "this device has zero apps" and the picker's "allow access"
     * affordance would never appear.
     *
     * A result containing no other package is therefore reported as an error. The
     * Dart provider is required to catch `PlatformException` and surface this text
     * as a readable error state (`lib/state/installed_apps_providers.dart`), which
     * is exactly what the picker needs in order to show "allow access" instead of
     * an empty device.
     */
    private fun listInstalledChecked(): Result<List<Map<String, Any?>>> = runCatching {
        val apps = listInstalled()
        if (apps.isEmpty()) {
            throw IllegalStateException("未能读取已安装应用列表，请在系统权限中允许“读取应用列表”")
        }
        apps
    }

    /**
     * Every app except this one, sorted by label.
     *
     * `getInstalledApplications(0)` — not `getInstalledPackages` — because that is
     * exactly what 1.4.3's `loadInstalledApps` called, and it hands back
     * `ApplicationInfo` directly: `flags` (which decides `isSystem`) and
     * `loadLabel` both come from the same object, with no `PackageInfo.applicationInfo`
     * null check in between.
     *
     * 1.4.3 sorted with `compareBy { normalizedLabel }.thenBy { packageName }`;
     * the Dart side re-sorts by label anyway, but keeping the order here means a
     * truncated client still sees the same sequence.
     */
    private fun listInstalled(): List<Map<String, Any?>> {
        val packageManager = context.packageManager
        @Suppress("DEPRECATION")
        val installed = packageManager.getInstalledApplications(0)
        val self = context.packageName
        return installed.asSequence()
            .filter { it.packageName != self }
            .map { info ->
                val label = runCatching { info.loadLabel(packageManager).toString() }
                    .getOrNull()?.takeIf { it.isNotBlank() } ?: info.packageName
                mapOf(
                    "packageName" to info.packageName,
                    "label" to label,
                    "isSystem" to isSystemApp(info),
                    "uid" to uidOf(info.packageName),
                )
            }
            .sortedWith(
                compareBy<Map<String, Any?>> {
                    (it["label"] as? String).orEmpty().lowercase(Locale.ROOT)
                }.thenBy { it["packageName"] as? String },
            )
            .toList()
    }

    /**
     * Package name -> UID. Uninstalled packages are *omitted* (not mapped to
     * -1): the Dart caller drops them from the selection instead of handing the
     * engine an invalid UID.
     */
    private fun resolveUids(packages: List<String>): Map<String, Int> {
        if (packages.isEmpty()) return emptyMap()
        val output = HashMap<String, Int>(packages.size)
        for (packageName in packages.distinct()) {
            if (packageName.isBlank()) continue
            val uid = uidOf(packageName)
            if (uid >= 0) output[packageName] = uid
        }
        return output
    }

    private fun isSelf(packageName: String): Boolean =
        packageName.isNotEmpty() && packageName == context.packageName

    /** `-1` when the package is gone or the platform refuses to answer. */
    private fun uidOf(packageName: String): Int = runCatching {
        context.packageManager.getPackageUid(packageName, 0)
    }.getOrDefault(-1)

    private fun isSystemApp(info: ApplicationInfo): Boolean =
        (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0
}

/** Flutter's `MethodChannel.Result` may only be touched on the platform thread. */
private fun <T> Result<T>.ship(result: MethodChannel.Result) =
    ChannelResults.ship(result, this, "apps_unavailable")
