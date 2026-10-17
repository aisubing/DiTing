package com.haoze.diting.core.log

import com.haoze.diting.core.traffic.TrafficStatsManager
import com.haoze.diting.util.dayStringAt
import com.haoze.diting.data.AppDatabase
import com.haoze.diting.data.DnsRuntimeDataSources
import com.haoze.diting.data.dao.BootstrapLogDao
import com.haoze.diting.data.dao.DnsLogDao
import com.haoze.diting.data.dao.HttpRequestLogDao
import com.haoze.diting.data.dao.RaceLogDao
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Central log maintenance scheduler: periodic pruning and one-shot clearing
 * transactions for the 4 request-log types (DNS, HTTP, race, bootstrap).
 */
object LogMaintenance {
    private const val MAINTENANCE_INTERVAL_MS = 60 * 60 * 1000L // 1 hour
    private const val INITIAL_DELAY_MS = 30 * 1000L // first run 30s after service startup
    private const val DAY_MS = 24 * 60 * 60 * 1000L

    /**
     * Starts the periodic log retention pruning task in a background coroutine.
     */
    fun start(
        scope: CoroutineScope,
        database: AppDatabase,
        retentionDaysProvider: () -> Int
    ): Job {
        return scope.launch(Dispatchers.IO) {
            delay(INITIAL_DELAY_MS)
            while (isActive) {
                runCatching {
                    pruneExpiredLogs(database, retentionDaysProvider())
                }
                delay(MAINTENANCE_INTERVAL_MS)
            }
        }
    }

    /**
     * Prunes historical logs and app traffic data past the retention window.
     */
    suspend fun pruneExpiredLogs(database: AppDatabase, retentionDays: Int) {
        if (retentionDays <= 0) return
        val cutoff = System.currentTimeMillis() - retentionDays * DAY_MS
        val cutoffDate = dayStringAt(cutoff)
        withContext(Dispatchers.IO) {
            pruneLogDaos(
                dnsLogDao = database.dnsLogDao(),
                raceLogDao = database.raceLogDao(),
                bootstrapLogDao = database.bootstrapLogDao(),
                httpRequestLogDao = database.httpRequestLogDao(),
                cutoff = cutoff
            )
            runCatching { database.appTrafficDao().deleteOlderThan(cutoffDate) }
        }
    }

    /**
     * Runs the retention sweep for any log data source, including Express
     * mode's dedicated database, which has no HTTP log table.
     */
    suspend fun pruneExpiredLogs(
        dataSources: DnsRuntimeDataSources,
        httpRequestLogDao: HttpRequestLogDao?,
        retentionDays: Int
    ) {
        if (retentionDays <= 0) return
        val cutoff = System.currentTimeMillis() - retentionDays * DAY_MS
        withContext(Dispatchers.IO) {
            pruneLogDaos(
                dnsLogDao = dataSources.dnsLogDao(),
                raceLogDao = dataSources.raceLogDao(),
                bootstrapLogDao = dataSources.bootstrapLogDao(),
                httpRequestLogDao = httpRequestLogDao,
                cutoff = cutoff
            )
        }
    }

    /** Starts the periodic retention sweep for a plain log data source. */
    fun start(
        scope: CoroutineScope,
        dataSources: DnsRuntimeDataSources,
        httpRequestLogDao: HttpRequestLogDao? = null,
        retentionDaysProvider: () -> Int
    ): Job {
        return scope.launch(Dispatchers.IO) {
            delay(INITIAL_DELAY_MS)
            while (isActive) {
                runCatching {
                    pruneExpiredLogs(dataSources, httpRequestLogDao, retentionDaysProvider())
                }
                delay(MAINTENANCE_INTERVAL_MS)
            }
        }
    }

    private suspend fun pruneLogDaos(
        dnsLogDao: DnsLogDao,
        raceLogDao: RaceLogDao,
        bootstrapLogDao: BootstrapLogDao,
        httpRequestLogDao: HttpRequestLogDao?,
        cutoff: Long
    ) {
        runCatching { dnsLogDao.deleteBefore(cutoff) }
        runCatching { httpRequestLogDao?.deleteBefore(cutoff) }
        runCatching { raceLogDao.deleteBefore(cutoff) }
        runCatching { bootstrapLogDao.deleteBefore(cutoff) }
    }

    @Volatile
    var activeComponentsClearBuffers: (suspend () -> Unit)? = null

    /**
     * Clears all 4 log types in one operation.
     */
    suspend fun clearAllLogs(database: AppDatabase) {
        withContext(Dispatchers.IO) {
            runCatching { activeComponentsClearBuffers?.invoke() }
            runCatching { database.dnsLogDao().clearAll() }
            runCatching { database.httpRequestLogDao().clearAll() }
            runCatching { database.raceLogDao().clearAll() }
            runCatching { database.bootstrapLogDao().clearAll() }
        }
    }


    /**
     * Clears all app traffic history and in-memory statistics state.
     */
    suspend fun clearAllTrafficStats(database: AppDatabase) {
        withContext(Dispatchers.IO) {
            runCatching { com.haoze.diting.core.traffic.TrafficStatsManager.clearAllTrafficStats() }
            runCatching { database.appTrafficDao().clearAll() }
        }
    }
}
