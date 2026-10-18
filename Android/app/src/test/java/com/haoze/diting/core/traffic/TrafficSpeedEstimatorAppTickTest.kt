package com.haoze.diting.core.traffic

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-015: in Go tunnel mode the Kotlin kernel sampler never runs
 * (`startSamplingLoop` is skipped when `isGoTunnelActive`), so
 * `updateSingleAppSpeedEma` was never called and every app's realtime speed
 * stayed 0 — the REALTIME_SPEED sort in the traffic screen was inert.
 *
 * `updateAppSpeedsForTick` is the per-tick entry point now used by
 * `onGoTrafficTick`: it feeds the per-app EMA for the apps present in the tick
 * and decays the ones that went idle.
 */
class TrafficSpeedEstimatorAppTickTest {

    @Test
    fun appInTickGetsNonZeroRealtimeSpeed() {
        val estimator = TrafficSpeedEstimator()

        estimator.updateAppSpeedsForTick(
            appDeltas = listOf(Triple("com.example.app", 30_000L, 60_000L)),
            elapsedSeconds = 1.0
        )

        val speed = estimator.getAppSpeed("com.example.app")
        assertTrue("app speed must be recorded", speed != null)
        // EMA_ALPHA = 0.3 over a zero baseline -> 30% of the instant rate.
        assertEquals(9_000.0, speed!!.txSpeed, 0.5)
        assertEquals(18_000.0, speed.rxSpeed, 0.5)
    }

    @Test
    fun multipleAppsInOneTickAreAllRecorded() {
        val estimator = TrafficSpeedEstimator()

        estimator.updateAppSpeedsForTick(
            appDeltas = listOf(
                Triple("pkg.a", 10_000L, 0L),
                Triple("pkg.b", 0L, 10_000L),
                Triple("pkg.c", 5_000L, 5_000L)
            ),
            elapsedSeconds = 1.0
        )

        assertEquals(3, estimator.activeAppPackages.size)
        assertEquals(3_000.0, estimator.getAppSpeed("pkg.a")!!.txSpeed, 0.5)
        assertEquals(3_000.0, estimator.getAppSpeed("pkg.b")!!.rxSpeed, 0.5)
        assertEquals(1_500.0, estimator.getAppSpeed("pkg.c")!!.txSpeed, 0.5)
    }

    @Test
    fun appMissingFromNextTickIsDecayed() {
        val estimator = TrafficSpeedEstimator()
        estimator.updateAppSpeedsForTick(
            appDeltas = listOf(Triple("pkg.a", 30_000L, 30_000L)),
            elapsedSeconds = 1.0
        )
        val before = estimator.getAppSpeed("pkg.a")!!.txSpeed
        assertTrue(before > 0)

        // pkg.a stops sending traffic; pkg.b starts.
        estimator.updateAppSpeedsForTick(
            appDeltas = listOf(Triple("pkg.b", 10_000L, 10_000L)),
            elapsedSeconds = 1.0
        )

        val after = estimator.getAppSpeed("pkg.a")!!.txSpeed
        assertTrue("idle app speed must decay, was $before now $after", after < before)
    }

    @Test
    fun emptyTickDecaysEverythingAndNeverCreatesEntries() {
        val estimator = TrafficSpeedEstimator()
        estimator.updateAppSpeedsForTick(
            appDeltas = listOf(Triple("pkg.a", 30_000L, 0L)),
            elapsedSeconds = 1.0
        )

        estimator.updateAppSpeedsForTick(appDeltas = emptyList(), elapsedSeconds = 1.0)
        estimator.updateAppSpeedsForTick(appDeltas = emptyList(), elapsedSeconds = 1.0)

        // Two idle seconds converge to exactly zero (see decaySingleAppSpeed).
        assertEquals(0.0, estimator.getAppSpeed("pkg.a")!!.txSpeed, 0.001)
        assertNull("no entry may be created for an absent app", estimator.getAppSpeed("pkg.absent"))
    }

    @Test
    fun elapsedSecondsCompensatesAggregatedTicks() {
        val estimator = TrafficSpeedEstimator()

        // The Go engine can aggregate ticks (e.g. one every 10s while off-screen):
        // 100 KB over 10s must read as 10 KB/s, not 100 KB/s.
        estimator.updateAppSpeedsForTick(
            appDeltas = listOf(Triple("pkg.a", 100_000L, 0L)),
            elapsedSeconds = 10.0
        )

        assertEquals(3_000.0, estimator.getAppSpeed("pkg.a")!!.txSpeed, 1.0)
    }
}
