package com.haoze.diting.normal

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * O-103: `refreshRuntimeConfig` committed the *newly requested* resolution mode to the
 * Kotlin snapshot on the provider-resolution failure branch, where the Go engine had
 * just been re-synced with the *previous* providers and therefore kept running the
 * *previous* mode. Notifications and the UI then rendered a mode the engine was not
 * running, until some later change made the two sides agree again.
 *
 * The invariant pinned here: the resolution mode stored in the snapshot is the mode the
 * engine actually accepted.
 */
class RuntimeConfigCommitPolicyTest {

    private enum class Mode { SINGLE, PARALLEL_RACE }

    @Test
    fun failedRefreshKeepsTheModeTheEngineIsRunning() {
        // The engine was re-synced with the old providers, so it is still SINGLE; the
        // snapshot must not jump to the newly selected PARALLEL_RACE.
        assertEquals(
            Mode.SINGLE,
            RuntimeConfigCommitPolicy.committedResolutionMode(
                current = Mode.SINGLE,
                requested = Mode.PARALLEL_RACE,
                applied = false
            )
        )
    }

    @Test
    fun successfulRefreshCommitsTheRequestedMode() {
        assertEquals(
            Mode.PARALLEL_RACE,
            RuntimeConfigCommitPolicy.committedResolutionMode(
                current = Mode.SINGLE,
                requested = Mode.PARALLEL_RACE,
                applied = true
            )
        )
    }

    @Test
    fun snapshotNeverAdvancesPastTheEngine() {
        // The core property: the committed mode is the requested one iff the engine took
        // it, and otherwise the engine's current mode.
        for (applied in listOf(false, true)) {
            for ((current, requested) in listOf(
                Mode.SINGLE to Mode.PARALLEL_RACE,
                Mode.PARALLEL_RACE to Mode.SINGLE
            )) {
                assertEquals(
                    "applied=$applied current=$current requested=$requested",
                    if (applied) requested else current,
                    RuntimeConfigCommitPolicy.committedResolutionMode(current, requested, applied)
                )
            }
        }
    }

    @Test
    fun noopRefreshIsStableOnEveryPath() {
        for (applied in listOf(false, true)) {
            assertEquals(
                Mode.SINGLE,
                RuntimeConfigCommitPolicy.committedResolutionMode(
                    current = Mode.SINGLE,
                    requested = Mode.SINGLE,
                    applied = applied
                )
            )
        }
    }
}