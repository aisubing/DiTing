package com.haoze.diting.core.rule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-094: the `#$@#` element-hiding delimiter was missing from
 * [AdblockRuleLineParser]'s delimiter list, and a `#` glued to the pattern was
 * silently truncated into a whole-domain block.
 */
class AdblockRuleLineParserCosmeticDelimiterTest {

    private fun cosmeticLines(line: String): CategorizedLine = AdGuardRuleParser.parseCategorizedLine(line)

    @Test
    fun exceptionDelimiterAtRuleIsRecognized() {
        val result = cosmeticLines("example.com#@#div.ad")
        assertEquals(1, result.cosmeticRules.size)
        val rule = result.cosmeticRules.single()
        assertEquals("example.com", rule.domain)
        assertEquals("div.ad", rule.selector)
        assertTrue(rule.isException)
        assertEquals(0, result.blockRules.size)
    }

    @Test
    fun exceptionDelimiterDollarAtRuleIsRecognized() {
        // `#$@#` is the exception form of `#$#`. It was missing from the
        // delimiter list, so this line fell through to the `#` truncation.
        val result = cosmeticLines("example.com#$@#div.ad")
        assertEquals(1, result.cosmeticRules.size)
        val rule = result.cosmeticRules.single()
        assertEquals("example.com", rule.domain)
        assertEquals("div.ad", rule.selector)
        assertTrue(rule.isException)
        assertEquals(0, result.blockRules.size)
    }

    @Test
    fun hideDelimiterStillProducesNonExceptionRule() {
        val result = cosmeticLines("example.com##.ad")
        assertEquals(1, result.cosmeticRules.size)
        val rule = result.cosmeticRules.single()
        assertEquals("example.com", rule.domain)
        assertEquals(".ad", rule.selector)
        assertFalse(rule.isException)
    }

    @Test
    fun dollarHideDelimiterIsNotTreatedAsException() {
        val result = cosmeticLines("example.com#$#.ad { display: none }")
        assertEquals(1, result.cosmeticRules.size)
        assertFalse(result.cosmeticRules.single().isException)
    }

    @Test
    fun fourCharDelimiterWinsOverTwoCharDelimiter() {
        // Longest-first ordering: `#$@#` must not be split on the inner `#$#`.
        val result = cosmeticLines("a.com#$@#.x")
        val rule = result.cosmeticRules.single()
        assertEquals("a.com", rule.domain)
        assertEquals(".x", rule.selector)
    }

    @Test
    fun garbageDollarAtLineDoesNotBecomeWholeDomainBlock() {
        // `example.com#$@` matches no known delimiter. The old code took
        // `substringBefore('#')`, i.e. "example.com", and blocked the entire
        // domain — far wider than the author intended. It must be rejected.
        val result = cosmeticLines("example.com#\$@")
        assertEquals(0, result.blockRules.size)
        assertEquals(0, result.cosmeticRules.size)
        assertTrue(result.unsupportedCount + result.invalidCount > 0)
    }

    @Test
    fun trailingCommentIsStillStripped() {
        // A `#` preceded by whitespace is a trailing comment, not a delimiter.
        val result = cosmeticLines("||ads.example.com^ # tracker")
        assertEquals(1, result.blockRules.size)
        assertEquals("ads.example.com", result.blockRules.single().pattern)
    }

    @Test
    fun isCosmeticRuleLineCoversEveryDelimiter() {
        assertTrue(AdblockRuleLineParser.isCosmeticRuleLine("a.com##.ad"))
        assertTrue(AdblockRuleLineParser.isCosmeticRuleLine("a.com#@#.ad"))
        assertTrue(AdblockRuleLineParser.isCosmeticRuleLine("a.com#?#.ad"))
        assertTrue(AdblockRuleLineParser.isCosmeticRuleLine("a.com#$#.ad"))
        assertTrue(AdblockRuleLineParser.isCosmeticRuleLine("a.com#$@#.ad"))
        assertFalse(AdblockRuleLineParser.isCosmeticRuleLine("||ads.example.com^"))
    }
}
