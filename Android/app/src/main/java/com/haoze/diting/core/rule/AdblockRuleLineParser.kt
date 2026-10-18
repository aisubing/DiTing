package com.haoze.diting.core.rule

import com.haoze.diting.data.entity.RewriteTargetType

internal object AdblockRuleLineParser {

    /**
     * Longest delimiter first so a four-character marker is never matched by a
     * shorter one. `#$@#` is the exception form of the `#$#` style rule; it was
     * missing entirely, which made every `example.com#$@#selector` line fall
     * through to the trailing-comment truncation below and turn into a
     * whole-domain block.
     */
    private val COSMETIC_DELIMITERS = listOf("#$@#", "#@#", "##", "#?#", "#$#")

    /**
     * Whether the line uses an element-hiding delimiter. A line starting with
     * `#` may be either a comment or a generic cosmetic rule (`##.ad`), so the
     * delimiter has to be recognized before comment filtering.
     */
    fun isCosmeticRuleLine(line: String): Boolean =
        COSMETIC_DELIMITERS.any { line.contains(it) }

    /**
     * Index at which a trailing `#` comment may start.
     *
     * A `#` inside a leading regex literal (`/foo#bar/`) is part of the pattern,
     * not a comment, so the scan starts just past the literal's closing `/`. A
     * comment that follows the literal (`/foo#bar/ # note`) is still found, since
     * it starts after that point. Zero is returned for every line that does not
     * start with a regex delimiter, so the plain search from the beginning is
     * preserved.
     */
    private fun commentSearchStart(line: String, allow: Boolean): Int {
        val offset = if (allow && line.startsWith("@@")) 2 else 0
        if (line.length <= offset + 1 || line[offset] != '/') return 0
        // A regex literal ends at the first whitespace of the line.
        var tokenEnd = offset + 1
        while (tokenEnd < line.length && !line[tokenEnd].isWhitespace()) tokenEnd++
        val closing = line.lastIndexOf('/', tokenEnd - 1)
        return if (closing <= offset) 0 else closing + 1
    }

    fun parseAdblockOrDomainLine(line: String, originalLine: String, allow: Boolean): CategorizedLine {
        // 1. Element hiding (cosmetic) rules: ##, #@#, #?#, #$#, #$@#
        val cosmetic = parseCosmeticLine(line, originalLine)
        if (cosmetic != null) {
            return cosmetic
        }

        // Only a `#` that begins a trailing comment may be dropped. A `#` glued
        // to the pattern is a cosmetic marker this parser did not recognize (or
        // a malformed rule); truncating there would silently widen it into a
        // whole-domain block, so such lines are reported as unsupported instead.
        // A regex rule may legitimately carry `#` inside its pattern
        // (`/foo#bar/`); the scan starts past the literal so such a rule is kept.
        val hashIndex = line.indexOf('#', commentSearchStart(line, allow))
        var value = if (hashIndex < 0) {
            line.trim()
        } else {
            val before = line.substring(0, hashIndex)
            if (before.isEmpty() || before.last().isWhitespace()) before.trim()
            else return CategorizedLine(unsupportedCount = 1)
        }
        if (value.isEmpty()) return CategorizedLine(invalidCount = 1)
        if (allow) value = value.removePrefix("@@")

        // 2. Regex syntax
        var isRegex = false
        var regexPattern: String? = null
        var modifiersStr: String? = null

        if (value.startsWith("/")) {
            val lastSlash = value.lastIndexOf('/')
            if (lastSlash > 0) {
                val extractedRegex = value.substring(1, lastSlash).trim()
                if (extractedRegex.isNotEmpty()) {
                    val validRegex = runCatching { Regex(extractedRegex) }.isSuccess
                    if (validRegex) {
                        isRegex = true
                        regexPattern = extractedRegex
                        val tail = value.substring(lastSlash + 1).trim()
                        if (tail.isNotEmpty()) {
                            if (!tail.startsWith("$")) {
                                return CategorizedLine(invalidCount = 1)
                            }
                            modifiersStr = tail.substring(1)
                        }
                        value = ""
                    } else {
                        return CategorizedLine(invalidCount = 1)
                    }
                } else {
                    return CategorizedLine(invalidCount = 1)
                }
            }
        }

        if (!isRegex) {
            val modifierIndex = value.indexOf('$')
            if (modifierIndex >= 0) {
                modifiersStr = value.substring(modifierIndex + 1)
                value = value.substring(0, modifierIndex).trim()
            }
        }

        // 3. Modifier handling
        var important = false
        var appScope: String? = null
        var appInverted = false
        var dnsrewriteTargetType: String? = null
        var dnsrewriteTargetValue: String? = null
        var dnsrewriteIsBlock = false
        var isBadfilter = false
        var denyallow: String? = null
        var dnsType: String? = null
        var isWebModifierPresent = false

        if (!modifiersStr.isNullOrEmpty()) {
            val modifiers = modifiersStr.split(',').map { it.trim() }.filter { it.isNotEmpty() }
            for (token in modifiers) {
                val lower = token.lowercase()
                when {
                    lower == "important" -> important = true
                    // `~denyallow=` has no invertible meaning (the modifier is already
                    // an exclusion list), so the modifier is dropped while the rule
                    // itself is kept — the same rule the desktop parser applies.
                    // Reading it as a plain denyallow used to turn those domains into
                    // exceptions of an otherwise active block rule, so the rule blocked
                    // nothing the author intended it to block.
                    lower.startsWith("~denyallow=") -> Unit
                    lower.startsWith("app=") || lower.startsWith("~app=") -> {
                        val isNegativePrefix = lower.startsWith("~app=")
                        val appValue = if (isNegativePrefix) token.substring(5).trim() else token.substring(4).trim()
                        if (appValue.isEmpty()) return CategorizedLine(unsupportedCount = 1)
                        val pkgs = appValue.split('|').map { it.trim() }.filter { it.isNotEmpty() }
                        if (pkgs.isEmpty()) return CategorizedLine(unsupportedCount = 1)
                        val hasInverted = isNegativePrefix || pkgs.any { it.startsWith("~") }
                        val cleanPkgs = pkgs.map { it.removePrefix("~").trim().lowercase() }.filter { it.isNotEmpty() }
                        if (cleanPkgs.isEmpty()) return CategorizedLine(unsupportedCount = 1)
                        appInverted = hasInverted
                        appScope = cleanPkgs.joinToString("|")
                    }
                    lower.startsWith("denyallow=") -> {
                        val rawSpec = token.substring(10).trim()
                        if (rawSpec.isEmpty()) return CategorizedLine(invalidCount = 1)
                        val rawDomains = rawSpec.split('|').map { it.trim().lowercase() }.filter { it.isNotEmpty() }
                        if (rawDomains.isEmpty()) return CategorizedLine(invalidCount = 1)
                        val cleanDomains = mutableListOf<String>()
                        for (d in rawDomains) {
                            val clean = d.removePrefix("||").trimEnd('^').trimEnd('.')
                            val normalized = AdGuardDomainUtils.normalizeDomain(clean) ?: return CategorizedLine(invalidCount = 1)
                            cleanDomains += normalized
                        }
                        denyallow = cleanDomains.joinToString("|")
                    }
                    lower.startsWith("dnstype=") || lower.startsWith("~dnstype=") -> {
                        val isNegative = lower.startsWith("~dnstype=")
                        val rawSpec = if (isNegative) token.substring(9).trim() else token.substring(8).trim()
                        if (rawSpec.isEmpty()) return CategorizedLine(unsupportedCount = 1)
                        val rawTypes = rawSpec.split('|').map { it.trim().uppercase() }.filter { it.isNotEmpty() }
                        if (rawTypes.isEmpty()) return CategorizedLine(unsupportedCount = 1)
                        val cleanTypes = mutableListOf<String>()
                        for (t in rawTypes) {
                            val actual = t.removePrefix("~")
                            if (actual !in AdGuardDomainUtils.VALID_DNS_TYPES) return CategorizedLine(unsupportedCount = 1)
                            cleanTypes += actual
                        }
                        dnsType = if (isNegative || rawTypes.any { it.startsWith("~") }) {
                            "~" + cleanTypes.joinToString("|")
                        } else {
                            cleanTypes.joinToString("|")
                        }
                    }
                    lower.startsWith("dnsrewrite=") -> {
                        val rawSpec = token.substring(11).trim()
                        if (rawSpec.isEmpty()) return CategorizedLine(invalidCount = 1)
                        val targetSpec = if (rawSpec.contains(';')) {
                            val parts = rawSpec.split(';').map { it.trim() }.filter { it.isNotEmpty() }
                            if (parts.first().uppercase() in setOf("NXDOMAIN", "REFUSED", "SERVFAIL")) "NXDOMAIN" else parts.last()
                        } else rawSpec

                        val upper = targetSpec.uppercase()
                        val lowerTarget = targetSpec.lowercase()
                        if (upper in setOf("NXDOMAIN", "REFUSED", "SERVFAIL") || lowerTarget in AdGuardDomainUtils.SINKHOLE_ADDRESSES) {
                            dnsrewriteIsBlock = true
                        } else if (AdGuardDomainUtils.looksLikeLiteralIp(targetSpec)) {
                            val addr = AdGuardDomainUtils.parseNumericAddressSafe(targetSpec)
                            if (addr != null) {
                                dnsrewriteTargetType = if (addr.address.size == 4) RewriteTargetType.IPV4 else RewriteTargetType.IPV6
                                dnsrewriteTargetValue = if (addr.address.size == 4) addr.hostAddress else targetSpec.trim()
                            } else return CategorizedLine(invalidCount = 1)
                        } else {
                            val cname = AdGuardDomainUtils.normalizeDomain(targetSpec)
                            if (cname != null) {
                                dnsrewriteTargetType = RewriteTargetType.CNAME
                                dnsrewriteTargetValue = cname
                            } else return CategorizedLine(invalidCount = 1)
                        }
                    }
                    lower == "badfilter" -> isBadfilter = true
                    AdGuardDomainUtils.isWebOnlyModifier(lower) -> {
                        return CategorizedLine(ignoredCount = 1)
                    }
                    lower == "all" || lower == "empty" -> {
                        // $all matches all content types
                    }
                    else -> return CategorizedLine(unsupportedCount = 1)
                }
            }
        }

        // 4. Check if this is a URL/Path interception rule
        if (!isRegex && isUrlOrPathRule(value)) {
            val cleanPattern = cleanUrlPattern(value)
            if (cleanPattern.isNotEmpty()) {
                if (isBadfilter) {
                    val key = if (allow) "url_allow:$cleanPattern:$appScope" else "url_block:$cleanPattern:$appScope"
                    return CategorizedLine(badfilterKeys = setOf(key))
                }
                val urlRule = ParsedUrlRule(
                    pattern = cleanPattern,
                    rawLine = originalLine,
                    isAllow = allow,
                    appScope = appScope,
                    important = important
                )
                return if (allow) {
                    CategorizedLine(urlAllowRules = listOf(urlRule))
                } else {
                    CategorizedLine(urlBlockRules = listOf(urlRule))
                }
            }
        }

        // 5. Standard domain rule
        val domain: String
        val isWildcard: Boolean
        if (isRegex) {
            domain = regexPattern!!
            isWildcard = false
        } else {
            value = when {
                value.startsWith("||") -> value.removePrefix("||").trimEnd('^')
                value.startsWith("|") || value.endsWith("|") -> return CategorizedLine(unsupportedCount = 1)
                else -> value.trimEnd('^')
            }

            isWildcard = value.contains('*')
            domain = (if (isWildcard) {
                AdGuardDomainUtils.normalizeWildcardDomain(value)
            } else {
                AdGuardDomainUtils.normalizeDomain(value)
            }) ?: return CategorizedLine(invalidCount = 1)
        }

        if (isBadfilter) {
            val key = when {
                dnsrewriteTargetType != null && dnsrewriteTargetValue != null ->
                    AdGuardRuleParser.rewriteRuleKey(domain, dnsrewriteTargetType, dnsrewriteTargetValue)
                dnsrewriteIsBlock || !allow ->
                    AdGuardRuleParser.blockRuleKey(domain, important, appScope, appInverted, denyallow, isRegex, dnsType)
                else ->
                    AdGuardRuleParser.allowRuleKey(domain, important, appScope, appInverted, denyallow, isRegex, dnsType)
            }
            return CategorizedLine(badfilterKeys = setOf(key))
        }

        if (dnsrewriteTargetType != null && dnsrewriteTargetValue != null) {
            val rule = RewriteRule(domain, dnsrewriteTargetType, dnsrewriteTargetValue, originalLine)
            return CategorizedLine(rewriteRules = listOf(rule))
        }

        val rule = ParsedRule(domain, originalLine, important, appScope, appInverted, isWildcard, denyallow, isRegex, dnsType)
        if (dnsrewriteIsBlock) {
            return CategorizedLine(blockRules = listOf(rule))
        }

        return if (allow) {
            CategorizedLine(allowRules = listOf(rule))
        } else {
            CategorizedLine(blockRules = listOf(rule))
        }
    }

    private fun parseCosmeticLine(line: String, originalLine: String): CategorizedLine? {
        // `#$@#` is the exception form of `#$#`, so it counts as an exception and
        // must be probed before the shorter `#$#` / `##` markers.
        val isException = line.contains("#@#") || line.contains("#$@#")
        val delimiter = when {
            line.contains("#$@#") -> "#$@#"
            line.contains("#@#") -> "#@#"
            line.contains("##") -> "##"
            line.contains("#?#") -> "#?#"
            line.contains("#$#") -> "#$#"
            else -> return null
        }

        val parts = line.split(delimiter, limit = 2)
        if (parts.size != 2) return CategorizedLine(invalidCount = 1)

        val domainPart = parts[0].trim()
        val selectorPart = parts[1].trim()

        if (selectorPart.isEmpty()) return CategorizedLine(invalidCount = 1)

        val domains = if (domainPart.isEmpty()) {
            listOf("")
        } else {
            domainPart.split(',').map { it.trim() }.filter { it.isNotEmpty() }
        }

        val rules = domains.map { domain ->
            ParsedCosmeticRule(
                domain = domain,
                selector = selectorPart,
                rawLine = originalLine,
                isException = isException
            )
        }
        return CategorizedLine(cosmeticRules = rules)
    }

    private fun isUrlOrPathRule(value: String): Boolean {
        if (value.startsWith("http://", ignoreCase = true) || value.startsWith("https://", ignoreCase = true) ||
            value.startsWith("|http://", ignoreCase = true) || value.startsWith("|https://", ignoreCase = true)
        ) {
            return true
        }
        // ||domain/path^ or ||*/path^
        if (value.startsWith("||") && value.removePrefix("||").contains('/')) {
            return true
        }
        // Path-only rules: */api/... or /api/... (exclude /.../ regexes)
        if (value.startsWith("*/") && value.length > 2) {
            return true
        }
        if (value.startsWith("/") && !value.endsWith("/") && value.length > 2) {
            return true
        }
        return false
    }

    private fun cleanUrlPattern(value: String): String {
        return value.removePrefix("||").removePrefix("|").removeSuffix("^").trim()
    }
}
