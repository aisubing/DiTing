package com.haoze.diting.express

import androidx.sqlite.db.SupportSQLiteQuery
import com.haoze.diting.data.dao.DnsCacheDao
import com.haoze.diting.data.entity.DnsCacheEntity
import com.haoze.diting.express.cache.ExpressRoomDnsCache
import com.haoze.diting.express.dns.ExpressDnsMessageUtils
import com.haoze.diting.core.cache.DnsCachePolicy
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.ConcurrentHashMap

class ExpressRoomDnsCacheTest {

    private class FakeDnsCacheDao : DnsCacheDao {
        val storage = ConcurrentHashMap<String, DnsCacheEntity>()
        var hitCount = 0

        override suspend fun get(key: String): DnsCacheEntity? = storage[key]

        override suspend fun getUnexpired(now: Long, limit: Int): List<DnsCacheEntity> =
            storage.values.filter { it.expiresAt > now }.take(limit)

        override suspend fun countUnexpired(now: Long): Int =
            storage.values.count { it.expiresAt > now }

        override suspend fun totalHitCount(): Int = hitCount

        override suspend fun insert(entity: DnsCacheEntity) {
            storage[entity.key] = entity
        }

        override suspend fun insertIfAbsent(entity: DnsCacheEntity) {
            storage.putIfAbsent(entity.key, entity)
        }

        override suspend fun updateMetadata(
            key: String,
            queryName: String,
            queryType: Int,
            queryClass: Int,
            createdAt: Long,
            expiresAt: Long,
            originalTtlSeconds: Long,
            ttlOffsets: String,
            response: ByteArray,
            responseSize: Int
        ): Int {
            val existing = storage[key] ?: return 0
            storage[key] = existing.copy(
                queryName = queryName,
                queryType = queryType,
                queryClass = queryClass,
                createdAt = createdAt,
                expiresAt = expiresAt,
                originalTtlSeconds = originalTtlSeconds,
                ttlOffsets = ttlOffsets,
                response = response,
                responseSize = responseSize
            )
            return 1
        }

        override suspend fun addHits(key: String, delta: Int, lastHitAt: Long): Int {
            val existing = storage[key] ?: return 0
            storage[key] = existing.copy(hitCount = existing.hitCount + delta, lastHitAt = lastHitAt)
            return 1
        }

        override suspend fun recordHit(key: String, now: Long) {
            hitCount++
            storage[key]?.let {
                storage[key] = it.copy(hitCount = it.hitCount + 1, lastHitAt = now)
            }
        }

        override suspend fun delete(key: String) {
            storage.remove(key)
        }

        override suspend fun deleteExpired(now: Long): Int {
            val expired = storage.values.filter { it.expiresAt <= now }.map { it.key }
            expired.forEach { storage.remove(it) }
            return expired.size
        }

        override suspend fun clearAll() {
            storage.clear()
        }

        override suspend fun queryList(query: SupportSQLiteQuery): List<DnsCacheEntity> = emptyList()

        override suspend fun count(query: SupportSQLiteQuery): Int = storage.size
    }

    @Test
    fun testCachePutAndGetHit() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val policy = DnsCachePolicy(enabled = true, minTtlSeconds = 60, maxTtlSeconds = 600)
        val cache = ExpressRoomDnsCache(fakeDao) { policy }

        val query = ExpressDnsMessageUtils.buildQuery("example.com", ExpressDnsMessageUtils.TYPE_A)
        val question = ExpressDnsMessageUtils.extractQuestion(query)!!
        val answer = ExpressDnsMessageUtils.buildZeroAddressResponse(query)

        cache.put(question, answer)
        assertEquals(1, fakeDao.storage.size)

        val cachedResponse = cache.get(question, query)
        assertNotNull(cachedResponse)
        assertEquals(ExpressDnsMessageUtils.RCODE_NOERROR, ExpressDnsMessageUtils.responseCode(cachedResponse!!))
    }

    @Test
    fun testCacheDisabledPolicy() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val disabledPolicy = DnsCachePolicy(enabled = false)
        val cache = ExpressRoomDnsCache(fakeDao) { disabledPolicy }

        val query = ExpressDnsMessageUtils.buildQuery("example.com", ExpressDnsMessageUtils.TYPE_A)
        val question = ExpressDnsMessageUtils.extractQuestion(query)!!
        val answer = ExpressDnsMessageUtils.buildZeroAddressResponse(query)

        cache.put(question, answer)
        assertEquals(0, fakeDao.storage.size)

        val cachedResponse = cache.get(question, query)
        assertNull(cachedResponse)
    }

    @Test
    fun testCacheExpiredEntity() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val policy = DnsCachePolicy(enabled = true)
        val cache = ExpressRoomDnsCache(fakeDao) { policy }

        val query = ExpressDnsMessageUtils.buildQuery("expired.com", ExpressDnsMessageUtils.TYPE_A)
        val question = ExpressDnsMessageUtils.extractQuestion(query)!!

        val expiredEntity = DnsCacheEntity(
            key = "expired.com#1#1#0#0",
            queryName = "expired.com",
            queryType = 1,
            queryClass = 1,
            createdAt = System.currentTimeMillis() - 100_000L,
            expiresAt = System.currentTimeMillis() - 50_000L,
            lastHitAt = null,
            hitCount = 0,
            originalTtlSeconds = 50,
            ttlOffsets = "",
            response = ExpressDnsMessageUtils.buildZeroAddressResponse(query),
            responseSize = 32
        )
        fakeDao.insert(expiredEntity)

        val cachedResponse = cache.get(question, query)
        assertNull(cachedResponse)
        assertNull(fakeDao.get("expired.com#1#1#0#0"))
    }

    @Test
    fun testTtlOffsetsPopulatedInEntity() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val policy = DnsCachePolicy(enabled = true)
        val cache = ExpressRoomDnsCache(fakeDao) { policy }

        val query = ExpressDnsMessageUtils.buildQuery("with-ttl.com", ExpressDnsMessageUtils.TYPE_A)
        val question = ExpressDnsMessageUtils.extractQuestion(query)!!
        val answer = ExpressDnsMessageUtils.buildZeroAddressResponse(query)

        cache.put(question, answer)
        val entity = fakeDao.get("with-ttl.com#1#1#0#0")
        assertNotNull(entity)
        assertTrue("ttlOffsets should be populated", entity!!.ttlOffsets.isNotBlank())
    }

    @Test
    fun testMemoryCacheDefensiveCopy() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val policy = DnsCachePolicy(enabled = true)
        val cache = ExpressRoomDnsCache(fakeDao) { policy }

        val query = ExpressDnsMessageUtils.buildQuery("defensive.com", ExpressDnsMessageUtils.TYPE_A)
        val question = ExpressDnsMessageUtils.extractQuestion(query)!!
        val answer = ExpressDnsMessageUtils.buildZeroAddressResponse(query)
        val originalFirstByte = answer[0]

        cache.put(question, answer)

        // Mutate original array
        answer[0] = (answer[0].toInt() xor 0xFF).toByte()

        val cached = cache.get(question, query)
        assertNotNull(cached)
        assertEquals(originalFirstByte, cached!![0])
    }

    @Test
    fun testClearMemoryCache() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val policy = DnsCachePolicy(enabled = true)
        val cache = ExpressRoomDnsCache(fakeDao) { policy }

        val query = ExpressDnsMessageUtils.buildQuery("clearmem.com", ExpressDnsMessageUtils.TYPE_A)
        val question = ExpressDnsMessageUtils.extractQuestion(query)!!
        val answer = ExpressDnsMessageUtils.buildZeroAddressResponse(query)

        cache.put(question, answer)
        cache.clearMemory()

        // Room entity remains and provides fallback
        val cached = cache.get(question, query)
        assertNotNull(cached)
        assertEquals(1, fakeDao.hitCount)
    }

    @Test
    fun testConcurrentPutAndGet() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val policy = DnsCachePolicy(enabled = true, minTtlSeconds = 60, maxTtlSeconds = 600)
        val cache = ExpressRoomDnsCache(fakeDao) { policy }

        val jobs = (1..20).map { i ->
            async(Dispatchers.IO) {
                val domain = "domain$i.com"
                val query = ExpressDnsMessageUtils.buildQuery(domain, ExpressDnsMessageUtils.TYPE_A)
                val question = ExpressDnsMessageUtils.extractQuestion(query)!!
                val answer = ExpressDnsMessageUtils.buildZeroAddressResponse(query)
                cache.put(question, answer)
                val retrieved = cache.get(question, query)
                assertNotNull(retrieved)
            }
        }
        jobs.awaitAll()
        assertEquals(20, fakeDao.storage.size)
    }

    @Test
    fun testDnssecOkAndCheckingDisabledProduceDistinctKeys() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val policy = DnsCachePolicy(enabled = true, minTtlSeconds = 60, maxTtlSeconds = 600)
        val cache = ExpressRoomDnsCache(fakeDao) { policy }

        val plainQuery = ExpressDnsMessageUtils.buildQuery("split.com", ExpressDnsMessageUtils.TYPE_A)
        val plainQuestion = ExpressDnsMessageUtils.extractQuestion(plainQuery)!!
        val doQuestion = plainQuestion.copy(dnssecOk = true)
        val cdQuestion = plainQuestion.copy(checkingDisabled = true)

        cache.put(plainQuestion, ExpressDnsMessageUtils.buildZeroAddressResponse(plainQuery))

        // A DO=1 or CD=1 client asks a different question and must not be served
        // the plain answer from the cache.
        assertNull(cache.get(doQuestion, plainQuery))
        assertNull(cache.get(cdQuestion, plainQuery))
        assertEquals(1, fakeDao.storage.size)

        cache.put(doQuestion, ExpressDnsMessageUtils.buildZeroAddressResponse(plainQuery))
        assertEquals(2, fakeDao.storage.size)
        assertNotNull(cache.get(doQuestion, plainQuery))
        assertNotNull(cache.get(plainQuestion, plainQuery))
    }

    /**
     * A-065: `put()` used `dao.insert(...)` with `OnConflictStrategy.REPLACE`
     * (ExpressRoomDnsCache.kt:126 in the report). SQLite implements REPLACE as
     * DELETE + INSERT, so refreshing the response of a key that was already there
     * dropped the accumulated `hitCount` to 0 and `lastHitAt` to null. The cache
     * screen orders entries by hit count, so a hot domain fell back to the bottom
     * of the list every time its TTL expired and the answer was re-resolved.
     */
    @Test
    fun testPutPreservesHitCountersOfExistingEntry() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val policy = DnsCachePolicy(enabled = true, minTtlSeconds = 60, maxTtlSeconds = 600)
        val cache = ExpressRoomDnsCache(fakeDao) { policy }

        val query = ExpressDnsMessageUtils.buildQuery("hot.com", ExpressDnsMessageUtils.TYPE_A)
        val question = ExpressDnsMessageUtils.extractQuestion(query)!!
        val answer = ExpressDnsMessageUtils.buildZeroAddressResponse(query)

        cache.put(question, answer)
        val key = "hot.com#1#1#0#0"

        // Two cache hits served from the DAO layer (memory cache dropped first).
        cache.clearMemory()
        assertNotNull(cache.get(question, query))
        cache.clearMemory()
        assertNotNull(cache.get(question, query))
        assertEquals(2, fakeDao.storage.getValue(key).hitCount)
        val lastHitAtBefore = fakeDao.storage.getValue(key).lastHitAt
        assertNotNull(lastHitAtBefore)

        // Re-resolve the same question while it is still cached.
        cache.put(question, answer)

        val refreshed = fakeDao.storage.getValue(key)
        assertEquals("hitCount must survive a response refresh", 2, refreshed.hitCount)
        assertEquals("lastHitAt must survive a response refresh", lastHitAtBefore, refreshed.lastHitAt)
        assertEquals(1, fakeDao.storage.size)
    }

    /** A-065: the update path must still create a row for a brand-new key. */
    @Test
    fun testPutInsertsNewEntryWhenKeyAbsent() = runBlocking {
        val fakeDao = FakeDnsCacheDao()
        val policy = DnsCachePolicy(enabled = true)
        val cache = ExpressRoomDnsCache(fakeDao) { policy }

        val query = ExpressDnsMessageUtils.buildQuery("brand-new.com", ExpressDnsMessageUtils.TYPE_A)
        val question = ExpressDnsMessageUtils.extractQuestion(query)!!

        cache.put(question, ExpressDnsMessageUtils.buildZeroAddressResponse(query))

        val entity = fakeDao.get("brand-new.com#1#1#0#0")
        assertNotNull(entity)
        assertEquals(0, entity!!.hitCount)
        assertNull(entity.lastHitAt)
    }
}
