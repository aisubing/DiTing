package com.haoze.diting.core.rule

import com.haoze.diting.data.entity.CosmeticRuleEntity
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CosmeticRuleManagerTest {

    private fun rule(domain: String, selector: String, isException: Boolean = false) =
        CosmeticRuleEntity(
            domain = domain,
            selector = selector,
            rawLine = if (isException) "$domain#@#$selector" else "$domain##$selector",
            addedAt = 0L,
            isException = isException
        )

    private fun selectors(arr: org.json.JSONArray): List<String> =
        (0 until arr.length()).map { arr.getString(it) }

    @Test
    fun scopedRulesAreGroupedByDomain() {
        val json = CosmeticRuleManager.buildScopedCssJson(
            listOf(
                rule("example.com", ".ad"),
                rule("example.com", ".banner"),
                rule("other.com", ".ad"),
                rule("", ".generic"),
                rule("example.com", ".banner", isException = true)
            )
        )
        val root = JSONObject(json)
        assertEquals(listOf(".generic"), selectors(root.getJSONArray("globalHide")))
        assertEquals(0, root.getJSONArray("globalException").length())

        val example = root.getJSONObject("domains").getJSONObject("example.com")
        assertEquals(listOf(".ad", ".banner"), selectors(example.getJSONArray("hide")))
        assertEquals(listOf(".banner"), selectors(example.getJSONArray("exception")))

        val other = root.getJSONObject("domains").getJSONObject("other.com")
        assertEquals(listOf(".ad"), selectors(other.getJSONArray("hide")))
    }

    @Test
    fun globalHideIsNotDuplicatedPerDomain() {
        val json = CosmeticRuleManager.buildScopedCssJson(
            listOf(
                rule("", ".ad"),
                rule("example.com", ".ad")
            )
        )
        val root = JSONObject(json)
        val example = root.getJSONObject("domains").getJSONObject("example.com")
        assertEquals(0, example.getJSONArray("hide").length())
        assertEquals(0, example.getJSONArray("exception").length())
        assertTrue(selectors(root.getJSONArray("globalHide")).contains(".ad"))
    }

    @Test
    fun exceptionIsNotCompiledAsHide() {
        val json = CosmeticRuleManager.buildScopedCssJson(
            listOf(rule("example.com", ".ad", isException = true))
        )
        val root = JSONObject(json)
        val example = root.getJSONObject("domains").getJSONObject("example.com")
        assertEquals(0, example.getJSONArray("hide").length())
        assertEquals(listOf(".ad"), selectors(example.getJSONArray("exception")))
        assertFalse(selectors(root.getJSONArray("globalHide")).contains(".ad"))
    }
}
