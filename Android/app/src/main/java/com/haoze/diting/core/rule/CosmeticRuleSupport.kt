package com.haoze.diting.core.rule

import com.haoze.diting.data.RuleDataset

/**
 * Element-hiding (cosmetic) rules are only ever compiled into the scoped CSS
 * that the full-tunnel engine injects, and that engine always reads the NORMAL
 * rule database — [CosmeticRuleManager.getInstance] hardcodes `AppDatabase`,
 * and the Go side injects the stylesheet from the VPN/MITM pipeline only.
 *
 * Express runs on its own database ([com.haoze.diting.data.ExpressRulesDatabase])
 * with no CSS compiler, and DNS mode has no HTTP interception at all. Accepting
 * a cosmetic rule in either dataset therefore stored the row and reported
 * success while the rule could never take effect or even show up in the list,
 * which is why this gate must cover both non-NORMAL datasets rather than just
 * DNS mode.
 *
 * Returns the user-facing rejection message, or null when the dataset supports
 * cosmetic rules. Shared by the single-rule and the batch entry points so the
 * two paths cannot drift apart again.
 */
internal fun cosmeticRuleRejection(dataset: RuleDataset): String? = when (dataset) {
    RuleDataset.NORMAL -> null
    RuleDataset.EXPRESS, RuleDataset.DNS_MODE -> "元素隐藏规则仅普通模式支持（极速模式与服务器模式无法生效）"
}
