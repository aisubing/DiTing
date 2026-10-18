package com.haoze.diting.update

/**
 * Throttles update-download progress callbacks so they cannot flood the UI.
 *
 * Byte-based throttling alone is not enough: on a fast link a 256 KB step is
 * crossed every few milliseconds, and each callback repaints the settings
 * screen and re-posts the progress notification. Requiring both a byte step and
 * a minimum time gap keeps the update rate bounded regardless of throughput.
 *
 * Pure and clock-injected so unit tests can pin the decision without a real
 * download; the caller forces the first and the final report.
 */
internal class AppUpdateProgressThrottle(
    private val minBytes: Long = DEFAULT_MIN_BYTES,
    private val minIntervalMs: Long = DEFAULT_MIN_INTERVAL_MS
) {
    private var lastReportedBytes: Long? = null
    private var lastReportedAtMs: Long? = null

    /** True when a progress update is due; a due update starts a new window. */
    fun shouldReport(downloadedBytes: Long, nowMs: Long): Boolean {
        val previousBytes = lastReportedBytes
        val previousAt = lastReportedAtMs
        if (previousBytes == null || previousAt == null) {
            markReported(downloadedBytes, nowMs)
            return true
        }
        if (downloadedBytes - previousBytes < minBytes) return false
        if (nowMs - previousAt < minIntervalMs) return false
        markReported(downloadedBytes, nowMs)
        return true
    }

    /** Marks the current window as reported, e.g. after a forced final update. */
    fun markReported(downloadedBytes: Long, nowMs: Long) {
        lastReportedBytes = downloadedBytes
        lastReportedAtMs = nowMs
    }

    companion object {
        const val DEFAULT_MIN_BYTES = 256L * 1024L
        const val DEFAULT_MIN_INTERVAL_MS = 250L
    }
}
