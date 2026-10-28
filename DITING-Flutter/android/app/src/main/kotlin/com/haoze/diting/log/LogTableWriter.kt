package com.haoze.diting.log

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/// Bounded, single-threaded writer for one log table.
///
/// Engine callbacks must not touch the disk: a write that waits on `busy_timeout` stalls the DNS
/// hot path, which is why 2.1.7 opened a connection per event there. Rows are queued instead,
/// written in one transaction per batch, and kept while the database is unavailable — retried with
/// an exponential backoff rather than dropped on the first `SQLITE_BUSY`.
internal class LogTableWriter(
    context: Context,
    private val databaseName: String,
    private val table: String,
    threadName: String,
    private val maxPending: Int = MAX_PENDING_ROWS,
) {
    private val appContext = context.applicationContext
    private val lock = Any()
    private val pending = ArrayDeque<ContentValues>()

    private val executor: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, threadName).apply { isDaemon = true }
        }

    private var scheduled = false
    private var closed = false
    private var backoffMs = 0L
    private var retryAtMs = 0L

    /// Null until the first successful open; a table that never appears is a permanent no-op.
    private var tableMissing = false

    /// Cheap enough for a per-query callback: it only appends and arms a timer.
    fun submit(values: ContentValues) {
        var batchFull = false
        synchronized(lock) {
            if (closed) return
            pending.addLast(values)
            if (pending.size > maxPending) {
                // A stuck database must not grow the heap without bound: drop the oldest rows.
                pending.removeFirst()
                DbWriteHealth.onDropped(1)
            }
            batchFull = pending.size >= BATCH_SIZE
        }
        if (batchFull) schedule(0L) else schedule(FLUSH_INTERVAL_MS)
    }

    /// Final flush on the caller's thread (the engine is already stopped), then stops the timer.
    fun close() {
        synchronized(lock) {
            if (closed) return
            closed = true
        }
        executor.shutdownNow()
        val batch = takeBatch()
        if (batch != null && !write(batch)) DbWriteHealth.onDropped(batch.size)
        val left = synchronized(lock) {
            val remaining = pending.size
            pending.clear()
            remaining
        }
        DbWriteHealth.onDropped(left)
    }

    private fun schedule(delayMs: Long) {
        synchronized(lock) {
            if (closed || scheduled) return
            scheduled = true
        }
        try {
            executor.schedule({ drain() }, delayMs, TimeUnit.MILLISECONDS)
        } catch (_: RejectedExecutionException) {
            // Already shut down: close() commits the tail.
            synchronized(lock) { scheduled = false }
        }
    }

    private fun drain() {
        synchronized(lock) { scheduled = false }
        val batch = takeBatch() ?: return
        write(batch)
        if (hasPending()) {
            val wait = synchronized(lock) { maxOf(0L, retryAtMs - System.currentTimeMillis()) }
            schedule(wait)
        }
    }

    private fun takeBatch(): List<ContentValues>? = synchronized(lock) {
        if (pending.isEmpty()) return null
        val copy = ArrayList(pending)
        pending.clear()
        copy
    }

    private fun hasPending(): Boolean = synchronized(lock) { pending.isNotEmpty() }

    /// True when the rows are either written or permanently unpersistable (so no requeue).
    private fun write(batch: List<ContentValues>): Boolean {
        val open = LegacyDb.open(appContext, databaseName)
        if (open is LegacyDb.Open.Absent) {
            // No database yet on a fresh install; Dart creates the schema, so skip.
            return true
        }
        if (open is LegacyDb.Open.Unavailable) {
            requeue(batch)
            backoff()
            return false
        }
        val db = (open as LegacyDb.Open.Ready).db
        if (tableMissing) {
            DbWriteHealth.onDropped(batch.size)
            return true
        }
        if (!LegacyDb.hasTable(db, table)) {
            tableMissing = true
            DbWriteHealth.warn("LogTableWriter", "$databaseName has no $table; dropping ${batch.size} rows")
            DbWriteHealth.onDropped(batch.size)
            return true
        }
        return try {
            db.beginTransaction()
            try {
                for (values in batch) {
                    db.insertWithOnConflict(table, null, values, SQLiteDatabase.CONFLICT_IGNORE)
                }
                db.setTransactionSuccessful()
            } finally {
                runCatching { db.endTransaction() }
            }
            resetBackoff()
            true
        } catch (t: Throwable) {
            DbWriteHealth.warn("LogTableWriter", "unable to persist ${batch.size} rows into $table", t)
            requeue(batch)
            backoff()
            false
        }
    }

    /// Puts an unwritten batch back in front so the table stays chronological.
    private fun requeue(batch: List<ContentValues>) {
        synchronized(lock) {
            for (index in batch.indices.reversed()) {
                pending.addFirst(batch[index])
            }
            while (pending.size > maxPending) {
                pending.removeFirst()
                DbWriteHealth.onDropped(1)
            }
        }
    }

    private fun backoff() {
        synchronized(lock) {
            backoffMs = if (backoffMs <= 0L) MIN_BACKOFF_MS else minOf(backoffMs * 2, MAX_BACKOFF_MS)
            retryAtMs = System.currentTimeMillis() + backoffMs
        }
    }

    private fun resetBackoff() {
        synchronized(lock) {
            backoffMs = 0L
            retryAtMs = 0L
        }
    }

    private companion object {
        const val BATCH_SIZE = 20
        const val FLUSH_INTERVAL_MS = 500L
        const val MAX_PENDING_ROWS = 500
        const val MIN_BACKOFF_MS = 2_000L
        const val MAX_BACKOFF_MS = 60_000L
    }
}

/// One [LogTableWriter] per (database, table), so the engine callbacks of both data planes share
/// the same queue instead of each creating a thread that opens its own connection.
internal object LogTableWriters {
    private val writers = ConcurrentHashMap<String, LogTableWriter>()

    fun of(
        context: Context,
        databaseName: String,
        table: String,
        threadName: String,
    ): LogTableWriter = writers.getOrPut("$databaseName/$table") {
        LogTableWriter(context, databaseName, table, threadName)
    }

    /// Flushes and stops every queue; called when the data plane closes.
    fun closeAll() {
        val snapshot = writers.values.toList()
        writers.clear()
        snapshot.forEach { runCatching { it.close() } }
    }
}
