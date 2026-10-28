package com.haoze.diting.log

import android.util.Log
import java.util.concurrent.atomic.AtomicLong

/// Health of the log-table writers, and the only place that logs a write failure.
///
/// 2.1.7 printed a 25-line stack trace per failed open, from every engine callback thread: the
/// 2026-10-27 export had ~7000 such lines in four minutes. That flooded logcat (the startup lines
/// were pushed out of the ring buffer, so the export had no context) and slowed the DNS hot path.
/// Failures are now counted and reported once per window, and the counters are exposed to the
/// troubleshooting page so a silent "no logs at all" becomes visible.
internal object DbWriteHealth {
    private const val TAG = "DbWriteHealth"
    private const val WARN_WINDOW_MS = 60_000L

    private val droppedRows = AtomicLong(0)
    private val openFailures = AtomicLong(0)
    private val suppressed = AtomicLong(0)

    private var lastWarnAt = 0L
    private var lastCause: String? = null

    /// Rows that could not be persisted at all (buffer over the cap, or a table that never exists).
    fun onDropped(rows: Int) {
        if (rows > 0) droppedRows.addAndGet(rows.toLong())
    }

    fun onOpenFailure(databaseName: String, cause: Throwable?) {
        openFailures.incrementAndGet()
        warn(TAG, "unable to open $databaseName", cause)
    }

    /// One line per [WARN_WINDOW_MS]; the first failure of a window keeps its stack trace.
    @Synchronized
    fun warn(tag: String, message: String, cause: Throwable? = null) {
        if (cause != null) lastCause = "${cause.javaClass.simpleName}: ${cause.message}"
        val now = System.currentTimeMillis()
        if (now - lastWarnAt < WARN_WINDOW_MS) {
            suppressed.incrementAndGet()
            return
        }
        val more = suppressed.getAndSet(0)
        val suffix = if (more > 0) " (+$more suppressed in ${WARN_WINDOW_MS / 1000}s)" else ""
        lastWarnAt = now
        if (cause == null) Log.w(tag, message + suffix) else Log.w(tag, message + suffix, cause)
    }

    /// Payload for the diagnostics channel; zero counters and an empty cause mean "healthy".
    fun snapshot(): Map<String, Any> = mapOf(
        "droppedRows" to droppedRows.get(),
        "openFailures" to openFailures.get(),
        "suppressed" to suppressed.get(),
        "lastCause" to (lastCause ?: ""),
    )
}
