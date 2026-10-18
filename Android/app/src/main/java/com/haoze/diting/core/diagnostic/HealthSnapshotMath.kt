package com.haoze.diting.core.diagnostic

/**
 * Pure update rules for a health snapshot.
 *
 * Both health engines kept this arithmetic inline, which made it impossible to
 * test: the engines need a Context for preferences, and the unit-test classpath
 * has no Robolectric. Extracting it also makes the two engines provably share the
 * same EWMA/jitter/cooldown behaviour instead of drifting apart.
 */
internal object HealthSnapshotMath {

    const val DEFAULT_LATENCY_MS = 250.0
    const val EWMA_ALPHA = 0.25
    const val JITTER_ALPHA = 0.2
    const val COOLDOWN_FAILURE_THRESHOLD = 3
    const val COOLDOWN_MS = 30_000L

    /**
     * Applies one measurement to [current].
     *
     * A failure never moves the latency estimate: a timeout is not a measurement
     * of how fast the server answers, and folding the timeout value into the EWMA
     * made a temporarily unreachable provider look permanently slow.
     */
    fun applySample(
        current: BootstrapHealthSnapshot,
        success: Boolean,
        elapsedMs: Long,
        now: Long
    ): BootstrapHealthSnapshot {
        val safeElapsed = elapsedMs.coerceAtLeast(1L).toDouble()
        val nextEwma = if (success) {
            current.ewmaMs * (1.0 - EWMA_ALPHA) + safeElapsed * EWMA_ALPHA
        } else {
            current.ewmaMs
        }
        val nextJitter = if (success) {
            current.jitterMs * (1.0 - JITTER_ALPHA) + kotlin.math.abs(safeElapsed - current.ewmaMs) * JITTER_ALPHA
        } else {
            current.jitterMs
        }
        val nextConsecutiveFailures = if (success) 0 else current.consecutiveFailures + 1
        return current.copy(
            successes = current.successes + if (success) 1 else 0,
            failures = current.failures + if (success) 0 else 1,
            ewmaMs = nextEwma,
            jitterMs = nextJitter,
            consecutiveFailures = nextConsecutiveFailures,
            cooldownUntil = if (nextConsecutiveFailures >= COOLDOWN_FAILURE_THRESHOLD) {
                now + COOLDOWN_MS
            } else {
                0L
            },
            decayedSuccesses = current.decayedSuccesses + if (success) 1.0 else 0.0,
            decayedFailures = current.decayedFailures + if (success) 0.0 else 1.0,
            lastUpdatedAt = now
        )
    }

    /** An empty snapshot for [ipId], used when a sample arrives for an unknown id. */
    fun emptySnapshot(ipId: String, now: Long): BootstrapHealthSnapshot =
        BootstrapHealthSnapshot(
            ipId = ipId,
            successes = 0,
            failures = 0,
            ewmaMs = DEFAULT_LATENCY_MS,
            lastUpdatedAt = now,
            decayedSuccesses = 0.0,
            decayedFailures = 0.0
        )
}
