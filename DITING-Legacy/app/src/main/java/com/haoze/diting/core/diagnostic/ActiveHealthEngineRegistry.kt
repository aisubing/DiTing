package com.haoze.diting.core.diagnostic

import com.haoze.diting.data.RuleDataset

/**
 * Holds the currently live health engine of each dataset.
 *
 * Both health engines used a single static `activeEngine` slot. Once the engines
 * became per-dataset (A-088/A-092), that slot was shared between the ordinary
 * tunnel and the Express engine, so `flushActive()` flushed whichever engine was
 * constructed last — the wrong dataset entirely — while the caller's own pending
 * samples stayed unwritten. Keying the slot by dataset keeps them independent.
 *
 * Kept as a small standalone class rather than inline map juggling so the
 * behaviour is unit-testable without a Context.
 */
internal class ActiveHealthEngineRegistry<T : Any> {

    private val engines = java.util.concurrent.ConcurrentHashMap<RuleDataset, T>()

    /** Registers [engine] as the live engine of [dataset]. */
    fun set(dataset: RuleDataset, engine: T) {
        engines[dataset] = engine
    }

    /**
     * Clears [dataset] only if [engine] is still the registered one. A newer
     * engine may already have replaced it, and clearing blindly would drop the
     * newer engine's slot.
     *
     * Compared by identity rather than equality: `ConcurrentHashMap.remove(k, v)`
     * uses `equals`, and these engines carry mutable per-dataset health state, so
     * value equality is not the question being asked — "is this still me?" is.
     */
    fun clearIfCurrent(dataset: RuleDataset, engine: T) {
        engines.computeIfPresent(dataset) { _, current ->
            if (current === engine) null else current
        }
    }

    /** The live engine of [dataset], or null when none is registered. */
    fun get(dataset: RuleDataset): T? = engines[dataset]
}
