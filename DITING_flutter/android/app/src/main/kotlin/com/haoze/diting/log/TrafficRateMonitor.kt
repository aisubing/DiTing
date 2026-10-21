package com.haoze.diting.log

/**
 * Second-resolution transfer rates for the notification's speed readout.
 *
 * 1.4.3 had `core/traffic/TrafficStatsManager`, which exposed a `StateFlow`
 * snapshot of the total TX/RX speed and drove `VpnSpeedMonitor` (a coroutine that
 * reformatted the notification text only when the rendered string changed).
 *
 * This port dropped both when the Flutter UI took over the dashboard: the
 * numbers only ever fed the Compose gauge, which no longer exists. The
 * notification's 实时速率 switch needs them back, so this keeps just the part
 * that has a live reader — a rate derived from the same per-UID deltas that
 * [TrafficIngest] already parses, with no state of its own beyond the last
 * sample.
 *
 * Deliberately a singleton: the tick callback and the notification builder are
 * constructed in different places (the engine plane owns the callback, the
 * service owns the notification) and passing an object between them would mean
 * threading a reference through startup for one number.
 */
object TrafficRateMonitor {
    private var lastTx = 0L
    private var lastRx = 0L
    private var lastAtMs = 0L

    @Volatile
    private var txBps = 0L

    @Volatile
    private var rxBps = 0L

    /** Total bytes moved in the last tick. */
    fun onTick(tx: Long, rx: Long) {
        val now = System.currentTimeMillis()
        val previous = lastAtMs
        if (previous > 0) {
            val elapsed = now - previous
            if (elapsed <= 0) return
            // Per-second normalisation: the engine's tick is nominally 1 s, but a
            // stalled callback can deliver a double-sized delta late. Dividing by
            // the real interval keeps the readout from spiking to 2× and then
            // reading 0 on the following tick.
            txBps = tx * 1000 / elapsed
            rxBps = rx * 1000 / elapsed
            lastTx = tx
            lastRx = rx
        }
        lastAtMs = now
    }

    fun reset() {
        lastTx = 0
        lastRx = 0
        lastAtMs = 0
        txBps = 0
        rxBps = 0
    }

    fun snapshot(): Pair<Long, Long> = txBps to rxBps

    /**
     * Formats `↑ 1.2 MB/s  ↓ 340 KB/s`, matching 1.4.3's
     * `VpnNotificationBuilder.formatTrafficSpeed` byte-for-byte (1024-based,
     * one decimal for MB, none for KB).
     */
    fun format(txBps: Long, rxBps: Long): String {
        fun one(bytes: Long): String = when {
            bytes >= 1024 * 1024 -> String.format(
                java.util.Locale.US,
                "%.1f MB/s",
                bytes / (1024.0 * 1024.0),
            )
            bytes >= 1024 -> String.format(
                java.util.Locale.US,
                "%.0f KB/s",
                bytes / 1024.0,
            )
            else -> "$bytes B/s"
        }
        return "↑ ${one(txBps)}  ↓ ${one(rxBps)}"
    }
}
