package com.haoze.diting.apps

import android.content.Context
import android.content.pm.ApplicationInfo
import com.haoze.diting.platform.ChannelResults
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

/// Read-only installed-app inventory; selection state lives in
/// SharedPreferences, written by LegacyPrefsBridge.
class AppsBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/apps"

        /// Enumeration takes hundreds of ms, so it runs off the platform thread.
        /// A single worker also keeps concurrent enumerations from interleaving.
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

    /// An empty result is reported as an error: some ROMs (MIUI/ColorOS/EMUI)
    /// gate the list behind a runtime permission and still return only this
    /// app, which the UI must show as "allow access", not "no apps installed".
    private fun listInstalledChecked(): Result<List<Map<String, Any?>>> = runCatching {
        val apps = listInstalled()
        if (apps.isEmpty()) {
            throw IllegalStateException("未能读取已安装应用列表，请在系统权限中允许“读取应用列表”")
        }
        apps
    }

    /// Every app except this one, sorted by normalized label then package name.
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

    /// Package name -> UID, omitting uninstalled packages so the caller never
    /// hands the engine an invalid UID.
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

    /// -1 when the package is gone or the platform refuses to answer.
    private fun uidOf(packageName: String): Int = runCatching {
        context.packageManager.getPackageUid(packageName, 0)
    }.getOrDefault(-1)

    private fun isSystemApp(info: ApplicationInfo): Boolean =
        (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0
}

/// Result may only be touched on the platform thread.
private fun <T> Result<T>.ship(result: MethodChannel.Result) =
    ChannelResults.ship(result, this, "apps_unavailable")
