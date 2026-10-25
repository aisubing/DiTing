package com.haoze.diting.log

import android.content.Context
import java.io.File

/// Files behind the manual runtime-log capture: `RuntimeLogService` appends to them and
/// `RuntimeLogBridge` reads, lists and clears them. Lives outside `filesDir` so a USB cable can
/// reach the folder; the in-app export still goes through the system save picker.
object RuntimeLogStore {
    private const val DIR = "runtime_logs"

    /// Hard cap per file, then the oldest file is dropped: a stuck loop must not fill the disk.
    const val MAX_FILE_BYTES = 2L * 1024 * 1024

    const val MAX_FILES = 3

    fun dir(context: Context): File {
        val root = context.getExternalFilesDir(null) ?: context.filesDir
        return File(root, DIR).apply { mkdirs() }
    }

    /// Newest first, so [read] can join them in the reverse order for a chronological export.
    fun files(context: Context): List<File> =
        dir(context)
            .listFiles()
            ?.filter { it.isFile && it.name.endsWith(".log") }
            ?.sortedByDescending { it.lastModified() }
            ?: emptyList()

    fun sizeBytes(context: Context): Long = files(context).sumOf { it.length() }

    /// A fresh capture file; the timestamp keeps two sessions apart.
    fun newFile(context: Context): File {
        val stamp = java.text.SimpleDateFormat("yyyyMMdd-HHmmss", java.util.Locale.US)
            .format(java.util.Date())
        return File(dir(context), "runtime-$stamp.log")
    }

    /// Drops the oldest files beyond [MAX_FILES]; returns the surviving list.
    fun trim(context: Context): List<File> {
        val files = files(context)
        files.drop(MAX_FILES).forEach { runCatching { it.delete() } }
        return files.take(MAX_FILES)
    }

    /// Everything recorded so far, oldest first, with a header the developer can read.
    fun read(context: Context): String {
        val files = files(context).reversed()
        if (files.isEmpty()) return ""
        val header = buildString {
            append("=".repeat(80)).append('\n')
            append("                 DITING RUNTIME LOGS EXPORT (${files.size} FILE(S))\n")
            append("                 Exported: ").append(timestamp()).append('\n')
            append("=".repeat(80)).append("\n\n")
        }
        val body = files.joinToString("\n\n") { file ->
            buildString {
                append("---- ").append(file.name).append(" ----\n")
                append(runCatching { file.readText() }.getOrDefault("(无法读取该文件)"))
            }
        }
        return header + body
    }

    fun clear(context: Context): Int {
        var removed = 0
        files(context).forEach { file -> if (runCatching { file.delete() }.getOrDefault(false)) removed++ }
        return removed
    }

    private fun timestamp(): String =
        java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US)
            .format(java.util.Date())
}
