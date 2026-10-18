package com.haoze.diting.core.diagnostic

import android.content.Context
import com.haoze.diting.data.RuleDataset
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.pow

class ProviderHealthEngine(
    private val context: Context,
    private val scope: CoroutineScope,
    private val dataset: RuleDataset = RuleDataset.NORMAL
) : ProviderHealthStoreListener {
    private val healthByProvider = ProviderHealthStore.loadAll(context, dataset).toMutableMap()
    private var dirty = false
    private var closed = false
    private var scheduledFlushJob: Job? = null

    init {
        activeEngines.set(dataset, this)
        ProviderHealthStore.registerListener(this, dataset)
    }

    @Synchronized
    fun loadAll(): Map<String, ProviderHealthSnapshot> {
        val now = System.currentTimeMillis()
        return healthByProvider.mapValues { (_, snapshot) -> snapshot.decayed(now) }
    }

    @Synchronized
    fun recordResult(providerId: String, success: Boolean, elapsedMs: Long) {
        if (closed) return
        val now = System.currentTimeMillis()
        val current = healthByProvider[providerId]?.decayed(now)
            ?: ProviderHealthSnapshot(
                providerId = providerId,
                successes = 0,
                failures = 0,
                ewmaMs = DEFAULT_LATENCY_MS,
                lastUpdatedAt = now,
                decayedSuccesses = 0.0,
                decayedFailures = 0.0
            )

        val bootstrapSample = HealthSnapshotMath.applySample(
            current = current.toBootstrapShape(),
            success = success,
            elapsedMs = elapsedMs,
            now = now
        )
        healthByProvider[providerId] = current.copy(
            successes = bootstrapSample.successes,
            failures = bootstrapSample.failures,
            ewmaMs = bootstrapSample.ewmaMs,
            jitterMs = bootstrapSample.jitterMs,
            consecutiveFailures = bootstrapSample.consecutiveFailures,
            cooldownUntil = bootstrapSample.cooldownUntil,
            decayedSuccesses = bootstrapSample.decayedSuccesses,
            decayedFailures = bootstrapSample.decayedFailures,
            lastUpdatedAt = bootstrapSample.lastUpdatedAt
        )
        markDirty()
    }

    /** Views the provider snapshot through the shared sample-update rules. */
    private fun ProviderHealthSnapshot.toBootstrapShape(): BootstrapHealthSnapshot =
        BootstrapHealthSnapshot(
            ipId = providerId,
            successes = successes,
            failures = failures,
            ewmaMs = ewmaMs,
            lastUpdatedAt = lastUpdatedAt,
            jitterMs = jitterMs,
            consecutiveFailures = consecutiveFailures,
            cooldownUntil = cooldownUntil,
            decayedSuccesses = decayedSuccesses,
            decayedFailures = decayedFailures
        )

    @Synchronized
    fun flush(commit: Boolean = false) {
        if (!dirty && !commit) return
        cancelScheduledFlush()
        ProviderHealthStore.saveAll(context, loadAll(), dataset, commit = commit)
        dirty = false
    }

    fun close() {
        val shouldClose = synchronized(this) {
            if (closed) {
                false
            } else {
                closed = true
                true
            }
        }
        if (!shouldClose) return
        synchronized(this) {
            cancelScheduledFlush()
        }
        ProviderHealthStore.unregisterListener(this, dataset)
        activeEngines.clearIfCurrent(dataset, this)
        flush(commit = true)
    }

    @Synchronized
    override fun onProviderHealthReset(providerIds: Set<String>) {
        providerIds.forEach { healthByProvider.remove(it) }
        // Replace, not merge: a merge would re-add the ids that were just removed.
        cancelScheduledFlush()
        ProviderHealthStore.replaceAll(context, loadAll(), dataset, commit = true)
        dirty = false
    }

    @Synchronized
    override fun onProviderHealthCleared() {
        cancelScheduledFlush()
        healthByProvider.clear()
        dirty = false
    }

    private fun markDirty() {
        dirty = true
        if (scheduledFlushJob?.isActive == true) return
        scheduledFlushJob = scope.launch {
            delay(FLUSH_DELAY_MS)
            flush()
        }
    }

    private fun cancelScheduledFlush() {
        scheduledFlushJob?.cancel()
        scheduledFlushJob = null
    }

    private fun ProviderHealthSnapshot.decayed(now: Long): ProviderHealthSnapshot {
        val elapsed = max(0L, now - lastUpdatedAt)
        if (elapsed == 0L) return this
        val factor = 0.5.pow(elapsed.toDouble() / HEALTH_HALF_LIFE_MS)
        return copy(
            decayedSuccesses = decayedSuccesses * factor,
            decayedFailures = decayedFailures * factor,
            decayedHedgeMisses = decayedHedgeMisses * factor,
            lastUpdatedAt = now
        )
    }

    companion object {
        // One engine per dataset: the ordinary tunnel and the Express engine run
        // their own provider lists, so a single shared slot made flushActive()
        // flush whichever engine was created last — the wrong dataset's samples,
        // while the caller's own engine stayed unflushed.
        private val activeEngines = ActiveHealthEngineRegistry<ProviderHealthEngine>()

        fun flushActive(commit: Boolean = true, dataset: RuleDataset = RuleDataset.NORMAL): Boolean {
            val engine = activeEngines.get(dataset) ?: return false
            engine.flush(commit = commit)
            return true
        }

        private const val FLUSH_DELAY_MS = 15_000L
        private const val HEALTH_HALF_LIFE_MS = 30 * 60 * 1000.0
        private const val DEFAULT_LATENCY_MS = 250.0
        private const val EWMA_ALPHA = 0.25
        private const val JITTER_ALPHA = 0.2
        private const val COOLDOWN_FAILURE_THRESHOLD = 3
        private const val COOLDOWN_MS = 30_000L
    }
}
