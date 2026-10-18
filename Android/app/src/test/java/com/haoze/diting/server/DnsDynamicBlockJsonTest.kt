package com.haoze.diting.server

import com.haoze.diting.core.rule.DynamicBlockResponseConfig
import com.haoze.diting.server.model.DnsDynamicBlockJson
import com.haoze.diting.server.model.DnsModeConfig
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for A-023: DNS mode stored and displayed the dynamic
 * block-response policy, but `DnsServerEngine.applyDnsConfig()` never emitted a
 * `dynamicResponse` key, so the Go engine decoded the zero value
 * (`Enabled == false`) and `dynamicBlockTracker.responseFor` returned the
 * fallback on its first line. The feature was dead.
 *
 * These tests pin the JSON shape to the Go struct tags so the key cannot be
 * dropped again. The Go side is authoritative:
 * `Android/tunnel/dns_config.go` declares
 *
 *     type dynamicBlockConfig struct {
 *         Enabled          bool `json:"enabled"`
 *         RequestThreshold int  `json:"requestThreshold"`
 *         WindowSeconds    int  `json:"windowSeconds"`
 *         NXDomainSeconds  int  `json:"nxDomainDurationSeconds"`
 *     }
 */
class DnsDynamicBlockJsonTest {

    @Test
    fun `json keys match the Go struct tags exactly`() {
        val json = DnsDynamicBlockJson.toJson(DynamicBlockResponseConfig(enabled = true))

        // Each of these strings is copied from the Go struct tags; a rename here
        // without the matching Go change would silently disable escalation again.
        assertTrue("missing `enabled`", json.has("enabled"))
        assertTrue("missing `requestThreshold`", json.has("requestThreshold"))
        assertTrue("missing `windowSeconds`", json.has("windowSeconds"))
        assertTrue("missing `nxDomainDurationSeconds`", json.has("nxDomainDurationSeconds"))

        // Guard against a plausible wrong name: Go uses `nxDomainDurationSeconds`,
        // not `nxdomainSeconds` or `nxDomainSeconds`.
        assertFalse("`nxDomainSeconds` is not a Go tag", json.has("nxDomainSeconds"))
        assertFalse("`nxdomainDurationSeconds` is the wrong casing", json.has("nxdomainDurationSeconds"))
        assertEquals(4, json.length())
    }

    @Test
    fun `enabled and parameter values are carried through`() {
        val config = DynamicBlockResponseConfig(
            enabled = true,
            requestThreshold = 7,
            windowSeconds = 90,
            nxDomainDurationSeconds = 600
        )
        val json = DnsDynamicBlockJson.toJson(config)

        assertTrue(json.getBoolean("enabled"))
        assertEquals(7, json.getInt("requestThreshold"))
        assertEquals(90, json.getInt("windowSeconds"))
        assertEquals(600, json.getInt("nxDomainDurationSeconds"))
    }

    @Test
    fun `disabled config still emits enabled false instead of omitting the key`() {
        // An explicit `enabled: false` is not functionally different from a missing
        // object (Go treats the zero value as disabled), but it keeps the snapshot
        // self-describing and lets this test fail if the key is ever dropped again.
        val json = DnsDynamicBlockJson.toJson(DynamicBlockResponseConfig(enabled = false))

        assertTrue("the object must still be present", json.has("enabled"))
        assertFalse(json.getBoolean("enabled"))
        assertTrue(json.has("requestThreshold"))
        assertTrue(json.has("windowSeconds"))
        assertTrue(json.has("nxDomainDurationSeconds"))
    }

    @Test
    fun `defaults stay inside the ranges Go clamps to`() {
        // tunnel/dns_config.go substitutes 5 / 60 / 300 when a value is < 1, so the
        // Kotlin defaults must already be >= 1 or the engine and the UI would
        // disagree about the effective policy.
        val json = DnsDynamicBlockJson.toJson(DynamicBlockResponseConfig())

        assertTrue(json.getInt("requestThreshold") >= 1)
        assertTrue(json.getInt("windowSeconds") >= 1)
        assertTrue(json.getInt("nxDomainDurationSeconds") >= 1)
    }

    @Test
    fun `the key name is dynamicResponse as Go expects`() {
        assertEquals("dynamicResponse", DnsDynamicBlockJson.KEY)
    }

    @Test
    fun `dns mode config carries the dynamic policy so it can reach the snapshot`() {
        // DnsModeConfig must expose the setting; without this field there was
        // nothing for applyDnsConfig() to serialise.
        val config = DnsModeConfig(dynamicBlockResponse = DynamicBlockResponseConfig(enabled = true))
        assertTrue(config.dynamicBlockResponse.enabled)

        // Default must be the disabled policy, matching the prefs default.
        assertFalse(DnsModeConfig().dynamicBlockResponse.enabled)
    }

    @Test
    fun `embedded object parses back the way Go would decode it`() {
        // Simulate the shape handed to applyDNSConfig: the dynamicResponse object
        // nested inside the engine config, exactly where Go's json.Unmarshal looks.
        val engineConfig = JSONObject()
            .put("mode", "single")
            .put("blockResponse", "NXDOMAIN")
            .put(DnsDynamicBlockJson.KEY, DnsDynamicBlockJson.toJson(
                DynamicBlockResponseConfig(enabled = true, requestThreshold = 3)
            ))

        val dynamic = engineConfig.getJSONObject("dynamicResponse")
        assertTrue(dynamic.getBoolean("enabled"))
        assertEquals(3, dynamic.getInt("requestThreshold"))
    }
}
