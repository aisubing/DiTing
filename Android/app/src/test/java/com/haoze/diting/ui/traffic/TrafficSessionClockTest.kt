package com.haoze.diting.ui.traffic

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * A-057: the "connected for" line of the traffic card was computed once during
 * composition from `System.currentTimeMillis()`, so it froze whenever no traffic
 * updates arrived. [sessionClockText] is the pure part of the fix and is pinned
 * here; the ticking clock itself is a Compose effect and is covered by the
 * call site (`rememberTickingNowMs`).
 */
class TrafficSessionClockTest {

    @Test
    fun formatsElapsedTimeUnderAnHour() {
        val start = 1_700_000_000_000L
        assertEquals("00:00", sessionClockText(start, start))
        assertEquals("00:07", sessionClockText(start, start + 7_000L))
        assertEquals("01:00", sessionClockText(start, start + 60_000L))
        assertEquals("59:59", sessionClockText(start, start + 3_599_000L))
    }

    @Test
    fun formatsElapsedTimeOverAnHour() {
        val start = 1_700_000_000_000L
        assertEquals("01:00:00", sessionClockText(start, start + 3_600_000L))
        assertEquals("02:03:04", sessionClockText(start, start + 7_384_000L))
    }

    @Test
    fun negativeDeltaClampsToZero() {
        // A wall-clock change can put `now` behind the session start; the card
        // must show 00:00 instead of a negative duration.
        val start = 1_700_000_000_000L
        assertEquals("00:00", sessionClockText(start, start - 5_000L))
        assertEquals("00:00", sessionClockText(start, 0L))
    }

    @Test
    fun subSecondProgressDoesNotTickTheText() {
        // The displayed value only changes once a full second elapsed, so a
        // 1 s tick cannot render duplicates like 00:01 -> 00:01.
        val start = 1_700_000_000_000L
        assertEquals(sessionClockText(start, start + 1_000L), sessionClockText(start, start + 1_999L))
    }
}
