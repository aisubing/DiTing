package com.haoze.diting.core.rule

/**
 * Compiles a rule-supplied regular expression with the same case semantics the
 * Go engine applies, so both filtering engines agree on every subscription.
 *
 * `policy_engine.go` prefixes `(?i)` to a regex rule unless the pattern already
 * starts with it, i.e. matching is case-insensitive by default. The Kotlin
 * matchers used a bare [Regex], so an upper-case regex subscription rule
 * matched in Go but not in Kotlin. This mirrors the Go rule literally — prefix
 * `(?i)` only when the pattern does not already start with it — so a pattern
 * that opens with another inline flag group (`(?-i)`, `(?s)`, …) ends up with
 * exactly the same flag set as on the Go side.
 */
internal object RuleRegex {

    private const val CASE_INSENSITIVE_PREFIX = "(?i)"

    fun compile(pattern: String): Regex =
        if (pattern.startsWith(CASE_INSENSITIVE_PREFIX)) {
            Regex(pattern)
        } else {
            Regex(CASE_INSENSITIVE_PREFIX + pattern)
        }

    /** Unanchored match, mirroring Go's `MatchString`. Invalid patterns never match. */
    fun containsMatch(pattern: String, domain: String): Boolean =
        runCatching { compile(pattern).containsMatchIn(domain) }.getOrDefault(false)
}
