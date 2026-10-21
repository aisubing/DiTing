package com.haoze.diting.core.log

import com.haoze.diting.util.dayStringAt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-014: `app_traffic_daily` was pruned inside `pruneExpiredLogs` using the
 * *DNS log* retention days, while the dedicated setting
 * `SystemSettingsStore.getTrafficStatsRetentionDays` (default 30 days, 1..90)
 * had no consumer at all in the prune path. A user keeping DNS logs for 1 day
 * silently lost 30 days of traffic history; conversely a 30-day log retention
 * kept traffic rows 30 days even when the traffic setting asked for 1.
 *
 * `trafficCutoffDate` now derives the traffic cutoff from its own window.
 */
class LogMaintenanceTrafficRetentionTest {

    private val dayMs = 24L * 60L * 60L * 1000L
    private val now = 1_700_000_000_000L

    @Test
    fun trafficCutoffUsesTheTrafficRetentionWindow() {
        assertEquals(
            dayStringAt(now - 30 * dayMs),
            LogMaintenance.trafficCutoffDate(retentionDays = 30, nowMillis = now)
        )
    }

    @Test
    fun trafficCutoffDiffersFromTheLogRetentionWindow() {
        val trafficCutoff = LogMaintenance.trafficCutoffDate(retentionDays = 30, nowMillis = now)
        val logCutoff = dayStringAt(now - 1 * dayMs)

        assertNotEquals(
            "a 30-day traffic window must not collapse to the 1-day log window",
            logCutoff,
            trafficCutoff
        )
    }

    @Test
    fun trafficCutoffIsMonotonicInRetentionDays() {
        val oneDay = LogMaintenance.trafficCutoffDate(retentionDays = 1, nowMillis = now)
        val thirtyDays = LogMaintenance.trafficCutoffDate(retentionDays = 30, nowMillis = now)
        val ninetyDays = LogMaintenance.trafficCutoffDate(retentionDays = 90, nowMillis = now)

        // ISO dates compare lexicographically in chronological order.
        assertTrue("1-day cutoff must be later than 30-day", oneDay > thirtyDays)
        assertTrue("30-day cutoff must be later than 90-day", thirtyDays > ninetyDays)
    }

    @Test
    fun defaultRetentionWindowsAreIndependent() {
        // The two settings must not share a default: 7 days of DNS logs vs
        // 30 days of traffic history.
        assertNotEquals(
            com.haoze.diting.ui.settings.SystemSettingsStore.DEFAULT_LOG_RETENTION_DAYS,
            com.haoze.diting.ui.settings.SystemSettingsStore.DEFAULT_TRAFFIC_STATS_RETENTION_DAYS
        )
        assertEquals(7, com.haoze.diting.ui.settings.SystemSettingsStore.DEFAULT_LOG_RETENTION_DAYS)
        assertEquals(30, com.haoze.diting.ui.settings.SystemSettingsStore.DEFAULT_TRAFFIC_STATS_RETENTION_DAYS)
    }
}
