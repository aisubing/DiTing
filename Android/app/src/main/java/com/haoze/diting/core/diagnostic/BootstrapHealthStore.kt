package com.haoze.diting.core.diagnostic

import android.content.Context
import android.content.SharedPreferences
import com.haoze.diting.data.RuleDataset
import org.json.JSONObject

data class BootstrapHealthSnapshot(
    val ipId: String,
    val successes: Int,
    val failures: Int,
    val ewmaMs: Double,
    val lastUpdatedAt: Long,
    val jitterMs: Double = 0.0,
    val consecutiveFailures: Int = 0,
    val cooldownUntil: Long = 0L,
    val decayedSuccesses: Double = successes.toDouble(),
    val decayedFailures: Double = failures.toDouble()
) {
    val attempts: Int = successes + failures
    val successRate: Double
        get() {
            val decayedAttempts = decayedSuccesses + decayedFailures
            return if (decayedAttempts <= 0.0) 0.0 else decayedSuccesses / decayedAttempts
        }
    val predictionWeight: Double
        get() {
            val decayedAttempts = decayedSuccesses + decayedFailures
            if (decayedAttempts <= 0.0) return 1.0
            val correctness = (decayedSuccesses + 2.0) / (decayedAttempts + 3.0)
            val speed = if (successes > 0) {
                DEFAULT_LATENCY_MS / (ewmaMs + jitterMs * JITTER_WEIGHT).coerceIn(MIN_LATENCY_MS, MAX_LATENCY_MS)
            } else {
                1.0
            }
            val cooldownPenalty = if (System.currentTimeMillis() < cooldownUntil) COOLDOWN_PENALTY else 1.0
            val failurePenalty = 1.0 / (1.0 + consecutiveFailures * CONSECUTIVE_FAILURE_PENALTY)
            return (correctness * speed * cooldownPenalty * failurePenalty)
                .coerceIn(MIN_WEIGHT, MAX_WEIGHT)
        }

    companion object {
        private const val DEFAULT_LATENCY_MS = 250.0
        private const val MIN_LATENCY_MS = 20.0
        private const val MAX_LATENCY_MS = 5_000.0
        private const val MIN_WEIGHT = 0.05
        private const val MAX_WEIGHT = 3.0
        private const val JITTER_WEIGHT = 0.5
        private const val COOLDOWN_PENALTY = 0.1
        private const val CONSECUTIVE_FAILURE_PENALTY = 0.2
    }
}

/**
 * Persists Bootstrap DNS health samples.
 *
 * Entries are scoped per [RuleDataset]: the ordinary tunnel and the Express
 * engine each run their own Bootstrap DNS settings, so sharing one JSON blob
 * made whichever engine flushed last erase the other engine's samples and
 * cooldowns. Writes merge instead of replacing the whole blob so two engines
 * living in the same dataset cannot drop each other's entries either.
 */
object BootstrapHealthStore {
    private const val KEY_BOOTSTRAP_HEALTH_JSON = "bootstrap_health_json"
    private const val DEFAULT_LATENCY_MS = 250.0
    private val listeners = mutableMapOf<RuleDataset, MutableSet<BootstrapHealthStoreListener>>()

    private fun prefs(context: Context, dataset: RuleDataset): SharedPreferences =
        context.getSharedPreferences(dataset.prefsName(), Context.MODE_PRIVATE)

    @Synchronized
    fun loadAll(
        context: Context,
        dataset: RuleDataset = RuleDataset.NORMAL
    ): Map<String, BootstrapHealthSnapshot> {
        val root = HealthStoreJson.parseRoot(prefs(context, dataset).getString(KEY_BOOTSTRAP_HEALTH_JSON, null))
        val result = mutableMapOf<String, BootstrapHealthSnapshot>()
        val keys = root.keys()
        while (keys.hasNext()) {
            val ipId = keys.next()
            val obj = root.optJSONObject(ipId) ?: continue
            result[ipId] = BootstrapHealthSnapshot(
                ipId = ipId,
                successes = obj.optInt("successes", 0),
                failures = obj.optInt("failures", 0),
                ewmaMs = obj.optDouble("ewmaMs", DEFAULT_LATENCY_MS),
                lastUpdatedAt = obj.optLong("lastUpdatedAt", 0L),
                jitterMs = obj.optDouble("jitterMs", 0.0),
                consecutiveFailures = obj.optInt("consecutiveFailures", 0),
                cooldownUntil = obj.optLong("cooldownUntil", 0L),
                decayedSuccesses = obj.optDouble("decayedSuccesses", obj.optInt("successes", 0).toDouble()),
                decayedFailures = obj.optDouble("decayedFailures", obj.optInt("failures", 0).toDouble())
            )
        }
        return result
    }

    /**
     * Merges [snapshots] into the stored entries, keeping entries owned by other
     * engines of the same dataset. Deletions go through [reset]/[clearAll].
     */
    @Synchronized
    fun saveAll(
        context: Context,
        snapshots: Map<String, BootstrapHealthSnapshot>,
        dataset: RuleDataset = RuleDataset.NORMAL,
        commit: Boolean = false
    ): Boolean {
        val prefs = prefs(context, dataset)
        val root = HealthStoreJson.merge(
            prefs.getString(KEY_BOOTSTRAP_HEALTH_JSON, null),
            snapshots.mapValues { (_, snapshot) -> snapshot.toJson() }
        )
        return write(prefs, root, commit)
    }

    /**
     * Overwrites the stored entries with exactly [snapshots]. Used after a reset
     * so merged writes cannot resurrect the ids that were just removed.
     */
    @Synchronized
    fun replaceAll(
        context: Context,
        snapshots: Map<String, BootstrapHealthSnapshot>,
        dataset: RuleDataset = RuleDataset.NORMAL,
        commit: Boolean = false
    ): Boolean {
        val root = HealthStoreJson.replace(snapshots.mapValues { (_, snapshot) -> snapshot.toJson() })
        return write(prefs(context, dataset), root, commit)
    }

    fun reset(
        context: Context,
        ipIds: Set<String>,
        dataset: RuleDataset = RuleDataset.NORMAL
    ) {
        val notifyListeners = synchronized(this) {
            val prefs = prefs(context, dataset)
            val root = HealthStoreJson.remove(prefs.getString(KEY_BOOTSTRAP_HEALTH_JSON, null), ipIds)
            prefs.edit().putString(KEY_BOOTSTRAP_HEALTH_JSON, root.toString()).apply()
            listeners[dataset]?.toList().orEmpty()
        }
        notifyListeners.forEach { it.onBootstrapHealthReset(ipIds) }
    }

    fun remove(context: Context, ipId: String, dataset: RuleDataset = RuleDataset.NORMAL) {
        reset(context, setOf(ipId), dataset)
    }

    fun clearAll(context: Context, dataset: RuleDataset = RuleDataset.NORMAL) {
        val notifyListeners = synchronized(this) {
            prefs(context, dataset).edit().remove(KEY_BOOTSTRAP_HEALTH_JSON).apply()
            listeners[dataset]?.toList().orEmpty()
        }
        notifyListeners.forEach { it.onBootstrapHealthCleared() }
    }

    @Synchronized
    fun registerListener(
        listener: BootstrapHealthStoreListener,
        dataset: RuleDataset = RuleDataset.NORMAL
    ) {
        listeners.getOrPut(dataset) { mutableSetOf() }.add(listener)
    }

    @Synchronized
    fun unregisterListener(
        listener: BootstrapHealthStoreListener,
        dataset: RuleDataset = RuleDataset.NORMAL
    ) {
        listeners[dataset]?.remove(listener)
    }

    private fun write(prefs: SharedPreferences, root: JSONObject, commit: Boolean): Boolean {
        val editor = prefs.edit().putString(KEY_BOOTSTRAP_HEALTH_JSON, root.toString())
        return if (commit) editor.commit() else {
            editor.apply()
            true
        }
    }

    private fun BootstrapHealthSnapshot.toJson(): JSONObject = JSONObject().apply {
        put("successes", successes)
        put("failures", failures)
        put("ewmaMs", ewmaMs)
        put("jitterMs", jitterMs)
        put("consecutiveFailures", consecutiveFailures)
        put("cooldownUntil", cooldownUntil)
        put("decayedSuccesses", decayedSuccesses)
        put("decayedFailures", decayedFailures)
        put("lastUpdatedAt", lastUpdatedAt)
    }
}

interface BootstrapHealthStoreListener {
    fun onBootstrapHealthReset(ipIds: Set<String>)
    fun onBootstrapHealthCleared() {}
}
