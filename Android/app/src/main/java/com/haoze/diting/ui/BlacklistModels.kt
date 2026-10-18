package com.haoze.diting.ui

import com.haoze.diting.data.RuleDataset
import com.haoze.diting.data.dao.CosmeticRuleDao
import com.haoze.diting.data.dao.GoUrlRuleDao
import com.haoze.diting.data.dao.SubscriptionDao
import com.haoze.diting.data.entity.CosmeticRuleEntity
import com.haoze.diting.data.entity.GoUrlRuleEntity
import com.haoze.diting.data.entity.GoUrlRuleKind

enum class BlacklistType {
    DOMAIN,
    URL,
    COSMETIC
}

enum class BlacklistFilter(val labelResName: String) {
    ALL("全部"),
    USER_ADDED("用户自定义"),
    SUBSCRIPTION("规则订阅"),
    DOMAIN("域名屏蔽"),
    URL("URL 屏蔽"),
    COSMETIC("元素隐藏")
}

data class BlacklistItem(
    val id: Long,
    val pattern: String,
    val rawLine: String,
    val type: BlacklistType,
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

data class BlacklistStats(
    val totalDomains: Int = 0,
    val userTotal: Int = 0,
    val userEnabled: Int = 0,
    val urlBlockCount: Int = 0,
    val cosmeticCount: Int = 0,
    val totalActive: Int = 0
)

/**
 * Assembles the URL block rows shown above the paged domain rows. Kept here
 * (rather than in the ViewModel) to hold the ViewModel under the 550-line file
 * limit, matching the existing [WhitelistModels] split.
 *
 * [BlacklistFilter.SUBSCRIPTION] used to fall into the `else` branch and return
 * nothing, so URL rules carried by a subscription never appeared in the
 * "规则订阅" tab even though the whitelist had the matching branch. Subscription
 * sources are `sub_<id>`; every other source (useradd, preset, imports) counts
 * as a user rule, mirroring the cosmetic branch below.
 */
internal suspend fun GoUrlRuleDao.queryBlacklistUrlItems(
    filter: BlacklistFilter,
    query: String,
    subscriptionDao: SubscriptionDao,
    masterEnabled: Boolean
): List<BlacklistItem> {
    val all = when (filter) {
        BlacklistFilter.ALL, BlacklistFilter.USER_ADDED,
        BlacklistFilter.SUBSCRIPTION, BlacklistFilter.URL -> byKind(GoUrlRuleKind.BLOCK)
        else -> emptyList()
    }
    if (all.isEmpty()) return emptyList()

    val filtered = all.filter {
        query.isEmpty() ||
            it.pattern.contains(query, ignoreCase = true) ||
            it.rawLine.contains(query, ignoreCase = true)
    }
    val sources = sourcesForRuleIds(filtered.map { it.id })
    val sourcesByRuleId = sources.groupBy { it.ruleId }
    val names = subscriptionDao.lookupSubscriptionNames(sources.map { it.ruleId to it.source })

    return filtered.mapNotNull { entity ->
        val ruleSources = sourcesByRuleId[entity.id].orEmpty()
        val subSource = ruleSources.firstOrNull { it.source.startsWith("sub_") }
        val isSub = subSource != null
        val isUser = ruleSources.isEmpty() ||
            ruleSources.any { it.source == com.haoze.diting.core.rule.GoUrlRuleManager.USER_SOURCE || !it.source.startsWith("sub_") }
        if (filter == BlacklistFilter.USER_ADDED && !isUser) return@mapNotNull null
        if (filter == BlacklistFilter.SUBSCRIPTION && !isSub) return@mapNotNull null
        entity.toBlacklistItem(
            isUserRule = isUser,
            isSubscription = isSub,
            subscriptionName = subSource?.let { names[it.source] },
            masterEnabled = masterEnabled
        )
    }
}

/**
 * Assembles the element-hiding block rows. Only the NORMAL dataset has a CSS
 * compiler feeding the Go MITM engine, so every other dataset yields nothing.
 */
internal suspend fun CosmeticRuleDao.queryBlacklistCosmeticItems(
    filter: BlacklistFilter,
    query: String,
    dataset: RuleDataset,
    subscriptionDao: SubscriptionDao,
    masterEnabled: Boolean
): List<BlacklistItem> {
    if (dataset != RuleDataset.NORMAL) return emptyList()
    val all = when (filter) {
        BlacklistFilter.ALL, BlacklistFilter.USER_ADDED,
        BlacklistFilter.SUBSCRIPTION, BlacklistFilter.COSMETIC -> blockRules()
        else -> emptyList()
    }
    if (all.isEmpty()) return emptyList()

    val filtered = all.filter {
        query.isEmpty() ||
            it.rawLine.contains(query, ignoreCase = true) ||
            it.domain.contains(query, ignoreCase = true) ||
            it.selector.contains(query, ignoreCase = true)
    }
    val sources = sourcesForRuleIds(filtered.map { it.id })
    val sourcesByRuleId = sources.groupBy { it.ruleId }
    val names = subscriptionDao.lookupSubscriptionNames(sources.map { it.ruleId to it.source })

    return filtered.mapNotNull { entity ->
        val ruleSources = sourcesByRuleId[entity.id].orEmpty()
        val subSource = ruleSources.firstOrNull { it.source.startsWith("sub_") }
        val isSub = subSource != null
        val isUser = ruleSources.isEmpty() || ruleSources.any { it.source == "useradd" || !it.source.startsWith("sub_") }
        if (filter == BlacklistFilter.USER_ADDED && !isUser) return@mapNotNull null
        if (filter == BlacklistFilter.SUBSCRIPTION && !isSub) return@mapNotNull null
        entity.toBlacklistItem(
            isUserRule = isUser,
            isSubscription = isSub,
            subscriptionName = subSource?.let { names[it.source] },
            masterEnabled = masterEnabled
        )
    }
}

internal fun GoUrlRuleEntity.toBlacklistItem(
    isUserRule: Boolean = true,
    isSubscription: Boolean = false,
    subscriptionName: String? = null,
    masterEnabled: Boolean = true
): BlacklistItem = BlacklistItem(
    id = id,
    pattern = pattern,
    rawLine = rawLine,
    type = BlacklistType.URL,
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

internal fun CosmeticRuleEntity.toBlacklistItem(
    isUserRule: Boolean = true,
    isSubscription: Boolean = false,
    subscriptionName: String? = null,
    masterEnabled: Boolean = true
): BlacklistItem = BlacklistItem(
    id = id,
    pattern = rawLine.ifBlank { if (domain.isNotEmpty()) "$domain##$selector" else "##$selector" },
    rawLine = rawLine,
    type = BlacklistType.COSMETIC,
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
