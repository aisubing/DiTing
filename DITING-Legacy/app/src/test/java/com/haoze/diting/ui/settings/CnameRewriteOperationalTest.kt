package com.haoze.diting.ui.settings

import com.haoze.diting.data.RuleDataset
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * O-119: the rewrite list derived every row's "effective" state from
 * `isAddressRulesOperational`, which answers a different question — whether
 * *URL* rules can fire. DNS mode never pushes URL rules, so that method returns
 * false there, and the CNAME rows were painted as inactive with a
 * "master switch off" note even though DNS mode does deliver CNAME redirects to
 * the engine (`DnsQueryFilter.buildRewriteRulesJson()` merges them
 * unconditionally, and the Go engine applies `rewriteCNAME` at the DNS stage
 * *before* it consults `filterDNS`).
 *
 * CNAME rewrites therefore get their own predicate. These tests pin the dataset
 * decision table; the "is it really applied" half is covered by
 * [RewriteCnameDeliveryTest].
 */
class CnameRewriteOperationalTest {

    @Test
    fun dnsModeCnameRewritesAreAlwaysOperational() {
        // DNS mode's rewrite map is rebuilt on every rule reload and applied at
        // the DNS stage, independent of the ad-block master switch.
        assertTrue(cnameRewriteOperational(RuleDataset.DNS_MODE) { false })
        assertTrue(cnameRewriteOperational(RuleDataset.DNS_MODE) { true })
    }

    @Test
    fun expressNeverProgramsRewrites() {
        assertFalse(cnameRewriteOperational(RuleDataset.EXPRESS) { true })
    }

    @Test
    fun normalModeFollowsTheHttpsInspectionPrerequisites() {
        // Normal mode rewrites inside the inspection flow, so they need the same
        // prerequisites as address rules — the predicate must not hard-code true.
        assertTrue(cnameRewriteOperational(RuleDataset.NORMAL) { true })
        assertFalse(cnameRewriteOperational(RuleDataset.NORMAL) { false })
    }

    @Test
    fun onlyNormalModeConsultsTheHttpsInspectionPrerequisites() {
        // The probe itself must not be evaluated for the other datasets: it reads
        // normal-mode preferences, which are meaningless for DNS/Express.
        listOf(RuleDataset.DNS_MODE, RuleDataset.EXPRESS).forEach { dataset ->
            var consulted = false
            cnameRewriteOperational(dataset) { consulted = true; false }
            assertFalse("prerequisite probe ran for $dataset", consulted)
        }

        var consulted = false
        cnameRewriteOperational(RuleDataset.NORMAL) { consulted = true; false }
        assertTrue("NORMAL must consult the HTTPS inspection prerequisites", consulted)
    }
}
