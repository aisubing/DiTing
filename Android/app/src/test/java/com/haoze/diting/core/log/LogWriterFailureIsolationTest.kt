package com.haoze.diting.core.log

import com.haoze.diting.data.dao.HttpDailyStatRow
import com.haoze.diting.data.dao.HttpRequestLogDao
import com.haoze.diting.data.dao.RaceLogDao
import com.haoze.diting.data.dao.RaceStrategyStatRow
import com.haoze.diting.data.dao.RaceWinnerStatRow
import com.haoze.diting.data.dao.SmartSelectionStatRow
import com.haoze.diting.data.dao.SubscriptionInterceptionStatRow
import com.haoze.diting.data.entity.HttpRequestLogEntity
import com.haoze.diting.data.entity.RaceLogEntity
import com.haoze.diting.ui.RaceModeStrategy
import androidx.sqlite.db.SupportSQLiteQuery
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-046: `RaceLogger.flushLocked` / `HttpRequestLogger.flushLocked` called
 * `dao.insertAll(batch)` without `runCatching`, unlike the reference
 * implementation in `DnsLogger`. A failing insert (SQLite full, disk I/O error,
 * DB closed during shutdown) therefore propagated out of the logger into the
 * DNS/HTTPS hot path and aborted the shutdown flush chain — the remaining
 * loggers were never flushed and the service could crash while stopping.
 *
 * The fixed behaviour: the exception is swallowed and the batch is restored so
 * the next flush retries it.
 */
class LogWriterFailureIsolationTest {

    private class ThrowingRaceLogDao : RaceLogDao {
        var attempts = 0
        var accepted = 0

        override suspend fun insert(entity: RaceLogEntity) {
            throw IllegalStateException("boom")
        }

        override suspend fun insertAll(entities: List<RaceLogEntity>) {
            attempts++
            throw IllegalStateException("disk I/O error")
        }

        override suspend fun deleteBefore(before: Long) {}
        override suspend fun clearAll() {}
        override suspend fun strategyStats(since: Long): List<RaceStrategyStatRow> = emptyList()
        override suspend fun winnerStats(since: Long): List<RaceWinnerStatRow> = emptyList()
        override suspend fun smartSelectionStats(since: Long, strategy: String): List<SmartSelectionStatRow> = emptyList()
    }

    private class RecordingRaceLogDao : RaceLogDao {
        val inserted = ArrayList<RaceLogEntity>()
        var failuresLeft = 0

        override suspend fun insert(entity: RaceLogEntity) {
            inserted.add(entity)
        }

        override suspend fun insertAll(entities: List<RaceLogEntity>) {
            if (failuresLeft > 0) {
                failuresLeft--
                throw IllegalStateException("transient failure")
            }
            inserted.addAll(entities)
        }

        override suspend fun deleteBefore(before: Long) {}
        override suspend fun clearAll() {
            inserted.clear()
        }

        override suspend fun strategyStats(since: Long): List<RaceStrategyStatRow> = emptyList()
        override suspend fun winnerStats(since: Long): List<RaceWinnerStatRow> = emptyList()
        override suspend fun smartSelectionStats(since: Long, strategy: String): List<SmartSelectionStatRow> = emptyList()
    }

    private class ThrowingHttpRequestLogDao : HttpRequestLogDao {
        var attempts = 0

        override suspend fun insertAll(entities: List<HttpRequestLogEntity>) {
            attempts++
            throw IllegalStateException("disk I/O error")
        }

        override suspend fun queryList(query: SupportSQLiteQuery): List<HttpRequestLogEntity> = emptyList()
        override suspend fun recent(limit: Int): List<HttpRequestLogEntity> = emptyList()
        override suspend fun dailyStats(since: Long): List<HttpDailyStatRow> = emptyList()
        override suspend fun countSince(since: Long): Int = 0
        override suspend fun subscriptionInterceptionStats(
            since: Long,
            blockedOutcome: String
        ): List<SubscriptionInterceptionStatRow> = emptyList()

        override suspend fun deleteBefore(before: Long) {}
        override suspend fun clearAll() {}
    }

    private suspend fun RaceLogger.logOne(name: String) = log(
        queryName = name,
        queryType = 1,
        strategy = RaceModeStrategy.BRUTE_FORCE_PARALLEL,
        providerCount = 2,
        success = true,
        elapsedMs = 10L,
        // Disambiguates the two log() overloads.
        selectedProviderId = null
    )

    @Test
    fun raceLoggerFlushDoesNotThrowWhenInsertFails() = runBlocking {
        val dao = ThrowingRaceLogDao()
        val logger = RaceLogger(dao)

        logger.logOne("a.example.com")
        // Must not throw: this runs on the DNS hot path.
        logger.flush()

        assertEquals("the failing batch must be retried once per flush", 1, dao.attempts)
    }

    @Test
    fun raceLoggerKeepsBatchForRetryAfterFailure() = runBlocking {
        val dao = RecordingRaceLogDao()
        val logger = RaceLogger(dao)

        logger.logOne("retry.example.com")
        dao.failuresLeft = 1
        logger.flush()
        assertTrue("first flush failed, nothing stored", dao.inserted.isEmpty())

        logger.flush()
        assertEquals("restored batch must be written by the next flush", 1, dao.inserted.size)
        assertEquals("retry.example.com", dao.inserted[0].queryName)
    }

    @Test
    fun raceLoggerBatchThresholdFailureDoesNotEscapeLog() = runBlocking {
        val dao = ThrowingRaceLogDao()
        val logger = RaceLogger(dao)

        // BATCH_SIZE is 20: the 20th record triggers the batch flush.
        repeat(20) { index ->
            logger.logOne("bulk$index.example.com")
        }

        assertEquals("the threshold flush must have been attempted", 1, dao.attempts)
    }

    @Test
    fun httpRequestLoggerFlushDoesNotThrowWhenInsertFails() = runBlocking {
        val dao = ThrowingHttpRequestLogDao()
        val logger = HttpRequestLogger(dao)

        logger.log(
            packageName = "com.example.app",
            authority = "api.example.com",
            protocol = "https",
            outcome = HttpRequestOutcome.ALLOWED
        )
        // Must not throw: this runs on the HTTPS hot path / shutdown chain.
        logger.flush()

        assertEquals(1, dao.attempts)
    }

    @Test
    fun httpRequestLoggerBatchThresholdFailureDoesNotEscapeLog() = runBlocking {
        val dao = ThrowingHttpRequestLogDao()
        val logger = HttpRequestLogger(dao)

        // BATCH_SIZE is 10.
        repeat(10) {
            logger.log(
                packageName = "com.example.app",
                authority = "api.example.com",
                protocol = "https",
                outcome = HttpRequestOutcome.BLOCKED
            )
        }

        assertEquals(1, dao.attempts)
    }
}
