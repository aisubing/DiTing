package com.haoze.diting.ui.batch

import com.haoze.diting.core.rule.cosmeticRuleRejection
import com.haoze.diting.data.RuleDataset
import com.haoze.diting.data.entity.AllowRuleEntity
import com.haoze.diting.data.entity.BlockRuleEntity
import com.haoze.diting.data.entity.CosmeticRuleEntity
import com.haoze.diting.data.entity.GoUrlRuleEntity
import com.haoze.diting.data.entity.GoUrlRuleKind
import com.haoze.diting.data.entity.RewriteRuleEntity

/**
 * Pure item-to-entity mappers for [BatchRuleValidator.commitDetailed].
 *
 * Extracted so the "does the classified item actually reach the row" step can be
 * unit-tested without a `Context`: `commitDetailed` itself needs one, which is
 * why the lost `~app=` modifier could hide here unnoticed.
 */

/** Blocklist domain row. [BatchRuleItem.ValidDomain.appInverted] must survive. */
internal fun BatchRuleItem.ValidDomain.toBlockEntity(now: Long): BlockRuleEntity = BlockRuleEntity(
    pattern = pattern,
    rawLine = rawLine,
    addedAt = now,
    enabled = true,
    groupName = null,
    appScope = appScope,
    appInverted = appInverted,
    isWildcard = isWildcard,
    denyallow = denyallow,
    isRegex = isRegex,
    dnsType = dnsType,
    important = important
)

/** Allowlist domain row. */
internal fun BatchRuleItem.ValidDomain.toAllowEntity(now: Long): AllowRuleEntity = AllowRuleEntity(
    pattern = pattern,
    rawLine = rawLine,
    addedAt = now,
    enabled = true,
    groupName = null,
    appScope = appScope,
    appInverted = appInverted,
    isWildcard = isWildcard,
    denyallow = denyallow,
    isRegex = isRegex,
    dnsType = dnsType,
    important = important
)

/** URL row. [urlPattern] is already normalized by `GoUrlRuleManager.parse`. */
internal fun BatchRuleItem.ValidUrl.toGoUrlEntity(now: Long): GoUrlRuleEntity = GoUrlRuleEntity(
    pattern = urlPattern,
    kind = if (isAllow) GoUrlRuleKind.ALLOW else GoUrlRuleKind.BLOCK,
    rawLine = rawLine,
    addedAt = now,
    enabled = true
)

internal fun BatchRuleItem.ValidCosmetic.toCosmeticEntity(now: Long): CosmeticRuleEntity = CosmeticRuleEntity(
    domain = domain,
    selector = selector,
    rawLine = rawLine,
    addedAt = now,
    enabled = true,
    isException = isException
)

internal fun BatchRuleItem.ValidRewrite.toRewriteEntity(now: Long): RewriteRuleEntity = RewriteRuleEntity(
    pattern = domain,
    targetType = targetType,
    targetValue = targetValue,
    rawLine = rawLine,
    addedAt = now,
    enabled = true
)

/**
 * Element-hiding rules may only be committed on the NORMAL dataset: the CSS
 * compiler in [com.haoze.diting.core.rule.CosmeticRuleManager] is bound to the
 * NORMAL database and only the NORMAL tunnel consumes its stylesheet, so a row
 * written for another dataset would never take effect.
 *
 * [BatchRuleValidator.validate] already rejects such lines; this is the guard for
 * direct [BatchRuleValidator.commitDetailed] callers.
 */
internal fun committableCosmeticItems(
    items: List<BatchRuleItem>,
    dataset: RuleDataset
): List<BatchRuleItem.ValidCosmetic> =
    if (cosmeticRuleRejection(dataset) != null) {
        emptyList()
    } else {
        items.filterIsInstance<BatchRuleItem.ValidCosmetic>()
    }
