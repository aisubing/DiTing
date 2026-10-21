package com.haoze.diting.core.rule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-031: `AllowRuleCache.reloadCustomRules` de-duplicated the surviving
 * subscription special rules against the freshly loaded user rules **by pattern
 * only**, unlike `BlockRuleCache` which filtered by source. Adding a user allow
 * rule whose pattern matched a subscription rule therefore dropped the
 * subscription rule from the snapshot until the next full reload.
 */
class AllowRuleSpecialRulesReloadTest {

    private fun rule(
        pattern: String,
        source: String,
        isRegex: Boolean = true
    ) = ExportedSpecialAllowRule(pattern = pattern, source = source, isRegex = isRegex)

    @Test
    fun subscriptionSpecialRuleSurvivesWhenUserRuleHasSamePattern() {
        val current = listOf(
            rule("regex-sub\\.example\\.com", "sub_3"),
            rule("regex-user\\.example\\.com", "useradd")
        )
        // The reloaded user list now contains a rule with the *same pattern* as
        // the subscription rule. The old pattern-only filter dropped the
        // subscription entry here.
        val reloaded = listOf(rule("regex-sub\\.example\\.com", "useradd"))

        val kept = retainSubscriptionSpecialRules(current, reloaded)

        assertEquals(listOf("regex-sub\\.example\\.com"), kept.map { it.pattern })
        assertEquals(listOf("sub_3"), kept.map { it.source })
    }

    @Test
    fun userSpecialRulesAreDroppedBecauseTheReloadedListReplacesThem() {
        val current = listOf(
            rule("a\\.example\\.com", "useradd"),
            rule("b\\.example\\.com", "sub_1")
        )
        val reloaded = listOf(rule("a\\.example\\.com", "useradd"))

        val kept = retainSubscriptionSpecialRules(current, reloaded)

        assertFalse(kept.any { it.source == "useradd" })
        assertEquals(listOf("b\\.example\\.com"), kept.map { it.pattern })
    }

    @Test
    fun subscriptionRulesWithDistinctPatternsAllSurvive() {
        val current = listOf(
            rule("one\\.com", "sub_1"),
            rule("two\\.com", "sub_2"),
            rule("three\\.com", "useradd")
        )

        val kept = retainSubscriptionSpecialRules(current, emptyList())

        assertEquals(listOf("one\\.com", "two\\.com"), kept.map { it.pattern })
    }

    @Test
    fun stagingSubscriptionSourceCountsAsSubscription() {
        // Staging rows are tagged `staging_sub_<id>`; they are transient and must
        // be treated like any other non-user source.
        val current = listOf(rule("staged\\.com", "staging_sub_7"))

        val kept = retainSubscriptionSpecialRules(current, emptyList())

        assertTrue(kept.isEmpty())
    }

    @Test
    fun specialAllowRuleDefaultsToUserSource() {
        // The new `source` field defaults to the user source so existing
        // constructor call sites keep their meaning.
        assertEquals(ExportedSpecialAllowRule.USER_SOURCE, ExportedSpecialAllowRule(pattern = "x").source)
        assertEquals("useradd", ExportedSpecialAllowRule.USER_SOURCE)
    }
}
