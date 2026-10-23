package com.haoze.diting.platform

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// OS-level operations with no Dart equivalent; the SAF pickers and task list need an Activity.
class PlatformBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/platform"

        /// Both must be cleared: an upgraded install still has files in the old one
        private const val CRASH_DIR = "crash"
        private const val LEGACY_CRASH_DIR = "crash_logs"

        private const val CRASH_PREFS = "diting_crash_state"

        private val CRASH_STATE_KEYS = arrayOf(
            "consecutive_crash_count",
            "has_manually_exported",
            "pending_auto_export_notice",
            "last_recorded_native_exit_time",
        )

        private const val BACKGROUND_CACHE_FILE = "custom_background_cached.png"
        private const val BACKGROUND_CACHE_TMP = "custom_background_cached.tmp"
        private const val BACKGROUND_MARKER_FILE = "custom_background_uri.txt"

        private const val REQUEST_EXPORT_DOCUMENT = 0x5701
        private const val REQUEST_IMPORT_DOCUMENT = 0x5702

        /// Local-file subscriptions keep a long-lived read grant, unlike a one-shot import.
        private const val REQUEST_PICK_TEXT_FILE = 0x5703

        private const val EXPORT_DIR = "exports"

        /// Must match the updater's download directory, or cleanup deletes nothing
        private const val UPDATE_DIR = "app-update"

        private const val HIDE_FROM_RECENTS_KEY = "hide_from_recents_enabled"

        private const val UI_PREFS = "dns_vpn_prefs"
    }

    private val context: Context get() = activity

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    /// Re-applies recents hiding on resume, so a cold start needs no push from Dart
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
            "crashLogCount" -> result.success(crashLogCount())
            "readCrashLogs" -> result.success(readCrashLogs())
            "clearCrashLogs" -> clearCrashLogs(result)
            "exportText" -> exportText(call, result)
            "memoryInfo" -> result.success(memoryInfo())
            // Null means "cannot tell" (no permission); "" means "not on Wi-Fi".
            "currentSsid" -> result.success(currentSsid())
            // File-system cleanup sqflite cannot reach: it only sees `databases/`.
            "clearUpdateCache" -> result.success(clearUpdateCache(call.argument<Boolean>("includeTemp") ?: true))
            "clearCustomBackgroundCache" -> result.success(clearCustomBackgroundCache())
            // Both are picker round trips; the answer arrives through onActivityResult.
            "exportDocument" -> exportDocument(call, result)
            "importDocument" -> importDocument(call, result)
            // Local-file subscriptions: the grant must outlive the picker dialog, so these are
            // separate from importDocument, which only reads the text once.
            "pickPersistableTextFile" -> pickPersistableTextFile(result)
            "readPersistedText" -> readPersistedText(call, result)
            "releasePersistedText" -> releasePersistedText(call, result)
            else -> result.notImplemented()
        }
    }

    private fun exportDocument(call: MethodCall, result: MethodChannel.Result) {
        val suggested = call.argument<String>("name")?.takeIf { it.isNotBlank() }
            ?: "diting-backup.json"
        val content = call.argument<String>("content").orEmpty()
        if (pendingDocumentResult != null) {
            result.error("picker_busy", "另一个文件选择器仍在打开", null)
            return
        }
        pendingDocumentResult = result
        pendingExportContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, suggested)
        }
        runCatching { activity.startActivityForResult(intent, REQUEST_EXPORT_DOCUMENT) }
            .onFailure {
                pendingDocumentResult = null
                pendingExportContent = null
                result.error("picker_failed", it.message, null)
            }
    }

    private fun importDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingDocumentResult != null) {
            result.error("picker_busy", "另一个文件选择器仍在打开", null)
            return
        }
        pendingDocumentResult = result
        pendingExportContent = null
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // `application/json` alone hides files a file manager labelled `text/plain`.
            type = "*/*"
        }
        runCatching { activity.startActivityForResult(intent, REQUEST_IMPORT_DOCUMENT) }
            .onFailure {
                pendingDocumentResult = null
                result.error("picker_failed", it.message, null)
            }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_PICK_TEXT_FILE) {
            finishPickTextFile(resultCode, data)
            return true
        }
        val isExport = requestCode == REQUEST_EXPORT_DOCUMENT
        val isImport = requestCode == REQUEST_IMPORT_DOCUMENT
        if (!isExport && !isImport) return false
        val pending = pendingDocumentResult
        val content = pendingExportContent
        pendingDocumentResult = null
        pendingExportContent = null
        if (pending == null) return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(mapOf("saved" to false, "name" to null, "cancelled" to true))
            return true
        }
        if (isExport) {
            pending.success(
                runCatching {
                    // "wt" truncates: a shorter backup would leave the previous tail.
                    activity.contentResolver.openOutputStream(uri, "wt")?.use {
                        it.write(content.orEmpty().toByteArray())
                    } ?: error("无法打开导出文件")
                    mapOf(
                        "saved" to true,
                        "name" to (uri.lastPathSegment ?: ""),
                        "cancelled" to false,
                    )
                }.getOrElse { error ->
                    mapOf(
                        "saved" to false,
                        "name" to null,
                        "cancelled" to false,
                        "error" to (error.message ?: error.javaClass.simpleName),
                    )
                },
            )
            return true
        }
        pending.success(
            runCatching {
                val text = activity.contentResolver.openInputStream(uri)?.use {
                    it.readBytes().toString(Charsets.UTF_8)
                } ?: error("无法读取该文件")
                mapOf(
                    "text" to text,
                    "name" to (displayNameOf(uri) ?: uri.lastPathSegment ?: ""),
                    "cancelled" to false,
                )
            }.getOrElse { error ->
                mapOf(
                    "text" to null,
                    "name" to null,
                    "cancelled" to false,
                    "error" to (error.message ?: error.javaClass.simpleName),
                )
            },
        )
        return true
    }

    /// Opens the document picker and keeps the returned grant, so a local subscription can be
    /// re-imported later without asking the user to pick the file again.
    private fun pickPersistableTextFile(result: MethodChannel.Result) {
        if (pendingDocumentResult != null) {
            result.error("picker_busy", "另一个文件选择器仍在打开", null)
            return
        }
        pendingDocumentResult = result
        pendingExportContent = null
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Rule files are plain text but file managers label them inconsistently.
            type = "text/*"
        }
        runCatching { activity.startActivityForResult(intent, REQUEST_PICK_TEXT_FILE) }
            .onFailure {
                pendingDocumentResult = null
                result.error("picker_failed", it.message, null)
            }
    }

    private fun finishPickTextFile(resultCode: Int, data: Intent?) {
        val pending = pendingDocumentResult
        pendingDocumentResult = null
        pendingExportContent = null
        if (pending == null) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(mapOf("cancelled" to true))
            return
        }
        // takePersistableUriPermission survives a reboot; without it the uri dies with the task.
        val granted = runCatching {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }.isSuccess
        pending.success(
            runCatching {
                val text = readUriText(uri) ?: error("无法读取该文件")
                mapOf(
                    "uri" to uri.toString(),
                    "name" to (displayNameOf(uri) ?: uri.lastPathSegment ?: ""),
                    "text" to text,
                    "persisted" to granted,
                    "cancelled" to false,
                )
            }.getOrElse { error ->
                mapOf(
                    "cancelled" to false,
                    "error" to (error.message ?: error.javaClass.simpleName),
                )
            },
        )
    }

    /// Re-reads a previously picked file; the stored grant is what makes this work after a restart.
    private fun readPersistedText(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<String>("uri")
        if (raw.isNullOrBlank()) {
            result.error("invalid_uri", "缺少文件地址", null)
            return
        }
        result.success(
            runCatching {
                val text = readUriText(Uri.parse(raw)) ?: error("无法读取该文件")
                mapOf("text" to text, "error" to null)
            }.getOrElse { error ->
                mapOf("text" to null, "error" to (error.message ?: error.javaClass.simpleName))
            },
        )
    }

    /// Drops the grant when the subscription is deleted; a stale grant would leak read access.
    private fun releasePersistedText(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<String>("uri")
        if (!raw.isNullOrBlank()) {
            runCatching {
                activity.contentResolver.releasePersistableUriPermission(
                    Uri.parse(raw),
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
        }
        result.success(null)
    }

    private fun readUriText(uri: Uri): String? = activity.contentResolver
        .openInputStream(uri)
        ?.use { it.readBytes().toString(Charsets.UTF_8) }

    /// Display name for a `content://` URI; `lastPathSegment` is the opaque document id
    private fun displayNameOf(uri: Uri): String? = runCatching {
        activity.contentResolver.query(
            uri,
            arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.getString(0)
            } else {
                null
            }
        }
    }.getOrNull()

    private var pendingDocumentResult: MethodChannel.Result? = null

    private var pendingExportContent: String? = null

    private fun applyRecentsPrivacy(call: MethodCall, result: MethodChannel.Result) {
        val hide = call.argument<Boolean>("hide") ?: false
        result.success(applyRecentsPrivacyInternal(hide))
    }

    /// Sets `excludeFromRecents` on every task; false when no task list is reachable yet
    private fun applyRecentsPrivacyInternal(hide: Boolean): Boolean = runCatching {
        val manager = context.getSystemService(ActivityManager::class.java) ?: return false
        manager.appTasks.forEach { task ->
            runCatching { task.setExcludeFromRecents(hide) }
        }
        true
    }.getOrDefault(false)

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return false
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    /// The SSID of the joined Wi-Fi. Null means the answer is unknowable (permission denied or
    /// location services off) and the page must say so rather than show a made-up name; an empty
    /// string means "not on Wi-Fi". Android 10+ needs a location permission for `getConnectionInfo`
    /// to return a real SSID, and Android 13+ additionally gates it behind NEARBY_WIFI_DEVICES.
    private fun currentSsid(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !hasPermission(android.Manifest.permission.NEARBY_WIFI_DEVICES) &&
            !hasPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
        ) {
            return null
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            !hasPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
        ) {
            return null
        }
        // Location services off also blanks the SSID, so report "unknown" instead of "".
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && !isLocationEnabled()) {
            return null
        }
        val wifi = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager
        @Suppress("DEPRECATION")
        val info = runCatching { wifi?.connectionInfo }.getOrNull() ?: return null
        @Suppress("DEPRECATION")
        val ssid = info.ssid
        if (ssid.isNullOrBlank()) return ""
        // Android quotes SSIDs, and an unassociated network reports the sentinel `<unknown ssid>`.
        val unquoted = ssid.removeSurrounding("\"").trim()
        if (unquoted == WifiManager.UNKNOWN_SSID) return ""
        return unquoted
    }

    private fun hasPermission(permission: String): Boolean =
        androidx.core.content.ContextCompat.checkSelfPermission(context, permission) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED

    private fun isLocationEnabled(): Boolean = runCatching {
        val manager = context.getSystemService(Context.LOCATION_SERVICE)
            as? android.location.LocationManager ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            manager.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) ||
                @Suppress("DEPRECATION")
                manager.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER)
        }
    }.getOrDefault(false)


    private fun requestIgnoreBatteryOptimizations(result: MethodChannel.Result) {
        // Newer Android opens the optimisation list; the settings screen keeps the button useful.
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

    private fun crashDir(): File = File(context.filesDir, CRASH_DIR).apply { mkdirs() }

    private fun crashLogCount(): Int = crashFiles().size

    private fun readCrashLogs(): String {
        val files = crashFiles()
        if (files.isEmpty()) return ""
        val header = buildString {
            append("=".repeat(80)).append('\n')
            append("                 DITING CRASH LOGS EXPORT (${files.size} REPORT(S))\n")
            append("                 Exported: ").append(timestamp()).append('\n')
            append("=".repeat(80)).append("\n\n")
        }
        val body = files.joinToString("\n\n") { file ->
            buildString {
                append("---- ").append(file.name).append(" ----\n")
                // A tombstone is hundreds of lines; a truncated read still keeps the useful head.
                append(runCatching { file.readText() }.getOrDefault("(无法读取该文件)"))
            }
        }
        return header + body
    }

    /// Reports from both directories, newest first
    private fun crashFiles(): List<File> {
        val files = mutableListOf<File>()
        for (dir in arrayOf(crashDir(), File(context.filesDir, LEGACY_CRASH_DIR))) {
            if (!dir.exists()) continue
            dir.listFiles()?.forEach { if (it.isFile) files.add(it) }
        }
        return files.sortedByDescending { it.lastModified() }
    }

    private fun timestamp(): String =
        java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US)
            .format(java.util.Date())

    /// Clears the crash records and resets the streak keys, or the crash-loop threshold trips again
    private fun clearCrashLogs(result: MethodChannel.Result) {
        var removed = 0
        removed += deleteContents(crashDir())
        removed += deleteContents(File(context.filesDir, LEGACY_CRASH_DIR))
        runCatching {
            val prefs = context.getSharedPreferences(CRASH_PREFS, Context.MODE_PRIVATE)
            val editor = prefs.edit()
            CRASH_STATE_KEYS.forEach { editor.remove(it) }
            editor.apply()
        }
        result.success(removed)
    }

    /// Deletes downloaded APKs, and with `includeTemp` both cache dirs; returns the count
    private fun clearUpdateCache(includeTemp: Boolean): Int {
        var removed = deleteContents(File(context.filesDir, UPDATE_DIR))
        if (includeTemp) {
            removed += deleteContents(context.cacheDir)
            removed += deleteContents(context.externalCacheDir)
        }
        return removed
    }

    /// Deletes the cached wallpaper and its marker; otherwise a stale URI is re-read
    private fun clearCustomBackgroundCache(): Int {
        val root = context.filesDir
        var removed = 0
        val names = arrayOf(
            BACKGROUND_CACHE_FILE,
            BACKGROUND_CACHE_TMP,
            BACKGROUND_MARKER_FILE,
        )
        for (name in names) {
            val file = File(root, name)
            if (file.exists() && file.delete()) removed++
        }
        // Per-URI copies live in `background/bg_*.png`; they must go too, or the preview survives.
        removed += deleteContents(File(root, "background"))
        return removed
    }

    private fun deleteContents(dir: File?): Int {
        if (dir == null || !dir.exists()) return 0
        var removed = 0
        dir.listFiles()?.forEach { file ->
            val ok = runCatching {
                if (file.isDirectory) file.deleteRecursively() else file.delete()
            }.getOrDefault(false)
            if (ok) removed++
        }
        return removed
    }

    /// Process plus device totals, in KB. Never add `totalPss` to the heaps:
    /// it counts `.so` and `.dex` too
    private fun memoryInfo(): Map<String, Any> {
        val self = android.os.Debug.MemoryInfo()
        val hasSelf = runCatching { android.os.Debug.getMemoryInfo(self) }.isSuccess
        val totalPss = if (hasSelf) self.totalPss else 0
        val runtime = Runtime.getRuntime()
        val javaHeap = runtime.totalMemory() - runtime.freeMemory()
        val nativeHeap = android.os.Debug.getNativeHeapAllocatedSize()
        val system = ActivityManager.MemoryInfo()
        val hasSystem = runCatching {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            manager.getMemoryInfo(system)
        }.isSuccess
        return mapOf(
            "available" to (hasSelf && totalPss > 0),
            "totalPss" to totalPss,
            "javaHeap" to javaHeap / 1024,
            "nativeHeap" to nativeHeap / 1024,
            "systemTotal" to if (hasSystem) system.totalMem / 1024 else 0L,
            "systemAvail" to if (hasSystem) system.availMem / 1024 else 0L,
        )
    }

    /// Writes `content` to `getExternalFilesDir/exports/<name>`; no SAF picker, USB can read it
    
    
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
