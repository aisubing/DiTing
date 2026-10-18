package com.haoze.diting.update

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-047: update-download progress was reported per OkHttp chunk (a 64 KB step),
 * so a fast link produced dozens of callbacks per second, each repainting the
 * settings screen and re-posting the progress notification.
 * [AppUpdateProgressThrottle] requires both a byte step and a time gap; the
 * decision is pinned here.
 */
class AppUpdateProgressThrottleTest {

    private val kb = 1024L

    @Test
    fun firstReportIsAlwaysAllowed() {
        val throttle = AppUpdateProgressThrottle()
        assertTrue(throttle.shouldReport(0L, 0L))
    }

    @Test
    fun byteStepBelowThresholdIsSuppressed() {
        val throttle = AppUpdateProgressThrottle(minBytes = 256 * kb, minIntervalMs = 0L)
        assertTrue(throttle.shouldReport(0L, 0L))
        assertFalse(throttle.shouldReport(100 * kb, 10_000L))
        assertFalse(throttle.shouldReport(255 * kb, 10_000L))
        assertTrue(throttle.shouldReport(256 * kb, 10_000L))
    }

    @Test
    fun timeGapBelowThresholdIsSuppressedOnFastLinks() {
        // The regression: a big byte step within the same millisecond used to be
        // reported every call.
        val throttle = AppUpdateProgressThrottle(minBytes = 256 * kb, minIntervalMs = 250L)
        assertTrue(throttle.shouldReport(0L, 0L))
        assertFalse(throttle.shouldReport(10 * 1024 * kb, 1L))
        assertFalse(throttle.shouldReport(20 * 1024 * kb, 249L))
        assertTrue(throttle.shouldReport(21 * 1024 * kb, 250L))
    }

    @Test
    fun windowRestartsAfterEachReport() {
        // A reported update becomes the new baseline for both dimensions.
        val throttle = AppUpdateProgressThrottle(minBytes = 256 * kb, minIntervalMs = 250L)
        assertTrue(throttle.shouldReport(0L, 0L))
        assertTrue(throttle.shouldReport(256 * kb, 250L))
        assertFalse(throttle.shouldReport(512 * kb, 300L))
        assertTrue(throttle.shouldReport(1_024 * kb, 500L))
    }

    @Test
    fun forcedReportMovesTheBaseline() {
        val throttle = AppUpdateProgressThrottle(minBytes = 256 * kb, minIntervalMs = 250L)
        assertTrue(throttle.shouldReport(0L, 0L))
        // Force the final update, then a small trailing callback must stay quiet.
        throttle.markReported(300 * kb, 100L)
        assertFalse(throttle.shouldReport(310 * kb, 1_000L))
        assertTrue(throttle.shouldReport(300 * kb + 256 * kb, 1_000L))
    }

    @Test
    fun defaultsAreBounded() {
        // Pin the shipped defaults so a future tune cannot silently reintroduce
        // a per-chunk flood.
        assertTrue(AppUpdateProgressThrottle.DEFAULT_MIN_BYTES >= 64 * kb)
        assertTrue(AppUpdateProgressThrottle.DEFAULT_MIN_INTERVAL_MS >= 100L)
    }
}
