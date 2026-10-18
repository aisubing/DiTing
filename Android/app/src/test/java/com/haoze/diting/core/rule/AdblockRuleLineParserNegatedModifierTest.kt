package com.haoze.diting.core.rule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * O-151(b): `~denyallow=` has no invertible meaning (the modifier is already an
 * exclusion list), so it must be ignored while the rule itself is kept — the same
 * semantics as the desktop parser (`rule_parser.go`: 「安全忽略该修饰符（保留整
 * 条规则）」).
 *
 * Previously it was parsed as a *positive* denyallow list, which turned those
 * domains into exceptions of an otherwise active block rule, so the line blocked
 * far less than the author intended.
 */
class AdblockRuleLineParserNegatedModifierTest {

    private fun parse(line: String): CategorizedLine = AdGuardRuleParser.parseCategorizedLine(line)

    @Test
    fun negatedDenyallowKeepsRuleAndDropsExceptions() {
        val result = parse("||example.com^\$~denyallow=x.com|y.com")
        assertEquals(1, result.blockRules.size)
        val rule = result.blockRules.single()
        assertEquals("example.com", rule.pattern)
        assertNull(rule.denyallow)
        assertEquals(0, result.unsupportedCount)
        assertEquals(0, result.invalidCount)
    }

    @Test
    fun positiveDenyallowStillPopulatesExceptions() {
        // Guard: the fix must not weaken the normal, meaningful form.
        val result = parse("||example.com^\$denyallow=x.com|y.com")
        assertEquals(1, result.blockRules.size)
        assertEquals("x.com|y.com", result.blockRules.single().denyallow)
    }

    @Test
    fun otherNegatedModifiersKeepTheirOwnSemantics() {
        // Guard the scope of this fix: `~dnstype=`/`~app=` keep their existing
        // inverted meaning, and `~to=` stays a web-only modifier (ignoring the
        // rule entirely is what prevents a DNS-stage over-block there).
        val dnsTypeResult = parse("||example.com^\$~dnstype=A")
        assertEquals(1, dnsTypeResult.blockRules.size)
        assertEquals("~A", dnsTypeResult.blockRules.single().dnsType)

        val appResult = parse("||example.com^\$~app=com.example")
        assertEquals(1, appResult.blockRules.size)
        assertTrue(appResult.blockRules.single().appInverted)

        val toResult = parse("||example.com^\$~to=x.com")
        assertEquals(0, toResult.blockRules.size)
        assertEquals(1, toResult.ignoredCount)
    }

    @Test
    fun negatedDenyallowDoesNotAffectOtherModifiers() {
        // `important` next to an ignored modifier must still be applied.
        val result = parse("||ads.example.com^\$important,~denyallow=keep.com")
        assertEquals(1, result.blockRules.size)
        val rule = result.blockRules.single()
        assertTrue(rule.important)
        assertNull(rule.denyallow)
    }

    @Test
    fun emptyNegatedDenyallowIsIgnoredNotReinterpreted() {
        // The desktop parser ignores the whole `~denyallow=` modifier whatever
        // its payload, so a malformed payload must not turn into a plain
        // denyallow list either — the rule simply keeps no exceptions.
        val result = parse("||example.com^\$~denyallow=")
        assertEquals(1, result.blockRules.size)
        assertNull(result.blockRules.single().denyallow)
    }
}
