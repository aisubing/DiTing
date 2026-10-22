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
 * - **备份导出 / 恢复导入** — the system "save / open document" pickers. 1.4.3 used
 *   `ActivityResultContracts.CreateDocument` / `OpenDocument`; both need an
 *   `Activity` and an `onActivityResult` round trip, which only exists here.
 *
 * Notification settings are **not** handled here: they live in
 * `notification_settings_prefs` and are consumed by the foreground services
 * (`DitingVpnService` / `ExpressVpnService`) through [NotificationSettings],
 * exactly how 1.4.3 wired them. A method channel would only add a hop.
 *
 * The Activity is required for the battery-optimisation intent (it must be
 * started from a UI context), for the task-list enumeration, and for both
 * document pickers.
 */
class PlatformBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/platform"

        /**
         * Crash records.
         *
         * Two names on purpose: 1.4.3 wrote `filesDir/crash_logs`
         * (`CrashLogManager.DIR_NAME`), an upgraded install therefore still has
         * that directory; this port has always used `crash`. Clearing only one
         * leaves the other's files behind while the UI says 「已删除」.
         */
        private const val CRASH_DIR = "crash"
        private const val LEGACY_CRASH_DIR = "crash_logs"

        /** 1.4.3 `CrashLogManager.PREFS_NAME`. */
        private const val CRASH_PREFS = "diting_crash_state"

        /** `CrashLogManager` streak keys reset by `clearCrashLogs`. */
        private val CRASH_STATE_KEYS = arrayOf(
            "consecutive_crash_count",
            "has_manually_exported",
            "pending_auto_export_notice",
            "last_recorded_native_exit_time",
        )

        /** 1.4.3 `CustomBackgroundManager` cache files under `filesDir`. */
        private const val BACKGROUND_CACHE_FILE = "custom_background_cached.png"
        private const val BACKGROUND_CACHE_TMP = "custom_background_cached.tmp"
        private const val BACKGROUND_MARKER_FILE = "custom_background_uri.txt"

        /** Document-picker request codes; distinct from the VPN ones (0x5650/0x5651). */
        private const val REQUEST_EXPORT_DOCUMENT = 0x5701
        private const val REQUEST_IMPORT_DOCUMENT = 0x5702

        /** Exports go here; visible to the user through the system file picker. */
        private const val EXPORT_DIR = "exports"

        /**
         * 1.4.3 `AppUpdateManager.UPDATE_DIRECTORY`.
         *
         * Data-cleanup 的「清理下载与临时缓存」必须删这个目录：更新安装包留在这里
         * 才不会被系统清掉，删错了地方会让「已清理」变成谎报。
         *
         * 这里曾经写成 `"updates"`，而下载目录实际是 `"app-update"`——删了一个
         * 从不存在的目录，动作照样报「已清理」。1.4.3 犯过同一个错，并用
         * `AppUpdateDirectories` 把常量收敛到一处来根治。
         */
        private const val UPDATE_DIR = "app-update"

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
            "crashLogCount" -> result.success(crashLogCount())
            "readCrashLogs" -> result.success(readCrashLogs())
            "clearCrashLogs" -> clearCrashLogs(result)
            "exportText" -> exportText(call, result)
            "memoryInfo" -> result.success(memoryInfo())
            // Data-cleanup actions that touch the file system. Their Dart
            // counterparts (logs / traffic / cache / rules / subscriptions) run
            // through the sqflite layer; these two cannot, because sqflite only
            // reaches the app's `databases/` directory.
            "clearUpdateCache" -> result.success(clearUpdateCache(call.argument<Boolean>("includeTemp") ?: true))
            "clearCustomBackgroundCache" -> result.success(clearCustomBackgroundCache())
            // Backup / restore. Both are picker round trips, so the answer comes
            // back through `onActivityResult` → `pendingDocumentResult`, not here.
            "exportDocument" -> exportDocument(call, result)
            "importDocument" -> importDocument(call, result)
            else -> result.notImplemented()
        }
    }

    // --------------------------------------------------- 备份导出 / 恢复导入

    /**
     * Opens the system "save document" picker and writes [content] to the chosen URI.
     *
     * The result map is `{saved: Boolean, name: String?}`. `saved = false` with no
     * name means the user cancelled — that is not an error, and treating it as one
     * would make a cancelled backup look like a failed backup.
     */
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

    /** Opens the system "open document" picker; the text is returned on selection. */
    private fun importDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingDocumentResult != null) {
            result.error("picker_busy", "另一个文件选择器仍在打开", null)
            return
        }
        pendingDocumentResult = result
        pendingExportContent = null
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // `application/json` alone hides files a file manager labelled
            // `text/plain`; `*/*` is filtered in Dart by parsing, which is what
            // 1.4.3's OpenDocument did as well.
            type = "*/*"
        }
        runCatching { activity.startActivityForResult(intent, REQUEST_IMPORT_DOCUMENT) }
            .onFailure {
                pendingDocumentResult = null
                result.error("picker_failed", it.message, null)
            }
    }

    /**
     * Settles a pending picker call. Called from `MainActivity.onActivityResult`.
     *
     * Returns true when the request belonged to this bridge, so the Activity can
     * stop looking for other handlers.
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
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
                    // "wt" truncates: without it a shorter backup leaves the tail
                    // of the previous file, producing invalid JSON.
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

    /**
     * Human-readable file name for a `content://` URI.
     *
     * `uri.lastPathSegment` is the provider's opaque document id (`1`, `msf:12`),
     * not the name the user sees: showing it as 「来源文件：1」 tells the user
     * nothing. `OpenableColumns.DISPLAY_NAME` is what the picker rendered.
     */
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

    /** The in-flight picker, if any. Only one can be open at a time. */
    private var pendingDocumentResult: MethodChannel.Result? = null

    /** Content waiting for the export picker to return a URI. */
    private var pendingExportContent: String? = null

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

    /** Files in both the Flutter directory and 1.4.3's `crash_logs`. */
    private fun crashLogCount(): Int = crashFiles().size

    /**
     * Concatenates every crash report into one text blob.
     *
     * The 日志模式 page's 「导出崩溃日志」 previously only showed a SnackBar saying the
     * native side had to provide file reading. This is that reader: 1.4.3's
     * `CrashLogManager.generateExportContent` opens the reports and prepends an
     * index, because a crash report is useless without knowing which file it came
     * from and when.
     */
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
                // A report can be large (a native tombstone is hundreds of lines);
                // `readText` on a truncated read still yields the useful head.
                append(runCatching { file.readText() }.getOrDefault("(无法读取该文件)"))
            }
        }
        return header + body
    }

    /** Reports from both directories, newest first. */
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

    /**
     * Deletes the crash records and resets the crash streak counters.
     *
     * The counters matter: `CrashLogManager.clearCrashLogs` also re-arms the
     * automatic export for the next streak. Deleting only the files leaves
     * `consecutive_crash_count` at its old value, so the next single crash
     * immediately trips the "crash loop" threshold again.
     */
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

    // ------------------------------------------------- 下载 / 背景缓存清理

    /**
     * Deletes downloaded update APKs, and with [includeTemp] the two cache
     * directories as well.
     *
     * Returns the number of deleted entries. `filesDir/app-update` is the
     * directory 1.4.3's `AppUpdateManager` writes to; an earlier cleanup that
     * targeted `filesDir/updates` deleted nothing and still reported success.
     */
    private fun clearUpdateCache(includeTemp: Boolean): Int {
        var removed = deleteContents(File(context.filesDir, UPDATE_DIR))
        if (includeTemp) {
            removed += deleteContents(context.cacheDir)
            removed += deleteContents(context.externalCacheDir)
        }
        return removed
    }

    /**
     * Deletes the cached custom wallpaper plus its marker file.
     *
     * The preference keys are cleared by the Dart layer (it owns the prefs
     * snapshot); this only removes the files, or the next launch re-reads a
     * stale bitmap whose URI no longer exists.
     */
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
        // 1.4.3 用上面的单文件缓存；本仓选图后按 URI 存 `background/bg_*.png`
        // （多张缩略图不必反复解码），清理时同样要清掉，否则设置页仍能显示已删壁纸。
        removed += deleteContents(File(root, "background"))
        return removed
    }

    /** Deletes every child of [dir]; returns how many entries disappeared. */
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

    // ----------------------------------------------------------- 进程内存

    /**
     * This process's memory plus the device's totals, all in KB.
     *
     * Two different quantities are reported, and they must not be added:
     * - `totalPss` — the whole process PSS, including mmapped code and shared
     *   pages. This is what "how much of the device does this app use" means.
     * - `javaHeap` / `nativeHeap` — allocator-level heap usage, answering
     *   "where is the memory". PSS also counts `.so` / `.dex` mappings, so the
     *   two heaps never sum to it.
     *
     * The `summary.java-heap` / `summary.native-heap` keys of `getMemoryStat`
     * were the obvious way to split PSS, but on Android 14 they read 0 for this
     * app (`dumpsys meminfo` reports the same, with the heap landing in
     * `Unknown`), which produced the self-contradictory 「总占用 339MB、
     * Java 堆 0B」. Allocator figures are measured on every API level instead.
     *
     * The Go engine is an in-process AAR, so its allocations are already inside
     * the native heap and cannot be reported separately. FlClash splits
     * 「应用 / 内核」 because its core is a separate process.
     */
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
