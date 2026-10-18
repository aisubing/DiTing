package com.haoze.diting.core.diagnostic

import org.json.JSONObject

/**
 * Pure JSON plumbing shared by [BootstrapHealthStore] and [ProviderHealthStore].
 *
 * Both stores keep all of their samples in a single preferences key. They used
 * to rebuild a fresh [JSONObject] from the map they were handed and overwrite
 * the key, so whichever engine flushed last erased every entry it did not know
 * about (another engine's samples, cooldowns and decayed counters). Saving now
 * merges into the stored object instead; [replace] exists only for the reset
 * path, where the removed ids must not come back.
 */
internal object HealthStoreJson {

    /** Parses [json] into an object, returning an empty one for blank/corrupt input. */
    fun parseRoot(json: String?): JSONObject {
        if (json.isNullOrBlank()) return JSONObject()
        return try {
            JSONObject(json)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    /**
     * Returns [existingJson] with [updates] applied, preserving every key that is
     * not in [updates].
     */
    fun merge(existingJson: String?, updates: Map<String, JSONObject>): JSONObject {
        val root = parseRoot(existingJson)
        updates.forEach { (key, value) -> root.put(key, value) }
        return root
    }

    /** Returns [existingJson] without [keys]. */
    fun remove(existingJson: String?, keys: Set<String>): JSONObject {
        val root = parseRoot(existingJson)
        keys.forEach { root.remove(it) }
        return root
    }

    /** Returns an object containing exactly [entries]. */
    fun replace(entries: Map<String, JSONObject>): JSONObject {
        val root = JSONObject()
        entries.forEach { (key, value) -> root.put(key, value) }
        return root
    }
}
