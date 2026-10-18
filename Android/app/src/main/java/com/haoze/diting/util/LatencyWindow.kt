package com.haoze.diting.util

/**
 * Measures only the work that belongs to a measurement window.
 *
 * The DNS latency tester used to start its stopwatch before resolving the
 * provider host, so bootstrap or system resolution time was charged to the DNS
 * upstream and made correctly-configured providers look slow. The window now
 * starts after the host is resolved; [elapsed] reports 0 when the setup itself
 * failed, so a setup failure never masquerades as a fast or slow round trip.
 */
class LatencyWindow {
    private var startedAt: Long = NOT_STARTED

    val isStarted: Boolean
        get() = startedAt != NOT_STARTED

    /** Opens the window at [nowMillis]. Calling it again restarts the window. */
    fun start(nowMillis: Long) {
        startedAt = nowMillis
    }

    /** Milliseconds measured since [start], or 0 when the window never opened. */
    fun elapsed(nowMillis: Long): Long {
        if (startedAt == NOT_STARTED) return 0L
        return (nowMillis - startedAt).coerceAtLeast(0L)
    }

    private companion object {
        const val NOT_STARTED = Long.MIN_VALUE
    }
}
