package com.haoze.diting.core.rule

import com.haoze.diting.data.entity.RewriteTargetType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-095: the parser searched for a trailing `#` comment starting at index 0, so a
 * `#` inside a regex literal's body (`/foo#bar/`) was treated as a comment
 * marker. Everything after it is not whitespace-separated, so the whole line was
 * rejected as unsupported and the rule silently disappeared from the dataset
 * while the desktop/Go side kept it.
 *
 * The search now starts after the closing `/` of a leading regex literal, so the
 * regex body is left intact and comment handling is unchanged everywhere else.
 */
class AdblockRuleLineParserRegexHashTest {

    private fun categorized(line: String): CategorizedLine = AdGuardRuleParser.parseCategorizedLine(line)

    @Test
    fun hashInsideRegexBodyDoesNotTruncateTheRule() {
        val result = categorized("/ads#banner/")
        assertEquals(0, result.unsupportedCount)
        assertEquals(0, result.invalidCount)
        val rule = result.blockRules.single()
        assertEquals("ads#banner", rule.pattern)
        assertTrue(rule.isRegex)
    }

    @Test
    fun hashInsideExceptionRegexBodyKeepsTheAllowRule() {
        val result = categorized("@@/ads#banner/")
        assertEquals(0, result.unsupportedCount)
        val rule = result.allowRules.single()
        assertEquals("ads#banner", rule.pattern)
        assertTrue(rule.isRegex)
        assertTrue(result.blockRules.isEmpty())
    }

    @Test
    fun modifiersAfterAHashBearingRegexAreStillRead() {
        val result = categorized("/ads#banner/ \$important")
        val rule = result.blockRules.single()
        assertEquals("ads#banner", rule.pattern)
        assertTrue(rule.isRegex)
        assertTrue(rule.important)
    }

    @Test
    fun hashInsideRegexBodyBeforeAModifierListIsNotMistakenForAComment() {
        // The regex body carries `#`, and the modifier list follows the closing
        // slash. Under the old truncation this returned unsupportedCount.
        val result = categorized("/a#b/ \$app=com.example.app")
        val rule = result.blockRules.single()
        assertEquals("a#b", rule.pattern)
        assertEquals("com.example.app", rule.appScope)
    }

    @Test
    fun trailingCommentAfterARegexLineIsStillStripped() {
        val result = categorized("@@/ads#banner/ # keep this exception")
        val rule = result.allowRules.single()
        assertEquals("ads#banner", rule.pattern)
        assertTrue(rule.isRegex)
    }

    @Test
    fun commentAndModifiersAfterAMultiHashRegexAreBothRead() {
        // Two `#` inside the body, plus a real modifier list and a real comment.
        // None of the body hashes may be mistaken for the comment marker, and the
        // comment must still be dropped.
        val result = categorized("/regex#with#hashes/ \$important # real comment")
        val rule = result.blockRules.single()
        assertEquals("regex#with#hashes", rule.pattern)
        assertTrue(rule.isRegex)
        assertTrue(rule.important)
    }

    @Test
    fun unclosedRegexLiteralWithHashIsStillRejected() {
        // No closing delimiter, so the line is not a regex literal. Falling back
        // to a whole-line domain rule would widen it, so it must stay rejected.
        val result = categorized("/ads#banner")
        assertTrue(result.blockRules.isEmpty())
        assertTrue(result.unsupportedCount + result.invalidCount > 0)
    }

    @Test
    fun hashOnAPlainDomainLineStillTruncatesOnlyARealComment() {
        // No regex delimiter: the `#` after whitespace is a trailing comment and
        // the rule survives.
        val commented = categorized("||ads.example.com^ # tracker")
        assertEquals("ads.example.com", commented.blockRules.single().pattern)

        // A `#` glued to the pattern is still not a comment: dropping it would
        // widen the rule to the whole domain.
        val glued = categorized("example.com#tracker")
        assertTrue(glued.blockRules.isEmpty())
        assertTrue(glued.unsupportedCount + glued.invalidCount > 0)
    }

    @Test
    fun cosmeticDelimitersStillWinOverTheRegexPath() {
        val result = categorized("example.com##.ad")
        assertEquals(0, result.unsupportedCount)
        assertTrue(result.blockRules.isEmpty())
        assertEquals("example.com", result.cosmeticRules.single().domain)
    }

    @Test
    fun dnsRewriteLineWithATrailingCommentStillParses() {
        val result = categorized("||ads.example.com^ \$dnsrewrite=1.2.3.4 # pinned")
        val rewrite = result.rewriteRules.single()
        assertEquals("ads.example.com", rewrite.pattern)
        assertEquals(RewriteTargetType.IPV4, rewrite.targetType)
        assertFalse(result.rewriteRules.isEmpty())
    }
}
