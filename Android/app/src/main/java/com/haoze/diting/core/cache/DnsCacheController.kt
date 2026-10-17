package com.haoze.diting.core.cache

import com.haoze.diting.data.dao.DnsCacheDao
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

object DnsCacheController {
    private val mutex = Mutex()
    private var activeCache: DnsResponseCache? = null
    private var onClearGoCache: (() -> Unit)? = null

    suspend fun register(cache: DnsResponseCache, clearGoCacheCallback: (() -> Unit)? = null) {
        mutex.withLock {
            activeCache = cache
            onClearGoCache = clearGoCacheCallback
        }
    }

    suspend fun unregister(cache: DnsResponseCache) {
        mutex.withLock {
            if (activeCache === cache) {
                activeCache = null
                onClearGoCache = null
            }
        }
    }

    /**
     * Clears the in-memory cache, the pending flush queue and the database.
     *
     * It must go through [DnsResponseCache.clear]: clearing only memory left the
     * queued writes alive, so the 30s trailing flush re-inserted every entry
     * that had not been flushed yet after the user asked to delete the cache.
     */
    suspend fun clearAll(dao: DnsCacheDao) {
        val (cache, clearGo) = mutex.withLock { activeCache to onClearGoCache }
        if (cache != null) {
            cache.clear()
        } else {
            // Cache not registered for this data set (e.g. Express, which clears
            // its own tables): still wipe whatever is persisted.
            dao.clearAll()
        }
        clearGo?.invoke()
    }
}
