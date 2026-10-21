package com.haoze.diting.express

import com.haoze.diting.core.rule.DynamicBlockResponseConfig
import com.haoze.diting.data.RuleDataset

/**
 * Whether dynamic block-response escalation is actually applied for a dataset.
 *
 * Dynamic escalation (answer NODATA first, then switch to NXDOMAIN once a domain
 * crosses a request threshold) is implemented in the Go data plane
 * (`tunnel/dns_config.go`'s `dynamicBlockTracker`, consumed by
 * `effectiveBlockResponseType`). NORMAL and DNS mode both run that engine and
 * both feed it a `dynamicResponse` object — NORMAL via
 * `normal/HttpsDnsConfigSnapshot.kt`, DNS mode via
 * [com.haoze.diting.server.model.DnsDynamicBlockJson] — so the setting is live in
 * both.
 *
 * Express mode is the exception: it runs the pure Kotlin `ExpressDnsEngine`,
 * which has no tracker and no escalation path at all, yet its rule-control
 * screen rendered "动态策略：先 NODATA，高频请求后 NXDOMAIN" as if active. Keeping
 * the answer in one pure function lets the UI state what actually happens
 * instead of echoing a stored flag.
 */
object ExpressDynamicBlockSupport {

    /**
     * Whether the running data plane actually applies dynamic escalation.
     *
     * Everything except Express does, because every other dataset is served by
     * the Go engine and now carries `dynamicResponse` into its config snapshot.
     */
    fun isEscalationApplied(dataset: RuleDataset): Boolean = dataset != RuleDataset.EXPRESS

    /** True when the stored config claims escalation that will not happen. */
    fun isMisleadingFor(
        dataset: RuleDataset,
        config: DynamicBlockResponseConfig
    ): Boolean = config.enabled && !isEscalationApplied(dataset)

    /**
     * Subtitle for the "拦截响应" entry. States the effective behaviour rather
     * than the stored flag, so users are not told an inactive policy is in force.
     * Returns untranslated Chinese text; callers pass it through localizedText.
     */
    fun blockResponseSubtitle(
        dataset: RuleDataset,
        config: DynamicBlockResponseConfig,
        blockResponseModeDisplayName: String
    ): String = when {
        isMisleadingFor(dataset, config) ->
            "${datasetLabel(dataset)}暂不执行动态升级，当前按固定策略返回（$blockResponseModeDisplayName）"
        config.enabled ->
            "动态策略：先 NODATA，高频请求后 NXDOMAIN"
        else ->
            "当前：$blockResponseModeDisplayName"
    }

    /** Mode name used when explaining that a stored flag is not in force. */
    internal fun datasetLabel(dataset: RuleDataset): String = when (dataset) {
        RuleDataset.EXPRESS -> "极速模式"
        RuleDataset.DNS_MODE -> "DNS 模式"
        RuleDataset.NORMAL -> "普通模式"
    }
}
