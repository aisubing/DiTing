package com.haoze.diting.core.rule

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-093: Kotlin regex rule matching must use the same case semantics as the Go
 * engine (`policy_engine.go` prefixes `(?i)` unless the pattern already starts
 * with it).
 */
class RuleRegexTest {

    @Test
    fun matchesUpperCasePatternAgainstLowerCaseDomain() {
        // Before the fix a bare Regex(pattern) was case-sensitive here, so this
        // subscription rule matched in Go but never in Kotlin.
        assertTrue(RuleRegex.containsMatch("Ads\\.example\\.com", "ads.example.com"))
        assertTrue(RuleRegex.containsMatch("ADS\\.EXAMPLE\\.COM", "ads.example.com"))
    }

    @Test
    fun matchesLowerCasePatternAgainstMixedCaseDomain() {
        assertTrue(RuleRegex.containsMatch("ads\\.example\\.com", "ADS.Example.COM"))
    }

    @Test
    fun keepsLeadingIgnoreCasePrefixUnchanged() {
        // Already-prefixed patterns must not get a second `(?i)`.
        assertTrue(RuleRegex.containsMatch("(?i)ads\\.example\\.com", "ads.example.com"))
    }

    @Test
    fun leadingNegativeInlineFlagStaysCaseSensitive() {
        // `(?-i)` is an inline flag group; the Go side also leaves such patterns
        // alone (its HasPrefix("(?i)") guard is false), so both stay
        // case-sensitive. This is what makes prefixing `(?i)` safe to mirror.
        assertFalse(RuleRegex.containsMatch("(?-i)ADS\\.example\\.com", "ads.example.com"))
        assertTrue(RuleRegex.containsMatch("(?-i)ADS\\.example\\.com", "ADS.example.com"))
    }

    @Test
    fun matchingIsUnanchored() {
        // Go uses MatchString, i.e. an unanchored search, not a full match.
        assertTrue(RuleRegex.containsMatch("doubleclick", "ads.doubleclick.net"))
    }

    @Test
    fun invalidPatternNeverMatches() {
        assertFalse(RuleRegex.containsMatch("(unclosed", "ads.example.com"))
    }
}
