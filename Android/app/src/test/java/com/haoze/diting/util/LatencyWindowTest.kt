package com.haoze.diting.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-045: the DNS latency tester started its stopwatch before resolving the
 * provider host, so bootstrap/system resolution time was charged to the DNS
 * upstream. A provider that needs a bootstrap lookup looked slower than a
 * provider that did not, even with identical upstream latency.
 *
 * The window now opens only after the host is resolved. The second half of the
 * bug is the failure path: when the setup itself fails, the reported elapsed
 * time must be 0, not "time since the request started", so a resolution failure
 * cannot masquerade as a measured round trip.
 */
class LatencyWindowTest {

    @Test
    fun reportsZeroBeforeStart() {
        val window = LatencyWindow()
        assertFalse(window.isStarted)
        assertEquals(0L, window.elapsed(1_000_000L))
    }

    @Test
    fun measuresOnlyTimeInsideTheWindow() {
        val window = LatencyWindow()
        // Setup (host resolution) happens before the window opens and must not
        // count toward the measurement.
        window.start(10_000L)
        assertTrue(window.isStarted)
        assertEquals(0L, window.elapsed(10_000L))
        assertEquals(120L, window.elapsed(10_120L))
    }

    @Test
    fun excludesSetupTimeThatHappenedBeforeStart() {
        val window = LatencyWindow()
        // Imagine resolution took 3s: the clock only starts afterwards.
        val setupFinishedAt = 3_000L
        window.start(setupFinishedAt)
        assertEquals(50L, window.elapsed(3_050L))
        // The old code would have reported 3050ms here.
    }

    @Test
    fun elapsedIsNeverNegative() {
        val window = LatencyWindow()
        window.start(5_000L)
        assertEquals(0L, window.elapsed(4_000L))
    }

    @Test
    fun restartResetsTheWindow() {
        val window = LatencyWindow()
        window.start(1_000L)
        assertEquals(500L, window.elapsed(1_500L))

        window.start(2_000L)
        assertEquals(0L, window.elapsed(2_000L))
        assertEquals(10L, window.elapsed(2_010L))
    }

    @Test
    fun eachAttemptGetsItsOwnWindow() {
        // testAverage runs several attempts; one attempt's elapsed time must not
        // leak into the next.
        val first = LatencyWindow()
        first.start(1_000L)
        val firstElapsed = first.elapsed(1_400L)

        val second = LatencyWindow()
        second.start(1_400L)
        val secondElapsed = second.elapsed(1_450L)

        assertEquals(400L, firstElapsed)
        assertEquals(50L, secondElapsed)
    }
}
