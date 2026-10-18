package com.haoze.diting.crash

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Manages the lifecycle of local crash log files: persistence, rotation and
 * cleanup, reading, exporting, and clearing. When the app crashes 3 times in
 * a row without a manual export, the logs are automatically backed up to the
 * system Download directory.
 */
object CrashLogManager {
    private const val TAG = "CrashLogManager"
    private const val DIR_NAME = "crash_logs"
    private const val MAX_CRASH_LOGS = 8

    /**
     * Name of the filesDir sub-directory used as the last-resort export target.
     * It must stay in sync with the `crash_export_private` entry of
     * `res/xml/file_paths.xml` (covered by CrashLogManagerStateTest).
     */
    internal const val PRIVATE_DOWNLOAD_DIR_NAME = "downloads"

    private const val PREFS_NAME = "diting_crash_state"
    private const val KEY_CONSECUTIVE_CRASH_COUNT = "consecutive_crash_count"
    private const val KEY_HAS_MANUALLY_EXPORTED = "has_manually_exported"
    private const val KEY_LAST_CRASH_TIME = "last_crash_time"
    private const val KEY_PENDING_AUTO_EXPORT_NOTICE = "pending_auto_export_notice"
    private const val KEY_LAST_RECORDED_NATIVE_EXIT_TIME = "last_recorded_native_exit_time"

    private const val CONSECUTIVE_THRESHOLD = 3
    private const val CONSECUTIVE_EXPIRY_MS = 24 * 60 * 60 * 1000L // Window within which crashes count as consecutive

    /**
     * Whether the current crash streak should trigger an automatic backup.
     *
     * [hasExported] is the "already backed up in this streak" suppression flag:
     * it is set both by a manual export and by a successful auto backup, and
     * cleared again by [clearCrashLogs] so the next streak re-arms it. Without
     * this check every crash past the threshold would write another full
     * backup into Downloads.
     */
    internal fun shouldAutoExport(consecutiveCount: Int, hasExported: Boolean): Boolean =
        consecutiveCount >= CONSECUTIVE_THRESHOLD && !hasExported

    /**
     * Serializes the consecutive-crash read-modify-write.
     *
     * The JVM crash handler and [checkAndCollectNativeCrashes] (which replays a
     * whole batch of historical crashes) can record at the same time. Without
     * this lock one of them reads the same starting count and an increment is
     * lost, so the auto-backup threshold fires later than it should.
     */
    private val stateLock = Any()

    /**
     * Next value of the consecutive-crash counter.
     *
     * A crash further than [expiryMs] from the previous one starts a new streak
     * (count 1); anything closer keeps counting. Extracted so the boundary can
     * be asserted without crashing the JVM.
     */
    internal fun nextConsecutiveCount(
        currentCount: Int,
        lastCrashTime: Long,
        now: Long,
        expiryMs: Long = CONSECUTIVE_EXPIRY_MS
    ): Int = if (now - lastCrashTime > expiryMs) 1 else currentCount + 1

    /**
     * Native-crash waterline to persist when the user clears the crash logs.
     *
     * The old implementation wrote the wall clock here. After the user moves the
     * system clock backwards, every later native exit timestamp stays below that
     * value, so [checkAndCollectNativeCrashes] filters everything out and native
     * crashes stop being collected until the clock catches up. Deriving the
     * waterline from the timestamps the system actually reports keeps the
     * watermark on the same clock as the records it filters, and still hides the
     * exits the user just deleted.
     */
    internal fun waterlineAfterClear(currentWaterline: Long, historicalTimestamps: List<Long>): Long =
        maxOf(currentWaterline, historicalTimestamps.maxOrNull() ?: 0L)

    fun getCrashDir(context: Context): File {
        val dir = File(context.filesDir, DIR_NAME)
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    /**
     * Synchronously writes a crash report to a local file and forces the data
     * to disk with an fsync.
     */
    fun saveCrashReport(context: Context, reportContent: String): File? {
        return runCatching {
            val dir = getCrashDir(context)
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date())
            val file = File(dir, "crash_$timestamp.log")

            FileOutputStream(file).use { fos ->
                fos.write(reportContent.toByteArray(Charsets.UTF_8))
                fos.flush()
                // Ensure the data is physically written to storage
                runCatching { fos.fd.sync() }
            }

            // Prune logs beyond the retention limit
            pruneOldLogs(dir)

            file
        }.onFailure { e ->
            Log.e(TAG, "Failed to save crash report to disk", e)
        }.getOrNull()
    }

    /**
     * Overwrites an already-saved crash report with the richer version collected
     * by the same crash pass. Same atomic write + fsync as [saveCrashReport], but
     * it never prunes, so the original file is kept in place even if the
     * enrichment step races log rotation.
     */
    fun replaceCrashReport(context: Context, file: File, reportContent: String) {
        runCatching {
            FileOutputStream(file).use { fos ->
                fos.write(reportContent.toByteArray(Charsets.UTF_8))
                fos.flush()
                runCatching { fos.fd.sync() }
            }
        }.onFailure { e ->
            Log.e(TAG, "Failed to replace crash report at ${file.absolutePath}", e)
        }
    }

    /**
     * Called every time a crash occurs: records the consecutive-crash count and,
     * once the threshold is reached without a prior manual export, automatically
     * backs the logs up to the system Download directory.
     */
    fun onCrashOccurred(context: Context) {
        runCatching {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            // Read, compute and write the streak inside one lock: the crash
            // handler and checkAndCollectNativeCrashes can run concurrently.
            val newCount = synchronized(stateLock) {
                val lastCrashTime = prefs.getLong(KEY_LAST_CRASH_TIME, 0L)
                val currentCount = prefs.getInt(KEY_CONSECUTIVE_CRASH_COUNT, 0)
                val next = nextConsecutiveCount(currentCount, lastCrashTime, now)

                // Use commit() during a crash so the count is persisted synchronously
                prefs.edit()
                    .putInt(KEY_CONSECUTIVE_CRASH_COUNT, next)
                    .putLong(KEY_LAST_CRASH_TIME, now)
                    .commit()
                next
            }
            val hasExported = prefs.getBoolean(KEY_HAS_MANUALLY_EXPORTED, false)

            Log.i(TAG, "Crash occurrence recorded: count=$newCount, hasManuallyExported=$hasExported")

            // Threshold reached and no export has happened for this streak yet
            if (shouldAutoExport(newCount, hasExported)) {
                val content = generateExportContent(context)
                if (content.isNotBlank()) {
                    val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
                    val fileName = "DITING-crash-auto-backup-$timestamp.txt"
                    val uri = exportToDownloads(context, fileName, content)
                    if (uri != null) {
                        Log.i(TAG, "Auto-saved crash logs to system Download: $fileName")
                        // Mark the streak as already backed up. Without this
                        // every subsequent crash in the same streak re-exports
                        // a fresh full backup, flooding Downloads. The flag is
                        // cleared again by clearCrashLogs(), which re-arms the
                        // auto backup for the next streak. It also runs under
                        // the lock so a concurrent replay cannot trigger a
                        // second backup from the same stale read.
                        synchronized(stateLock) {
                            prefs.edit()
                                .putBoolean(KEY_PENDING_AUTO_EXPORT_NOTICE, true)
                                .putBoolean(KEY_HAS_MANUALLY_EXPORTED, true)
                                .commit()
                        }
                    }
                }
            }
        }.onFailure { e ->
            Log.e(TAG, "Failed in onCrashOccurred handler", e)
        }
    }

    /**
     * Marks that the user exported logs manually, resetting the consecutive
     * crash counter.
     */
    fun markManuallyExported(context: Context) {
        runCatching {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_HAS_MANUALLY_EXPORTED, true)
                .putInt(KEY_CONSECUTIVE_CRASH_COUNT, 0)
                .apply()
        }
    }

    /**
     * Checks and consumes the "auto-backed-up to Downloads" notice flag.
     */
    fun consumePendingAutoExportNotice(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val pending = prefs.getBoolean(KEY_PENDING_AUTO_EXPORT_NOTICE, false)
        if (pending) {
            prefs.edit().putBoolean(KEY_PENDING_AUTO_EXPORT_NOTICE, false).apply()
        }
        return pending
    }

    /**
     * Exports the log content to the system Download directory.
     *
     * MediaStore.Downloads and IS_PENDING only exist on Android 10+ (API 29).
     * On older versions the app has no public-storage write permission, so the
     * only path that works without user interaction is the app-private external
     * "Downloads" folder. Previously the API 29 branch ran on 7.0-9 and both
     * attempts failed silently, so the auto-backup never happened at all.
     */
    fun exportToDownloads(context: Context, fileName: String, content: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return exportToPrivateDownloads(context, fileName, content)
        }
        return runCatching {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null
            resolver.openOutputStream(uri)?.use { os ->
                os.write(content.toByteArray(Charsets.UTF_8))
                os.flush()
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            uri
        }.getOrElse { e ->
            Log.e(TAG, "Failed to export crash log to Downloads via MediaStore, trying app-specific dir", e)
            exportToPrivateDownloads(context, fileName, content)
        }
    }

    /**
     * Fallback for API < 29 (and for MediaStore failures): writes into the
     * app-specific external Download folder. No permission is required and the
     * file survives app restarts, but it is removed on uninstall.
     */
    private fun exportToPrivateDownloads(context: Context, fileName: String, content: String): Uri? {
        return runCatching {
            val root = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                ?: File(context.filesDir, PRIVATE_DOWNLOAD_DIR_NAME)
            if (!root.exists()) root.mkdirs()
            val file = File(root, fileName)
            file.writeText(content, Charsets.UTF_8)
            FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        }.getOrElse { e ->
            Log.e(TAG, "Failed to write crash log to app-specific Downloads", e)
            null
        }
    }

    /**
     * Returns all local crash log files sorted from newest to oldest.
     */
    fun getCrashLogFiles(context: Context): List<File> {
        val dir = File(context.filesDir, DIR_NAME)
        if (!dir.exists()) return emptyList()
        return dir.listFiles { f -> f.isFile && f.name.startsWith("crash_") && f.name.endsWith(".log") }
            ?.sortedByDescending { it.lastModified() }
            ?: emptyList()
    }

    fun getCrashLogCount(context: Context): Int {
        return getCrashLogFiles(context).size
    }

    /**
     * Builds the diagnostic summary content used for exports.
     */
    fun generateExportContent(context: Context): String {
        val files = getCrashLogFiles(context)
        if (files.isEmpty()) return ""

        val sb = StringBuilder()
        sb.append("================================================================================\n")
        sb.append("                 DITING CRASH LOGS EXPORT (${files.size} REPORT(S))\n")
        sb.append("                 Exported: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())}\n")
        sb.append("================================================================================\n\n")

        // Index table giving developers an at-a-glance overview of every crash
        sb.append("--------------------------------------------------------------------------------\n")
        sb.append("  EXECUTIVE SUMMARY\n")
        sb.append("--------------------------------------------------------------------------------\n")
        for ((index, file) in files.withIndex()) {
            val preview = runCatching {
                file.useLines { lines ->
                    var crashType = "Unknown"
                    var timeStr = ""
                    var summary = ""
                    for (line in lines.take(120)) {
                        if (line.contains("DITING NATIVE CRASH REPORT") || line.contains("DITING NATIVE CRASH REPORT")) crashType = "Native Crash"
                        if (line.contains("DITING CRASH REPORT") || line.contains("DITING CRASH REPORT")) crashType = "Java Crash"
                        if (line.startsWith("Timestamp (Local): ")) timeStr = line.removePrefix("Timestamp (Local): ").trim()
                        if (line.startsWith("Exception Class  : ")) summary = line.removePrefix("Exception Class  : ").trim()
                        if (line.startsWith("Signal: ")) summary = line.trim()
                        if (line.startsWith("Abort Message: ")) {
                            summary = line.trim()
                            break
                        }
                        if (line.startsWith("Cause: ")) {
                            summary = line.trim()
                            break
                        }
                    }
                    Triple(crashType, timeStr, summary)
                }
            }.getOrNull()

            val type = preview?.first ?: "Crash"
            val time = preview?.second?.takeIf { it.isNotBlank() } ?: SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(file.lastModified()))
            val detail = preview?.third?.takeIf { it.isNotBlank() } ?: file.name
            sb.append(String.format(Locale.US, "  [%d/%d] %-12s | %s | %s\n", index + 1, files.size, type, time, detail))
        }
        sb.append("\n")

        for ((index, file) in files.withIndex()) {
            sb.append(">>> REPORT ").append(index + 1).append("/").append(files.size)
                .append(" : ").append(file.name).append(" <<<\n\n")
            runCatching {
                sb.append(file.readText(Charsets.UTF_8))
            }.onFailure {
                sb.append("(Error reading file content: ${it.message})\n")
            }
            sb.append("\n\n")
        }

        return sb.toString()
    }

    /**
     * Inspects the system's historical process exit records (Android 11+ /
     * API 30+) for native crashes (REASON_CRASH_NATIVE) that the JVM never
     * intercepted. Any crash not yet recorded has its tombstone/trace extracted
     * and turned into a standard crash log on disk.
     */
    fun checkAndCollectNativeCrashes(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return

        runCatching {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? android.app.ActivityManager ?: return
            val exitInfos = am.getHistoricalProcessExitReasons(context.packageName, 0, 10)
            if (exitInfos.isEmpty()) return

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lastRecordedTime = prefs.getLong(KEY_LAST_RECORDED_NATIVE_EXIT_TIME, 0L)

            // Sort oldest to newest so crash logs are generated in chronological order
            val nativeCrashes = exitInfos
                .filter { it.reason == android.app.ApplicationExitInfo.REASON_CRASH_NATIVE && it.timestamp > lastRecordedTime }
                .sortedBy { it.timestamp }

            if (nativeCrashes.isEmpty()) return

            var maxTimestamp = lastRecordedTime
            for (exitInfo in nativeCrashes) {
                val trace = runCatching {
                    exitInfo.traceInputStream?.use { stream ->
                        TombstoneParser.parse(stream)
                    }
                }.getOrNull().orEmpty()

                val report = CrashCollector.collectNativeCrashReport(
                    context = context,
                    exitInfo = exitInfo,
                    tombstoneTrace = trace
                )

                val file = saveCrashReport(context, report)
                Log.i(TAG, "Recorded historical native crash (pid=${exitInfo.pid}, time=${exitInfo.timestamp}) to: ${file?.absolutePath}")

                // Persist the waterline after every single record, not once after
                // the whole batch: this runs on a replay of a crash burst, and if
                // the process dies again mid-loop the old code re-collected the
                // entire batch next launch, inflating the consecutive-crash count
                // (and, past the threshold, exporting duplicate backups). It is
                // written before the streak update so a death inside the streak
                // update cannot double-count this exit either.
                if (exitInfo.timestamp > maxTimestamp) {
                    maxTimestamp = exitInfo.timestamp
                    prefs.edit().putLong(KEY_LAST_RECORDED_NATIVE_EXIT_TIME, maxTimestamp).apply()
                }

                onCrashOccurred(context)
            }
        }.onFailure { e ->
            Log.w(TAG, "Failed to check historical process exit reasons for native crash", e)
        }
    }

    /**
     * Clears all saved crash logs.
     *
     * The native-crash waterline is *not* reset to the wall clock: doing that
     * silently stops native crash collection whenever the user's clock is behind
     * the watermark (manual clock changes, timezone/DST corrections, NTP
     * rollback) because every reported exit timestamp then filters out. The
     * waterline is instead derived from the timestamps the system is actually
     * reporting right now, so the exits the user just deleted stay hidden while
     * later ones are still collected.
     */
    fun clearCrashLogs(context: Context): Boolean {
        runCatching {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val waterline = waterlineAfterClear(
                currentWaterline = prefs.getLong(KEY_LAST_RECORDED_NATIVE_EXIT_TIME, 0L),
                historicalTimestamps = historicalExitTimestamps(context)
            )
            prefs.edit()
                .putInt(KEY_CONSECUTIVE_CRASH_COUNT, 0)
                .putBoolean(KEY_HAS_MANUALLY_EXPORTED, false)
                .putBoolean(KEY_PENDING_AUTO_EXPORT_NOTICE, false)
                .putLong(KEY_LAST_RECORDED_NATIVE_EXIT_TIME, waterline)
                .apply()
        }
        return runCatching {
            val dir = File(context.filesDir, DIR_NAME)
            if (dir.exists()) {
                dir.listFiles()?.forEach { it.delete() }
            }
            true
        }.getOrDefault(false)
    }

    /** Every exit-reason timestamp the system still reports for this package. */
    private fun historicalExitTimestamps(context: Context): List<Long> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
        return runCatching {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? android.app.ActivityManager
                ?: return emptyList()
            am.getHistoricalProcessExitReasons(context.packageName, 0, 10).map { it.timestamp }
        }.getOrDefault(emptyList())
    }

    private fun pruneOldLogs(dir: File) {
        runCatching {
            val files = dir.listFiles { f -> f.isFile && f.name.startsWith("crash_") && f.name.endsWith(".log") }
                ?.sortedByDescending { it.lastModified() }
                ?: return

            if (files.size > MAX_CRASH_LOGS) {
                for (i in MAX_CRASH_LOGS until files.size) {
                    files[i].delete()
                }
            }
        }
    }
}
