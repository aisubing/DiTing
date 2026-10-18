package com.haoze.diting.core.diagnostic

import com.haoze.diting.data.RuleDataset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * A-092: the Bootstrap health engine exists three times over (ordinary tunnel,
 * Express engine, race-mode settings screen) and all of them shared one static
 * `activeEngine` slot. `flushActive()` therefore flushed whichever engine was
 * constructed last, which after A-088's dataset split is the wrong dataset
 * entirely — the caller's own pending samples stayed unwritten.
 *
 * The registry is plain Kotlin state, so it is tested here without a Context.
 */
class HealthEngineRegistryTest {

    @Test
    fun enginesOfDifferentDatasetsDoNotDisplaceEachOther() {
        val registry = ActiveHealthEngineRegistry<String>()
        registry.set(RuleDataset.NORMAL, "normal-engine")
        registry.set(RuleDataset.EXPRESS, "express-engine")

        assertEquals("normal-engine", registry.get(RuleDataset.NORMAL))
        assertEquals("express-engine", registry.get(RuleDataset.EXPRESS))
    }

    @Test
    fun aLaterEngineOfTheSameDatasetReplacesTheEarlier() {
        // Reopening the settings screen creates a new engine for the same
        // dataset; the newest one owns the pending samples.
        val registry = ActiveHealthEngineRegistry<String>()
        registry.set(RuleDataset.NORMAL, "first")
        registry.set(RuleDataset.NORMAL, "second")

        assertEquals("second", registry.get(RuleDataset.NORMAL))
        assertEquals(1, countOf(registry))
    }

    @Test
    fun closingOneDatasetLeavesTheOtherRegistered() {
        val registry = ActiveHealthEngineRegistry<String>()
        registry.set(RuleDataset.NORMAL, "normal-engine")
        registry.set(RuleDataset.EXPRESS, "express-engine")

        registry.clearIfCurrent(RuleDataset.EXPRESS, "express-engine")

        assertEquals("normal-engine", registry.get(RuleDataset.NORMAL))
        assertNull(registry.get(RuleDataset.EXPRESS))
    }

    @Test
    fun staleEngineCloseDoesNotEvictTheNewerEngine() {
        // The settings screen can be closed after a newer engine took the slot;
        // clearing blindly would leave the newer engine unreachable from
        // flushActive().
        val registry = ActiveHealthEngineRegistry<String>()
        registry.set(RuleDataset.NORMAL, "old-engine")
        registry.set(RuleDataset.NORMAL, "new-engine")

        registry.clearIfCurrent(RuleDataset.NORMAL, "old-engine")

        assertEquals("new-engine", registry.get(RuleDataset.NORMAL))
    }

    @Test
    fun unregisteredDatasetHasNoActiveEngine() {
        val registry = ActiveHealthEngineRegistry<String>()
        assertNull(registry.get(RuleDataset.NORMAL))
        assertNull(registry.get(RuleDataset.EXPRESS))
    }

    @Test
    fun everyDatasetSlotIsIndependent() {
        val registry = ActiveHealthEngineRegistry<String>()
        RuleDataset.entries.forEach { dataset ->
            registry.set(dataset, "engine-${dataset.name}")
        }
        RuleDataset.entries.forEach { dataset ->
            assertEquals("engine-${dataset.name}", registry.get(dataset))
        }
    }

    @Test
    fun identityIsPreservedForTheSameInstance() {
        // close() compares the registered engine against `this` before clearing
        // the slot, so identity (not equality) is what matters.
        val registry = ActiveHealthEngineRegistry<Any>()
        val engine = Any()
        registry.set(RuleDataset.NORMAL, engine)
        assertSame(engine, registry.get(RuleDataset.NORMAL))
    }

    @Test
    fun clearIfCurrentUsesIdentityNotEquality() {
        // Two equal-valued engines must not be confused: only the registered
        // instance may clear the slot.
        val registry = ActiveHealthEngineRegistry<Box>()
        val registered = Box(7)
        val lookalike = Box(7)
        registry.set(RuleDataset.NORMAL, registered)

        registry.clearIfCurrent(RuleDataset.NORMAL, lookalike)

        assertSame(registered, registry.get(RuleDataset.NORMAL))
    }

    private fun countOf(registry: ActiveHealthEngineRegistry<String>): Int =
        RuleDataset.entries.count { registry.get(it) != null }

    private data class Box(val value: Int)
}
