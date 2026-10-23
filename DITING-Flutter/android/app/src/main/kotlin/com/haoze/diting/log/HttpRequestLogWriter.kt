package com.haoze.diting.log

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/// Persists the engine's MITM request events into `http_request_log`.
///
/// The callback runs on the TLS relay path, so rows are batched (10 rows or
/// 500ms) instead of written synchronously with a WAL fsync per request.
/// `outcome` is stored verbatim because the Dart reader groups by these strings.
class HttpRequestLogWriter(
    private val context: Context,
    private val databaseName: String,
    private val modeProvider: () -> String,
) {
    private val executor: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "diting-http-log").apply { isDaemon = true }
        }
    private val lock = Any()
    private val pending = ArrayList<Row>(BATCH_SIZE)

    /// Guards against queueing a second timer while one flush is pending.
    private val flushScheduled = AtomicBoolean(false)

    @Volatile
    private var closed = false

    /// The DNS log mode also governs HTTP rows, so "off" and
    /// "blocked_and_errors" keep their meaning here.
    fun onEvent(
        packageName: String,
        authority: String,
        protocol: String,
        outcome: String,
        matchedRule: String,
    ) {
        if (closed) return
        val mode = modeProvider()
        if (mode == DnsLogWriter.MODE_OFF) return
        if (mode == DnsLogWriter.MODE_BLOCKED_AND_ERRORS && outcome in PASS_THROUGH_OUTCOMES) return

        var full = false
        synchronized(lock) {
            pending += Row(
                timestamp = System.currentTimeMillis(),
                packageName = packageName.ifBlank { "unknown" },
                authority = authority.ifBlank { null },
                protocol = protocol.ifBlank { "" },
                outcome = outcome.ifBlank { "error" },
                matchedRule = matchedRule.ifBlank { null },
            )
            full = pending.size >= BATCH_SIZE
        }
        if (full) submitFlush() else scheduleDelayedFlush()
    }

    /// Writes the tail and stops the executor; called from every stop path.
    /// `closed` gates only the entry points, never writeBatch: the final flush
    /// runs after it is set and must not be skipped.
    fun close() {
        if (closed) return
        closed = true
        runCatching {
            // Explicit Runnable: `submit { }` is ambiguous between the Runnable
            // and Callable overloads here.
            executor.submit(Runnable { writeBatch() }).get(CLOSE_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        }.onFailure { Log.w(TAG, "Final HTTP log flush did not complete", it) }
        executor.shutdown()
        runCatching { executor.awaitTermination(CLOSE_TIMEOUT_MS, TimeUnit.MILLISECONDS) }
    }

    /// Hands the buffer to the writer thread as soon as it is full.
    private fun submitFlush() {
        if (closed) return
        try {
            executor.execute { writeBatch() }
        } catch (_: RejectedExecutionException) {
            // Already shut down; close() commits the tail.
        }
    }

    /// Arms one 500ms timer for the first row of a burst and reuses it for the
    /// rest, so a trickle of ten events is one write instead of ten.
    private fun scheduleDelayedFlush() {
        if (closed || !flushScheduled.compareAndSet(false, true)) return
        try {
            executor.schedule(
                {
                    flushScheduled.set(false)
                    writeBatch()
                },
                FLUSH_INTERVAL_MS,
                TimeUnit.MILLISECONDS,
            )
        } catch (_: RejectedExecutionException) {
            flushScheduled.set(false)
        }
    }

    private fun writeBatch() {
        // Returned from the block instead of assigned to a captured `val`: the
        // assignment form depends on synchronized's callsInPlace contract.
        val batch = synchronized(lock) {
            if (pending.isEmpty()) return
            val copy = ArrayList(pending)
            pending.clear()
            copy
        }

        val db = LegacyDb.open(context, databaseName) ?: run {
            // No database yet (fresh install) or it never had this table; retrying
            // cannot help and would grow the buffer, so drop the batch.
            Log.w(TAG, "$databaseName not openable; dropping ${batch.size} HTTP rows")
            return
        }
        try {
            // Guard anyway: an INSERT into a missing table would throw per batch.
            if (!LegacyDb.hasTable(db, TABLE)) {
                Log.w(TAG, "$databaseName has no $TABLE; dropping ${batch.size} HTTP rows")
                return
            }
            db.beginTransaction()
            try {
                for (row in batch) {
                    db.insertWithOnConflict(TABLE, null, row.toValues(), SQLiteDatabase.CONFLICT_IGNORE)
                }
                db.setTransactionSuccessful()
            } catch (t: Throwable) {
                Log.w(TAG, "Unable to persist HTTP log batch", t)
                requeue(batch)
            } finally {
                runCatching { db.endTransaction() }
            }
        } finally {
            runCatching { db.close() }
        }
    }

    /// Keeps a failed batch for the next attempt instead of dropping it.
    private fun requeue(batch: List<Row>) {
        synchronized(lock) {
            if (closed) return
            // Prepend so the buffer stays chronological.
            pending.addAll(0, batch)
            // A permanently failing write must not grow the buffer without bound;
            // the oldest rows are the ones retention would have trimmed anyway.
            while (pending.size > MAX_PENDING_ROWS) {
                pending.removeAt(0)
            }
        }
        // No later event may arrive to hit BATCH_SIZE, so re-arm the timer.
        scheduleDelayedFlush()
    }

    private data class Row(
        val timestamp: Long,
        val packageName: String,
        val authority: String?,
        val protocol: String,
        val outcome: String,
        val matchedRule: String?,
    ) {
        /// `blockSubscriptionId` is left NULL: resolving it needs the rule snapshot
        /// this port does not keep, so Dart shows it as unknown.
        fun toValues(): ContentValues = ContentValues().apply {
            put("timestamp", timestamp)
            put("packageName", packageName)
            put("authority", authority)
            put("protocol", protocol)
            put("outcome", outcome)
            put("matchedRule", matchedRule)
            putNull("blockSubscriptionId")
        }
    }

    private companion object {
        const val TAG = "HttpRequestLogWriter"
        const val TABLE = "http_request_log"
        const val BATCH_SIZE = 10
        const val FLUSH_INTERVAL_MS = 500L
        const val CLOSE_TIMEOUT_MS = 500L

        /// Cap for the retry buffer when writes keep failing.
        const val MAX_PENDING_ROWS = 500

        /// Outcomes hidden by the `blocked_and_errors` log mode.
        val PASS_THROUGH_OUTCOMES = setOf("allowed", "passthrough")
    }
}
