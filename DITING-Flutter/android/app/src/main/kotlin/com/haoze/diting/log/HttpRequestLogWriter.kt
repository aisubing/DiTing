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

/// Persists the Go engine's MITM request events into `http_request_log`.
///
/// Source: `HttpLogCallback.onHttpEvent(packageName, authority, protocol,
/// outcome, matchedRule)` — emitted from `engine_mitm.go`'s `logHTTPEvent`, i.e.
/// only while stack MITM is active. Both `blocked` and `allowed` requests arrive
/// here, so this table is the only place the request timeline exists.
///
/// `outcome` is stored verbatim, never normalised. The Go side emits
/// `allowed` / `rewritten` / `blocked` / `passthrough` / `invalid` /
/// `handshake_failed` / `upstream_failed` / `decryption_failed` / `error`
/// (`mitm_handler.go`, `mitm_local_relay.go`, `mitm_relay.go`), and the Dart
/// reader decides grouping by comparing these strings. Mapping them into an
/// enum here would silently drop any value the engine adds later.
///
/// Batching follows 1.4.3 `HttpRequestLogger`: 10 rows or 500ms, whichever comes
/// first. The callback runs on the TLS relay path, so a synchronous insert (and
/// its WAL fsync) would add latency to every intercepted request.
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

    /// Whether a delayed flush is already queued, so ten trickling events still
    /// produce one write instead of ten.
    private val flushScheduled = AtomicBoolean(false)

    @Volatile
    private var closed = false

    /// `HttpRequestLogger.log` applied the DNS log mode to HTTP rows too, so the
    /// "off" and "blocked_and_errors" settings keep their meaning here.
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
    ///
    /// `closed` gates only the entry points (`onEvent`, `submitFlush`,
    /// `scheduleDelayedFlush`), never [writeBatch]: the final flush below runs
    /// after `closed` is already set, and guarding the writer on it would discard
    /// exactly the rows this method exists to save.
    fun close() {
        if (closed) return
        closed = true
        runCatching {
            // Explicit Runnable: `submit { }` is ambiguous between the Runnable
            // and Callable overloads on a Java interface.
            executor.submit(Runnable { writeBatch() }).get(CLOSE_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        }.onFailure { Log.w(TAG, "Final HTTP log flush did not complete", it) }
        executor.shutdown()
        runCatching { executor.awaitTermination(CLOSE_TIMEOUT_MS, TimeUnit.MILLISECONDS) }
    }

    /// Batch-threshold path: hand the buffer to the writer thread immediately.
    private fun submitFlush() {
        if (closed) return
        try {
            executor.execute { writeBatch() }
        } catch (_: RejectedExecutionException) {
            // Already shut down; close() commits the tail.
        }
    }

    /// Debounced path: arm one 500ms timer for the first row of a burst and reuse
    /// it for the rest, so a trickle of ten events is one write, not ten.
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
        // Returned from the block rather than assigned to a captured `val`: the
        // assignment-in-lambda form depends on `synchronized`'s callsInPlace
        // contract, and this reads the same either way.
        val batch = synchronized(lock) {
            if (pending.isEmpty()) return
            val copy = ArrayList(pending)
            pending.clear()
            copy
        }

        val db = LegacyDb.open(context, databaseName) ?: run {
            // Missing file = fresh install (the Dart layer creates the schema) or
            // a database that never had this table. Retrying cannot help and would
            // grow the buffer forever, so drop the batch.
            Log.w(TAG, "$databaseName not openable; dropping ${batch.size} HTTP rows")
            return
        }
        try {
            // `http_request_log` only exists in `diting_database`
            // (ExpressRulesDatabase excludes the entity), so guard anyway: an
            // INSERT into a missing table would throw per batch forever.
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

    /// Retention: keeps a failed batch instead of losing it, matching
    /// `HttpRequestLogger.flushLocked`'s "keep the batch for the next retry".
    private fun requeue(batch: List<Row>) {
        synchronized(lock) {
            if (closed) return
            // Prepend so ordering stays chronological, like 1.4.3 did with
            // `pending.addAll(0, batch)`.
            pending.addAll(0, batch)
            // A permanently failing write must not grow this list for the whole
            // session: past the cap the oldest rows go first, which is the same
            // data the retention policy would have trimmed.
            while (pending.size > MAX_PENDING_ROWS) {
                pending.removeAt(0)
            }
        }
        // No new event may arrive to reach BATCH_SIZE, so re-arm the timer.
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
        /// `blockSubscriptionId` is left NULL: 1.4.3 resolved it by re-evaluating
        /// the authority against the live rule snapshot
        /// (`GoTunnelLogProcessor.resolveHttpBlockSubscriptionId`), which needs
        /// the Kotlin rule cache this port does not have. The Dart layer shows
        /// the subscription as unknown rather than wrong.
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

        /// Safety valve for a write path that keeps failing.
        const val MAX_PENDING_ROWS = 500

        /// Outcomes that mean "request went through untouched"; they are the
        /// rows `blocked_and_errors` hides.
        val PASS_THROUGH_OUTCOMES = setOf("allowed", "passthrough")
    }
}
