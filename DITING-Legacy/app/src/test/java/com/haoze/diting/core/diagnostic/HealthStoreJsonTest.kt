package com.haoze.diting.core.diagnostic

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-092: both health stores keep every sample in one preferences key. Saving used
 * to rebuild a fresh JSONObject from the caller's map and overwrite the key, so
 * whichever engine flushed last erased the entries it did not know about — the
 * Express engine and the ordinary tunnel run separate engines over the same
 * dataset, and even a single dataset has more than one producer.
 *
 * The merge/remove/replace rules are pure JSON work, so they are tested here
 * without a Context (the unit-test classpath has no Robolectric).
 */
class HealthStoreJsonTest {

    @Test
    fun mergeKeepsKeysMissingFromUpdates() {
        val existing = """{"a":{"successes":1},"b":{"successes":2}}"""
        val merged = HealthStoreJson.merge(existing, mapOf("a" to JSONObject().put("successes", 9)))

        assertEquals(9, merged.getJSONObject("a").getInt("successes"))
        // "b" was not in the update map and must survive.
        assertEquals(2, merged.getJSONObject("b").getInt("successes"))
        assertEquals(2, merged.length())
    }

    @Test
    fun mergeAddsNewKeysAndReturnsFullSet() {
        val existing = """{"a":{"successes":1}}"""
        val merged = HealthStoreJson.merge(
            existing,
            mapOf("b" to JSONObject().put("successes", 5), "c" to JSONObject().put("successes", 6))
        )

        assertEquals(3, merged.length())
        assertEquals(1, merged.getJSONObject("a").getInt("successes"))
        assertEquals(5, merged.getJSONObject("b").getInt("successes"))
        assertEquals(6, merged.getJSONObject("c").getInt("successes"))
    }

    @Test
    fun mergeOverwritesOnlyTheUpdatedEntry() {
        val existing = """{"a":{"ewmaMs":100.0},"b":{"ewmaMs":200.0}}"""
        val merged = HealthStoreJson.merge(existing, mapOf("b" to JSONObject().put("ewmaMs", 350.0)))

        assertEquals(100.0, merged.getJSONObject("a").getDouble("ewmaMs"), 0.0001)
        assertEquals(350.0, merged.getJSONObject("b").getDouble("ewmaMs"), 0.0001)
    }

    @Test
    fun mergeOnBlankOrCorruptInputStartsFresh() {
        val fromNull = HealthStoreJson.merge(null, mapOf("a" to JSONObject().put("x", 1)))
        assertEquals(1, fromNull.length())

        val fromBlank = HealthStoreJson.merge("   ", mapOf("a" to JSONObject().put("x", 1)))
        assertEquals(1, fromBlank.length())

        val fromCorrupt = HealthStoreJson.merge("not json at all", mapOf("a" to JSONObject().put("x", 1)))
        assertEquals(1, fromCorrupt.length())
        assertEquals(1, fromCorrupt.getJSONObject("a").getInt("x"))
    }

    @Test
    fun removeDropsOnlyTheRequestedKeys() {
        val existing = """{"a":{},"b":{},"c":{}}"""
        val removed = HealthStoreJson.remove(existing, setOf("b"))

        assertEquals(2, removed.length())
        assertTrue(removed.has("a"))
        assertTrue(removed.has("c"))
        assertEquals(false, removed.has("b"))
    }

    @Test
    fun removeMissingKeyIsHarmless() {
        val existing = """{"a":{}}"""
        val removed = HealthStoreJson.remove(existing, setOf("zzz"))
        assertEquals(1, removed.length())
        assertTrue(removed.has("a"))
    }

    @Test
    fun replaceProducesExactlyTheGivenEntries() {
        // Reset path: a merge would resurrect ids that were just removed, so the
        // reset path must write exactly the surviving entries.
        val replaced = HealthStoreJson.replace(
            mapOf("a" to JSONObject().put("successes", 1), "c" to JSONObject().put("successes", 3))
        )

        assertEquals(2, replaced.length())
        assertTrue(replaced.has("a"))
        assertTrue(replaced.has("c"))
        assertEquals(false, replaced.has("b"))
    }

    @Test
    fun parseRootToleratesCorruptAndBlankValues() {
        assertEquals(0, HealthStoreJson.parseRoot(null).length())
        assertEquals(0, HealthStoreJson.parseRoot("").length())
        assertEquals(0, HealthStoreJson.parseRoot("   ").length())
        assertEquals(0, HealthStoreJson.parseRoot("{broken").length())
        assertEquals(1, HealthStoreJson.parseRoot("""{"a":{}}""").length())
    }

    @Test
    fun parseRootRejectsNonObjectRoot() {
        // A JSON array or scalar is not a valid store root; treating it as empty
        // keeps a corrupt write from breaking every later read.
        assertEquals(0, HealthStoreJson.parseRoot("[1,2,3]").length())
        assertEquals(0, HealthStoreJson.parseRoot("42").length())
    }

    @Test
    fun mergeSurvivesRoundTripThroughString() {
        val existing = """{"a":{"successes":1}}"""
        val merged = HealthStoreJson.merge(existing, mapOf("b" to JSONObject().put("successes", 2)))
        val reparsed = HealthStoreJson.parseRoot(merged.toString())

        assertEquals(2, reparsed.length())
        assertEquals(1, reparsed.getJSONObject("a").getInt("successes"))
        assertEquals(2, reparsed.getJSONObject("b").getInt("successes"))
        assertNull(reparsed.optString("missing", null))
    }
}
