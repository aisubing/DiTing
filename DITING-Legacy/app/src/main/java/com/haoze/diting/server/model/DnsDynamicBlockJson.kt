package com.haoze.diting.server.model

import com.haoze.diting.core.rule.DynamicBlockResponseConfig
import org.json.JSONObject

/**
 * Builds the `dynamicResponse` object of the DNS mode config snapshot.
 *
 * DNS mode runs the Go standalone server, whose `dnsEngineConfig.DynamicResponse`
 * (`tunnel/dns_config.go`) is populated only from the JSON handed to
 * `applyDNSConfig`. `DnsServerEngine.applyDnsConfig()` never emitted this key, so
 * Go decoded the zero value (`Enabled == false`) and
 * `dynamicBlockTracker.responseFor` returned the fallback on its first line —
 * the user's dynamic-block settings were stored and displayed but could never
 * take effect.
 *
 * The key names below mirror the Go struct tags exactly and must not drift:
 * `dynamicBlockConfig` in `tunnel/dns_config.go:25-30` declares
 * `enabled`, `requestThreshold`, `windowSeconds`, `nxDomainDurationSeconds`.
 * Pure Kotlin (only org.json) so unit tests can assert the emitted shape.
 */
object DnsDynamicBlockJson {

    const val KEY = "dynamicResponse"
    const val ENABLED = "enabled"
    const val REQUEST_THRESHOLD = "requestThreshold"
    const val WINDOW_SECONDS = "windowSeconds"
    const val NXDOMAIN_DURATION_SECONDS = "nxDomainDurationSeconds"

    /**
     * The `dynamicResponse` value for [config]. Always emits every field,
     * including `enabled: false` when the feature is off: Go treats the zero
     * value as disabled anyway, but an explicit object keeps the snapshot
     * self-describing and lets a test distinguish "feature off" from
     * "key forgotten again".
     */
    fun toJson(config: DynamicBlockResponseConfig): JSONObject = JSONObject()
        .put(ENABLED, config.enabled)
        .put(REQUEST_THRESHOLD, config.requestThreshold)
        .put(WINDOW_SECONDS, config.windowSeconds)
        .put(NXDOMAIN_DURATION_SECONDS, config.nxDomainDurationSeconds)
}
