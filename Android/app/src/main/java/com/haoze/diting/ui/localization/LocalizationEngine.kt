package com.haoze.diting.ui.localization

import android.content.Context
import java.util.concurrent.ConcurrentHashMap

/**
 * Core localization engine. Resolves a translation in the following order:
 * 1. Hash matching against Android system resource identifiers (`context.resources.getIdentifier`);
 * 2. Fast static dictionary lookup in each domain module (`translate*Exact`);
 * 3. Dynamic templates and pattern conversions in each domain module (`translate*Pattern`);
 * 4. Falls back to returning the original text.
 */
object LocalizationEngine {

    /**
     * Cache of resource-name -> resource id. `Resources.getIdentifier` performs
     * a full resource-table lookup on every call; with 1500+ call sites (many
     * inside list rows) that is a measurable per-frame cost. The mapping is
     * stable for the process lifetime, so it is cached once per name.
     */
    private val resourceIdCache = ConcurrentHashMap<String, Int>()
    private const val RESOURCE_ID_ABSENT = -1

    internal fun stableTextResourceName(text: String): String {
        var hash = 0
        text.forEach { character -> hash = 31 * hash + character.code }
        return "localized_text_${hash.toLong().and(0x7fffffff)}"
    }

    /**
     * Translates the given text into English.
     */
    fun translate(text: String, context: Context): String {
        // 1. Android string resource lookup
        val resourceId = resolveResourceId(text, context)
        if (resourceId != 0) return context.getString(resourceId)

        // 2. Exact match dictionary lookup across domain modules
        translateExact(text)?.let { return it }

        // 3. Dynamic pattern transformations
        return translatePatterns(text) ?: text
    }

    private fun resolveResourceId(text: String, context: Context): Int {
        val name = stableTextResourceName(text)
        val cached = resourceIdCache[name]
        if (cached != null) {
            return if (cached == RESOURCE_ID_ABSENT) 0 else cached
        }
        val id = context.resources.getIdentifier(name, "string", context.packageName)
        resourceIdCache[name] = if (id == 0) RESOURCE_ID_ABSENT else id
        return id
    }

    internal fun translateExact(text: String): String? {
        return translateHomeAndOverviewExact(text)
            ?: translateDnsResolutionExact(text)
            ?: translateNetworkToolsExact(text)
            ?: translateRulesAndSubscriptionExact(text)
            ?: translateHttpInspectionExact(text)
            ?: translateAppManagementExact(text)
            ?: translateSettingsAndAppearanceExact(text)
            ?: translateLogsAndStatsExact(text)
            ?: translateAboutAndUpdateExact(text)
            ?: translateCommonExact(text)
    }

    private fun translatePatterns(text: String): String? {
        return translateHomeAndOverviewPattern(text)
            ?: translateDnsResolutionPattern(text)
            ?: translateNetworkToolsPattern(text)
            ?: translateRulesAndSubscriptionPattern(text)
            ?: translateHttpInspectionPattern(text)
            ?: translateAppManagementPattern(text)
            ?: translateSettingsAndAppearancePattern(text)
            ?: translateLogsAndStatsPattern(text)
            ?: translateAboutAndUpdatePattern(text)
            ?: translateDynamicPattern(text)
    }
}
