package com.haoze.diting.ui.dashboard

import com.haoze.diting.core.log.LogResult

/**
 * Human readable result label for a DNS log row.
 *
 * Connection-level rows (`queryType == 0` / `TCP …` / `UDP …` / `blocked_by=connection`)
 * are not real DNS lookups, so a plain pass is shown as 「旁路」. That substitution
 * must only apply to the pass result: a blocked connection-level row is still a
 * filtered request and was previously mislabelled as 「旁路」, which made blocked
 * traffic look like it had been allowed through.
 */
fun dashboardDnsResultLabel(result: String, isConnectionLevel: Boolean): String {
    return when (result) {
        LogResult.PASSED.value -> if (isConnectionLevel) "旁路" else "通过"
        LogResult.REWRITTEN.value -> "覆写"
        LogResult.BLOCKED.value -> "过滤"
        LogResult.ERROR.value -> "失败"
        else -> result
    }
}

/**
 * Status token for a DNS log row, kept next to [dashboardDnsResultLabel] so the
 * two can never drift apart again.
 */
fun dashboardDnsResultStatus(result: String, isConnectionLevel: Boolean): String {
    return when (result) {
        LogResult.REWRITTEN.value -> "rewritten"
        LogResult.PASSED.value -> if (isConnectionLevel) "bypassed" else "passed"
        LogResult.BLOCKED.value -> "blocked"
        else -> "error"
    }
}
