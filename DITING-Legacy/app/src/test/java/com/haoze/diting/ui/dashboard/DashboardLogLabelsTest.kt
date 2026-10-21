package com.haoze.diting.ui.dashboard

import com.haoze.diting.core.log.LogResult
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * A-049: the dashboard derived the label of a DNS log row from a boolean
 * (`isConn`) instead of from the actual result:
 *
 * ```
 * resultLabel = if (isConn) "旁路" else resultLabel(log.result)
 * ```
 *
 * Connection-level rows (`queryType == 0`, `TCP …`, `UDP …`,
 * `blocked_by=connection`) are not real DNS lookups, so showing a plain pass as
 * 「旁路」 is right. But the substitution ignored `result == BLOCKED`, so a
 * firewall-blocked connection was displayed as 「旁路」 — blocked traffic looked
 * like it had been allowed through. The status token was already computed
 * correctly two lines above, and the HTTPS branch of the same screen maps
 * `blocked -> 过滤` correctly, which is the twin that proves the intent.
 */
class DashboardLogLabelsTest {

    @Test
    fun blockedConnectionRowIsLabelledFiltered() {
        // The defect: this used to return 「旁路」.
        assertEquals("过滤", dashboardDnsResultLabel(LogResult.BLOCKED.value, isConnectionLevel = true))
        assertEquals("blocked", dashboardDnsResultStatus(LogResult.BLOCKED.value, isConnectionLevel = true))
    }

    @Test
    fun passedConnectionRowStaysBypassed() {
        // The bypass label is correct for a connection-level row that passed.
        assertEquals("旁路", dashboardDnsResultLabel(LogResult.PASSED.value, isConnectionLevel = true))
        assertEquals("bypassed", dashboardDnsResultStatus(LogResult.PASSED.value, isConnectionLevel = true))
    }

    @Test
    fun passedDnsRowIsLabelledPassed() {
        assertEquals("通过", dashboardDnsResultLabel(LogResult.PASSED.value, isConnectionLevel = false))
        assertEquals("passed", dashboardDnsResultStatus(LogResult.PASSED.value, isConnectionLevel = false))
    }

    @Test
    fun rewrittenRowIsLabelledOverwrittenRegardlessOfConnectionFlag() {
        assertEquals("覆写", dashboardDnsResultLabel(LogResult.REWRITTEN.value, isConnectionLevel = false))
        assertEquals("覆写", dashboardDnsResultLabel(LogResult.REWRITTEN.value, isConnectionLevel = true))
        assertEquals("rewritten", dashboardDnsResultStatus(LogResult.REWRITTEN.value, isConnectionLevel = true))
    }

    @Test
    fun blockedDnsRowIsLabelledFiltered() {
        assertEquals("过滤", dashboardDnsResultLabel(LogResult.BLOCKED.value, isConnectionLevel = false))
        assertEquals("blocked", dashboardDnsResultStatus(LogResult.BLOCKED.value, isConnectionLevel = false))
    }

    @Test
    fun errorRowIsLabelledFailedRegardlessOfConnectionFlag() {
        assertEquals("失败", dashboardDnsResultLabel(LogResult.ERROR.value, isConnectionLevel = false))
        assertEquals("失败", dashboardDnsResultLabel(LogResult.ERROR.value, isConnectionLevel = true))
        assertEquals("error", dashboardDnsResultStatus(LogResult.ERROR.value, isConnectionLevel = true))
    }

    @Test
    fun unknownResultFallsBackToTheRawValue() {
        // A future/unknown result token must not be silently relabelled.
        assertEquals("SOMETHING_NEW", dashboardDnsResultLabel("SOMETHING_NEW", isConnectionLevel = false))
        assertEquals("SOMETHING_NEW", dashboardDnsResultLabel("SOMETHING_NEW", isConnectionLevel = true))
        assertEquals("error", dashboardDnsResultStatus("SOMETHING_NEW", isConnectionLevel = true))
    }

    @Test
    fun everyResultMapsToADistinctLabelForNonConnectionRows() {
        val labels = LogResult.entries.map { dashboardDnsResultLabel(it.value, isConnectionLevel = false) }
        assertEquals(labels.size, labels.toSet().size)
    }

    @Test
    fun blockedAndPassedNeverShareALabelForConnectionRows() {
        // The regression guard: the exact confusion A-049 describes.
        val blocked = dashboardDnsResultLabel(LogResult.BLOCKED.value, isConnectionLevel = true)
        val passed = dashboardDnsResultLabel(LogResult.PASSED.value, isConnectionLevel = true)
        assertEquals(false, blocked == passed)
        assertEquals("过滤", blocked)
        assertEquals("旁路", passed)
    }
}
