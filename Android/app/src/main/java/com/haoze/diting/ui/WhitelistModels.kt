package com.haoze.diting.ui

import com.haoze.diting.core.rule.DefaultWhitelistSeeder
import com.haoze.diting.core.rule.GoUrlRuleManager
import com.haoze.diting.data.RuleDataset
import com.haoze.diting.data.dao.AllowRuleDao
import com.haoze.diting.data.dao.CosmeticRuleDao
import com.haoze.diting.data.dao.GoUrlRuleDao
import com.haoze.diting.data.dao.SubscriptionDao
import com.haoze.diting.data.entity.AllowRuleEntity
import com.haoze.diting.data.entity.CosmeticRuleEntity
import com.haoze.diting.data.entity.GoUrlRuleEntity
import com.haoze.diting.data.entity.GoUrlRuleKind

enum class WhitelistType {
    DOMAIN,
    URL,
    COSMETIC
}

enum class WhitelistFilter(val labelResName: String) {
    ALL("全部"),
    USER_ADDED("用户自定义"),
    PRESET("默认预设"),
    SUBSCRIPTION("规则订阅"),
    DOMAIN("域名放行"),
    URL("URL 放行"),
    COSMETIC("元素放行")
}

data class WhitelistItem(
    val id: Long,
    val pattern: String,
    val rawLine: String,
    val type: WhitelistType,
    val isPreset: Boolean,
    val groupName: String?,
    val appScope: String?,
    val appInverted: Boolean,
    val isWildcard: Boolean,
    val important: Boolean,
    val enabled: Boolean,
    val masterEnabled: Boolean = true,
    val effectiveEnabled: Boolean = enabled && masterEnabled,
    val addedAt: Long,
    val isUserRule: Boolean = true,
    val isSubscription: Boolean = false,
    val subscriptionName: String? = null
)

data class WhitelistStats(
    val totalDomains: Int = 0,
    val presetTotal: Int = 0,
    val presetEnabled: Int = 0,
    val userTotal: Int = 0,
    val userEnabled: Int = 0,
    val subscriptionTotal: Int = 0,
    val subscriptionEnabled: Int = 0,
    val urlAllowCount: Int = 0,
    val cosmeticCount: Int = 0,
    val totalActive: Int = 0
)

internal fun AllowRuleEntity.toItem(
    isPreset: Boolean,
    isUserRule: Boolean = true,
    isSubscription: Boolean = false,
    subscriptionName: String? = null,
    masterEnabled: Boolean = true
): WhitelistItem = WhitelistItem(
    id = id,
    pattern = pattern,
    rawLine = rawLine,
    type = WhitelistType.DOMAIN,
    isPreset = isPreset,
    groupName = groupName,
    appScope = appScope,
    appInverted = appInverted,
    isWildcard = isWildcard,
    important = important,
    enabled = enabled,
    masterEnabled = masterEnabled,
    effectiveEnabled = enabled && masterEnabled,
    addedAt = addedAt,
    isUserRule = isUserRule,
    isSubscription = isSubscription,
    subscriptionName = subscriptionName
)

/**
 * Pages the allow-rule domain tables for the whitelist list. The ALL/DOMAIN view
 * orders preset rules last (matching the previous in-memory comparator); the
 * other filters map to their dedicated paged queries. Kept here (rather than in
 * the ViewModel) to hold the ViewModel under the 600-line file limit.
 */
internal suspend fun AllowRuleDao.queryWhitelistDomainPage(
    filter: WhitelistFilter,
    query: String,
    limit: Int,
    offset: Int
): List<AllowRuleEntity> = when (filter) {
    WhitelistFilter.PRESET -> {
        if (query.isEmpty()) pagedBySource(DefaultWhitelistSeeder.SOURCE_PRESET, limit, offset)
        else searchPagedBySource(DefaultWhitelistSeeder.SOURCE_PRESET, "%$query%", limit, offset)
    }
    WhitelistFilter.USER_ADDED -> {
        if (query.isEmpty()) userRulesPaged(limit, offset)
        else searchUserRulesPaged("%$query%", limit, offset)
    }
    WhitelistFilter.SUBSCRIPTION -> {
        if (query.isEmpty()) subscriptionRulesPaged(limit, offset)
        else searchSubscriptionRulesPaged("%$query%", limit, offset)
    }
    else -> {
        if (query.isEmpty()) allPaged(DefaultWhitelistSeeder.SOURCE_PRESET, limit, offset)
        else searchAllPaged(DefaultWhitelistSeeder.SOURCE_PRESET, "%$query%", limit, offset)
    }
}

/** Resolves only the subscription names referenced by the given `(ruleId, source)` rows. */
internal suspend fun SubscriptionDao.lookupSubscriptionNames(
    sources: List<Pair<Long, String>>
): Map<String, String> {
    val subIds = sources.mapNotNull { (_, source) ->
        if (source.startsWith("sub_")) source.removePrefix("sub_").toLongOrNull() else null
    }.distinct()
    if (subIds.isEmpty()) return emptyMap()
    return idNameByIds(subIds).associate { "sub_${it.id}" to it.name }
}

/** Case-insensitive "contains" match across any of the given fields; true when the query is blank. */
internal fun matchesSearchQuery(query: String, vararg fields: String?): Boolean {
    if (query.isEmpty()) return true
    return fields.any { it?.lowercase()?.contains(query) == true }
}

/**
 * Assembles the URL / cosmetic allow rows shown above the paged domain rows.
 *
 * URL and cosmetic rules have no paged DAO queries, so this list is still built in
 * memory; extracting it keeps [WhitelistViewModel] under the 550-line limit.
 *
 * The SUBSCRIPTION filter keeps both kinds (unlike the blacklist, whose URL branch
 * is empty for that filter): allow-listed URL rules with a subscription source do
 * belong in that tab.
 */
internal suspend fun buildWhitelistNonDomainItems(
    filter: WhitelistFilter,
    query: String,
    dataset: RuleDataset,
    goUrlRuleDao: GoUrlRuleDao,
    cosmeticRuleDao: CosmeticRuleDao,
    subscriptionDao: SubscriptionDao,
    masterEnabled: Boolean
): List<WhitelistItem> {
    val urlItems = goUrlRuleDao.queryWhitelistUrlItems(filter, query, subscriptionDao, masterEnabled)
    val cosmeticItems = cosmeticRuleDao.queryWhitelistCosmeticItems(
        filter, query, dataset, subscriptionDao, masterEnabled
    )
    return when (filter) {
        WhitelistFilter.URL -> urlItems
        WhitelistFilter.COSMETIC -> cosmeticItems
        WhitelistFilter.SUBSCRIPTION -> cosmeticItems + urlItems
        else -> cosmeticItems + urlItems
    }
}

private suspend fun GoUrlRuleDao.queryWhitelistUrlItems(
    filter: WhitelistFilter,
    query: String,
    subscriptionDao: SubscriptionDao,
    masterEnabled: Boolean
): List<WhitelistItem> {
    val all = when (filter) {
        WhitelistFilter.ALL, WhitelistFilter.USER_ADDED, WhitelistFilter.SUBSCRIPTION, WhitelistFilter.URL ->
            byKind(GoUrlRuleKind.ALLOW)
        else -> emptyList()
    }
    if (all.isEmpty()) return emptyList()

    val sources = sourcesForRuleIds(all.map { it.id }).groupBy { it.ruleId }
    val names = subscriptionDao.lookupSubscriptionNames(sources.values.flatten().map { it.ruleId to it.source })

    return all.mapNotNull { entity ->
        val rows = sources[entity.id].orEmpty()
        val subSource = rows.firstOrNull { it.source.startsWith("sub_") }
        val isSub = subSource != null
        val isUser = rows.isEmpty() || rows.any { it.source == GoUrlRuleManager.USER_SOURCE || !it.source.startsWith("sub_") }
        if (filter == WhitelistFilter.USER_ADDED && !isUser) return@mapNotNull null
        if (filter == WhitelistFilter.SUBSCRIPTION && !isSub) return@mapNotNull null
        val subName = subSource?.let { names[it.source] }
        if (!matchesSearchQuery(query, entity.pattern, entity.rawLine, null, null, subName)) return@mapNotNull null
        entity.toItem(
            isUserRule = isUser,
            isSubscription = isSub,
            subscriptionName = subName,
            masterEnabled = masterEnabled
        )
    }
}

private suspend fun CosmeticRuleDao.queryWhitelistCosmeticItems(
    filter: WhitelistFilter,
    query: String,
    dataset: RuleDataset,
    subscriptionDao: SubscriptionDao,
    masterEnabled: Boolean
): List<WhitelistItem> {
    // Only NORMAL has a CSS compiler feeding the Go engine.
    if (dataset != RuleDataset.NORMAL) return emptyList()
    val all = when (filter) {
        WhitelistFilter.ALL, WhitelistFilter.USER_ADDED, WhitelistFilter.SUBSCRIPTION, WhitelistFilter.COSMETIC ->
            allowRules()
        else -> emptyList()
    }
    if (all.isEmpty()) return emptyList()

    val sources = sourcesForRuleIds(all.map { it.id }).groupBy { it.ruleId }
    val names = subscriptionDao.lookupSubscriptionNames(sources.values.flatten().map { it.ruleId to it.source })

    return all.mapNotNull { entity ->
        val rows = sources[entity.id].orEmpty()
        val subSource = rows.firstOrNull { it.source.startsWith("sub_") }
        val isSub = subSource != null
        val isUser = rows.isEmpty() || rows.any { it.source == "useradd" || !it.source.startsWith("sub_") }
        if (filter == WhitelistFilter.USER_ADDED && !isUser) return@mapNotNull null
        if (filter == WhitelistFilter.SUBSCRIPTION && !isSub) return@mapNotNull null
        val subName = subSource?.let { names[it.source] }
        if (!matchesSearchQuery(query, entity.rawLine, entity.domain, entity.selector, null, subName)) return@mapNotNull null
        entity.toItem(
            isUserRule = isUser,
            isSubscription = isSub,
            subscriptionName = subName,
            masterEnabled = masterEnabled
        )
    }
}

internal fun GoUrlRuleEntity.toItem(
    isUserRule: Boolean = true,
    isSubscription: Boolean = false,
    subscriptionName: String? = null,
    masterEnabled: Boolean = true
): WhitelistItem = WhitelistItem(
    id = id,
    pattern = pattern,
    rawLine = rawLine,
    type = WhitelistType.URL,
    isPreset = false,
    groupName = null,
    appScope = null,
    appInverted = false,
    isWildcard = false,
    important = false,
    enabled = enabled,
    masterEnabled = masterEnabled,
    effectiveEnabled = enabled && masterEnabled,
    addedAt = addedAt,
    isUserRule = isUserRule,
    isSubscription = isSubscription,
    subscriptionName = subscriptionName
)

internal fun CosmeticRuleEntity.toItem(
    isUserRule: Boolean = true,
    isSubscription: Boolean = false,
    subscriptionName: String? = null,
    masterEnabled: Boolean = true
): WhitelistItem = WhitelistItem(
    id = id,
    pattern = rawLine.ifBlank { if (domain.isNotEmpty()) "$domain#@#$selector" else "#@#$selector" },
    rawLine = rawLine,
    type = WhitelistType.COSMETIC,
    isPreset = false,
    groupName = null,
    appScope = domain.takeIf { it.isNotBlank() },
    appInverted = false,
    isWildcard = false,
    important = false,
    enabled = enabled,
    masterEnabled = masterEnabled,
    effectiveEnabled = enabled && masterEnabled,
    addedAt = addedAt,
    isUserRule = isUserRule,
    isSubscription = isSubscription,
    subscriptionName = subscriptionName
)
