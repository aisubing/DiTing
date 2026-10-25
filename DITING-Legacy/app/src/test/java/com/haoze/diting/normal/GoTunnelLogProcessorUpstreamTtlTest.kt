package com.haoze.diting.normal

import com.haoze.diting.core.cache.DnsResponseCache
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * O-107: the batch log payload now carries the upstream TTL, and the Kotlin side
 * has to keep two very different cases apart:
 *
 * - a *missing* `ttl` key means "no TTL information"
 *   ([DnsResponseCache.TTL_UNKNOWN]), which keeps the legacy policy-maximum
 *   fallback;
 * - a *present* `0` means the upstream answer expires immediately and must never
 *   be written into the cache statistics table.
 *
 * The old `optLong("ttl", 0L)` collapsed both, so real TTL=0 answers showed up as
 * permanent rows in the cache statistics screen.
 */
class GoTunnelLogProcessorUpstreamTtlTest {

    @Test
    fun missingTtlKeyIsUnknown() {
        val obj = JSONObject("""{"d":"a.com","t":1,"i":"1.2.3.4"}""")

        assertEquals(DnsResponseCache.TTL_UNKNOWN, upstreamTtlFrom(obj))
    }

    @Test
    fun explicitZeroTtlIsPreserved() {
        val obj = JSONObject("""{"d":"a.com","t":1,"i":"1.2.3.4","ttl":0}""")

        assertEquals(0L, upstreamTtlFrom(obj))
    }

    @Test
    fun positiveTtlIsReadBack() {
        val obj = JSONObject("""{"d":"a.com","t":1,"i":"1.2.3.4","ttl":120}""")

        assertEquals(120L, upstreamTtlFrom(obj))
    }

    @Test
    fun negativeTtlIsForwardedAndDroppedByTheCache() {
        // The Go side only emits >= 0, but a malformed payload must not be turned
        // into a usable TTL: recordResolved's `else -> return` branch drops it.
        val obj = JSONObject("""{"d":"a.com","t":1,"ttl":-5}""")

        assertEquals(-5L, upstreamTtlFrom(obj))
    }

    @Test
    fun goPayloadAlwaysCarriesTheTtlKey() {
        // The aggregator used to tag the field `json:"ttl,omitempty"`, which
        // deleted the key for every zero TTL — exactly the case Kotlin needs to
        // see. Pinned at the source level (the Go toolchain is not run here).
        val candidates = listOf(
            // The engine moved to DITING-Flutter/tunnel; earlier entries cover
            // historical checkouts before that migration.
            File("../../DITING-Flutter/tunnel/log_aggregator.go"),
            File("../tunnel/log_aggregator.go"),
            File("DITING-Legacy/tunnel/log_aggregator.go"),
            File("../../tunnel/log_aggregator.go")
        )
        val file = candidates.firstOrNull { it.exists() } ?: return
        val tagLine = file.readLines()
            .firstOrNull { it.contains("int64") && it.contains("json:\"ttl") }
            .orEmpty()

        assertTrue("logItem must still declare the TTL field: $tagLine", tagLine.isNotEmpty())
        assertTrue(
            "logItem.TTL must be emitted even when it is 0 (O-107): $tagLine",
            tagLine.contains("json:\"ttl\"")
        )
        assertFalse("omitempty deleted the zero-TTL key: $tagLine", tagLine.contains("omitempty"))
    }
}
