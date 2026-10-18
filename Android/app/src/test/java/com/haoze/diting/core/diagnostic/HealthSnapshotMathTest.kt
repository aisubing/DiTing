package com.haoze.diting.core.diagnostic

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-091: `ProviderHealthEngine` had no instantiation and `recordResult` had no
 * caller anywhere in the repository, so `provider_health_json` was never written.
 * The health screen showed 「暂无运行数据」 and every smart-prediction weight was
 * the `?: 1.0` default — the UI presented fabricated equal weights as measured
 * health.
 *
 * The fix records each measured latency sample from the race-mode latency test.
 * The update rules are pure so the sample arithmetic is testable without a
 * Context.
 */
class HealthSnapshotMathTest {

    private fun snapshot(
        successes: Int = 0,
        failures: Int = 0,
        ewmaMs: Double = 250.0,
        jitterMs: Double = 0.0,
        consecutiveFailures: Int = 0,
        cooldownUntil: Long = 0L,
        decayedSuccesses: Double = successes.toDouble(),
        decayedFailures: Double = failures.toDouble(),
        lastUpdatedAt: Long = 0L
    ) = BootstrapHealthSnapshot(
        ipId = "ip-1",
        successes = successes,
        failures = failures,
        ewmaMs = ewmaMs,
        lastUpdatedAt = lastUpdatedAt,
        jitterMs = jitterMs,
        consecutiveFailures = consecutiveFailures,
        cooldownUntil = cooldownUntil,
        decayedSuccesses = decayedSuccesses,
        decayedFailures = decayedFailures
    )

    @Test
    fun successCountsAndMovesLatencyTowardTheSample() {
        val updated = HealthSnapshotMath.applySample(
            current = snapshot(ewmaMs = 200.0),
            success = true,
            elapsedMs = 400L,
            now = 1_000L
        )

        assertEquals(1, updated.successes)
        assertEquals(0, updated.failures)
        // 200 * 0.75 + 400 * 0.25 = 250
        assertEquals(250.0, updated.ewmaMs, 0.001)
        assertEquals(1_000L, updated.lastUpdatedAt)
    }

    @Test
    fun failureCountsWithoutMovingTheLatencyEstimate() {
        // A timeout is not evidence that the server answers slowly; folding it in
        // would make a briefly unreachable provider look permanently slow.
        val updated = HealthSnapshotMath.applySample(
            current = snapshot(ewmaMs = 200.0),
            success = false,
            elapsedMs = 3_000L,
            now = 1_000L
        )

        assertEquals(0, updated.successes)
        assertEquals(1, updated.failures)
        assertEquals(200.0, updated.ewmaMs, 0.001)
    }

    @Test
    fun firstSampleForAnUnknownProviderStartsFromTheDefault() {
        val updated = HealthSnapshotMath.applySample(
            current = HealthSnapshotMath.emptySnapshot("ip-1", now = 0L),
            success = true,
            elapsedMs = 250L,
            now = 1_000L
        )

        // Starting from the default 250ms and sampling 250ms stays at 250ms.
        assertEquals(250.0, updated.ewmaMs, 0.001)
        assertEquals(1, updated.successes)
    }

    @Test
    fun zeroElapsedIsClampedToOneMillisecond() {
        // A 0ms sample would otherwise be treated as "infinitely fast".
        val updated = HealthSnapshotMath.applySample(
            current = snapshot(ewmaMs = 100.0),
            success = true,
            elapsedMs = 0L,
            now = 1_000L
        )
        assertTrue(updated.ewmaMs > 0.0)
        assertEquals(100.0 * 0.75 + 1.0 * 0.25, updated.ewmaMs, 0.001)
    }

    @Test
    fun consecutiveFailuresStartACooldown() {
        var current = snapshot()
        repeat(HealthSnapshotMath.COOLDOWN_FAILURE_THRESHOLD) { index ->
            current = HealthSnapshotMath.applySample(current, success = false, elapsedMs = 1_000L, now = 1_000L)
            if (index < HealthSnapshotMath.COOLDOWN_FAILURE_THRESHOLD - 1) {
                assertEquals(0L, current.cooldownUntil)
            }
        }

        assertEquals(HealthSnapshotMath.COOLDOWN_FAILURE_THRESHOLD, current.consecutiveFailures)
        assertEquals(1_000L + HealthSnapshotMath.COOLDOWN_MS, current.cooldownUntil)
    }

    @Test
    fun successClearsTheFailureStreakAndCooldown() {
        val failing = snapshot(consecutiveFailures = 5, cooldownUntil = 99_000L)
        val updated = HealthSnapshotMath.applySample(failing, success = true, elapsedMs = 50L, now = 1_000L)

        assertEquals(0, updated.consecutiveFailures)
        assertEquals(0L, updated.cooldownUntil)
    }

    @Test
    fun failuresBelowTheThresholdDoNotCoolDown() {
        val updated = HealthSnapshotMath.applySample(
            snapshot(consecutiveFailures = 0),
            success = false,
            elapsedMs = 500L,
            now = 1_000L
        )
        assertEquals(1, updated.consecutiveFailures)
        assertEquals(0L, updated.cooldownUntil)
    }

    @Test
    fun decayedCountersTrackEverySample() {
        val afterSuccess = HealthSnapshotMath.applySample(
            snapshot(decayedSuccesses = 0.0, decayedFailures = 0.0),
            success = true,
            elapsedMs = 100L,
            now = 1_000L
        )
        val afterFailure = HealthSnapshotMath.applySample(afterSuccess, success = false, elapsedMs = 100L, now = 2_000L)

        assertEquals(1.0, afterFailure.decayedSuccesses, 0.001)
        assertEquals(1.0, afterFailure.decayedFailures, 0.001)
        assertEquals(1, afterFailure.successes)
        assertEquals(1, afterFailure.failures)
    }

    @Test
    fun jitterGrowsWhenSamplesVary() {
        val stable = HealthSnapshotMath.applySample(
            snapshot(ewmaMs = 100.0, jitterMs = 0.0),
            success = true,
            elapsedMs = 100L,
            now = 1_000L
        )
        val spiky = HealthSnapshotMath.applySample(
            snapshot(ewmaMs = 100.0, jitterMs = 0.0),
            success = true,
            elapsedMs = 900L,
            now = 1_000L
        )

        assertTrue("spiky sample should raise jitter", spiky.jitterMs > stable.jitterMs)
    }

    @Test
    fun measuredSamplesProduceDistinctPredictionWeights() {
        // The whole point of A-091: before the fix every provider fell back to the
        // same 1.0 weight, so the UI showed fabricated equal shares.
        val fast = HealthSnapshotMath.applySample(
            HealthSnapshotMath.emptySnapshot("fast", 0L),
            success = true,
            elapsedMs = 20L,
            now = 1_000L
        )
        val slow = HealthSnapshotMath.applySample(
            HealthSnapshotMath.emptySnapshot("slow", 0L),
            success = true,
            elapsedMs = 2_000L,
            now = 1_000L
        )

        val fastWeight = fast.predictionWeight
        val slowWeight = slow.predictionWeight
        assertNotEquals(fastWeight, slowWeight, 0.0001)
        assertTrue("a 20ms provider should outweigh a 2000ms one", fastWeight > slowWeight)
    }

    @Test
    fun neverSampledSnapshotFallsBackToNeutralWeight() {
        // Unchanged behaviour: no data must stay neutral rather than look bad.
        assertEquals(1.0, HealthSnapshotMath.emptySnapshot("ip-1", 0L).predictionWeight, 0.0001)
    }
}
