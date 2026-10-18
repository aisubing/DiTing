package com.haoze.diting.ui.localization

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Test

/**
 * A-061: the Express request-log screen shows the empty-state text
 * `当前筛选下暂无 DNS 请求日志` through `localizedText`, but the dictionary had
 * no entry for it while [DynamicPatternLocalization] contains a generic
 * `startsWith("当前筛选下")` rule that rewrites only the prefix. The sentence
 * therefore came out half-translated
 * (`No records for the current filter暂无 DNS 请求日志`).
 *
 * The fix adds the exact entry to [translateLogsAndStatsExact], which the engine
 * consults before any pattern module, so the dynamic prefix rule can no longer
 * reach the string.
 */
class LogsAndStatsFilteredEmptyMessageTest {

    private val filteredDnsEmpty = "当前筛选下暂无 DNS 请求日志"

    @Test
    fun filteredDnsEmptyStateHasAnExactTranslation() {
        assertEquals(
            "No DNS request logs for the current filter",
            translateLogsAndStatsExact(filteredDnsEmpty)
        )
    }

    @Test
    fun exactChainResolvesItBeforeTheDynamicPrefixRule() {
        // `LocalizationEngine.translateExact` is the whole exact-module chain; a
        // null here is what pushed the string into the pattern stage.
        assertEquals(
            "No DNS request logs for the current filter",
            LocalizationEngine.translateExact(filteredDnsEmpty)
        )
    }

    @Test
    fun patternStageNoLongerNeedsToGuessTheSentence() {
        // The generic `startsWith("当前筛选下")` rule lives in the dynamic module,
        // which runs last. The sentence must be resolved before it, so the
        // logs module itself must not fall back to a prefix rewrite either.
        val patternResult = translateLogsAndStatsPattern(filteredDnsEmpty)
        assertFalse(
            "the logs pattern stage must not rewrite this sentence piecewise",
            patternResult != null && patternResult.contains("DNS 请求日志")
        )
    }

    @Test
    fun theTwoNarrowerSiblingsKeepTheirOwnWording() {
        // The DNS-dashboard and Express variants are deliberately distinct: one
        // default screen has no DNS wording at all, the other name enters the
        // message. Sharing one string would drop information in one of them.
        assertEquals(
            "No request logs for the current filter",
            translateLogsAndStatsExact("当前筛选下暂无请求日志")
        )
        // The "record"-flavoured variant is resolved by the common module's exact
        // table, which the engine consults on the way to the logs module; the logs
        // pattern entry stays as a fallback and must not disagree with it.
        assertEquals(
            "No requests under the current filter",
            LocalizationEngine.translateExact("当前筛选下暂无请求记录")
        )
        assertEquals(
            "No request records for the current filter",
            translateLogsAndStatsPattern("当前筛选下暂无请求记录")
        )
    }

    @Test
    fun theEngineResolvesAllThreeInOnePass() {
        // `LocalizationEngine.translateExact` is the live chain (the resource-id
        // step above it has no resource for any of these, verified separately).
        val expected = mapOf(
            "当前筛选下暂无 DNS 请求日志" to "No DNS request logs for the current filter",
            "当前筛选下暂无请求日志" to "No request logs for the current filter",
            "当前筛选下暂无请求记录" to "No requests under the current filter"
        )
        expected.forEach { (source, translation) ->
            assertEquals("live translation of: $source", translation, LocalizationEngine.translateExact(source))
        }
    }

    @Test
    fun noFilteredEmptyStateLeaksChineseIntoTheTranslation() {
        val translations = listOf(
            translateLogsAndStatsExact("当前筛选下暂无 DNS 请求日志"),
            translateLogsAndStatsExact("当前筛选下暂无请求日志"),
            translateLogsAndStatsPattern("当前筛选下暂无请求记录")
        )
        assertEquals("every filtered empty state must have a translation", 3, translations.size)
        translations.forEachIndexed { index, translation ->
            assertNotNull("empty state #$index has no translation", translation)
            assertFalse(
                "translation still contains Chinese text: $translation",
                translation.orEmpty().any { it.code in 0x4E00..0x9FFF }
            )
        }
    }
}
