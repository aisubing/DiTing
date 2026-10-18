package com.haoze.diting.core.traffic

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-078: `restartVpnLocked()` (triggered by editing the excluded / blocked app
 * lists) tears the tunnel down and calls `startVpn()` again, which calls
 * `TrafficStatsManager.start()` without an intervening `stop()`. `start()` used
 * to unconditionally zero the session totals, the session start time, the
 * per-app session bytes and the speed estimator, so the user's session
 * statistics silently restarted from zero on every config change.
 *
 * `shouldResetSessionCounters()` keeps the reset on a genuine (re)start only.
 */
class TrafficStatsManagerSessionResetTest {

    @Test
    fun firstStartResetsSession() {
        assertTrue(
            "a cold start must begin a fresh session",
            TrafficStatsManager.shouldResetSessionCounters(wasRunning = false)
        )
    }

    @Test
    fun configRestartWhileRunningKeepsSession() {
        assertFalse(
            "a restart without stop() must preserve the session counters",
            TrafficStatsManager.shouldResetSessionCounters(wasRunning = true)
        )
    }
}
