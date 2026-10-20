package com.haoze.diting.log

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/// Persists the Go engine's per-UID traffic ticks into `app_traffic_daily`.
///
/// Source: `TrafficCallback.onTrafficStatsTick(String)` — a JSON array of
/// `{uid,tx,rx}` deltas, emitted once per second by `traffic_tracker.go`
/// (`uidDeltaJson`). The counters are swapped to zero on every tick, so each
/// payload is already a delta and must be ADDED to whatever the row holds.
///
/// The write path mirrors 1.4.3 `TrafficStatsManager` + `TrafficDatabaseSyncer`:
///  - the Go callback thread only parses and accumulates under a lock. SQLite
///    never runs there: the same dispatch loop also drives DNS and HTTP logging,
///    and a WAL commit on it would stall packet processing;
///  - one single-threaded executor serialises every DB write, so two flushes can
///    never interleave a transaction;
///  - a flush happens on the 15s timer or once the buffer crosses 1 MB, because
///    a per-tick transaction would mean one commit per second per session;
///  - the date key is the LOCAL `yyyy-MM-dd` at tick time, not at flush time. A
///    session crossing midnight therefore keeps two buckets, and each is written
///    under its own date: 1.4.3 flushed the old buffer before switching
///    `todayDateString`, and using the write-time date here would credit the
///    previous evening's bytes to the new day.
class TrafficIngest(
    private val context: Context,
    private val databaseName: String,
    private val uidPackageCache: UidPackageCache,
) {
    private val executor: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "diting-traffic-ingest").apply { isDaemon = true }
        }
    private val lock = Any()

    /// date -> (packageName -> accumulated delta). At most two entries in
    /// practice (a rollover in flight); the map is keyed by date so a failed
    /// write can be retried without being mis-dated.
    private val buckets = LinkedHashMap<String, LinkedHashMap<String, Delta>>()
    private var bufferedBytes = 0L

    @Volatile
    private var closed = false

    private val flushTask = executor.scheduleWithFixedDelay(
        { writeBuffered() },
        FLUSH_INTERVAL_MS,
        FLUSH_INTERVAL_MS,
        TimeUnit.MILLISECONDS,
    )

    /// Port of `TrafficStatsManager.onGoTrafficTick`, minus the speed EMA and the
    /// `StateFlow` snapshot: those only fed the 1.4.3 Compose gauge, which has no
    /// reader in this port. The persistent half — this table — is what the Dart
    /// traffic page reads.
    fun onTick(jsonDeltas: String) {
        if (jsonDeltas.isBlank() || closed) return
        val array = runCatching { JSONArray(jsonDeltas) }.getOrNull() ?: return
        if (array.length() == 0) return

        var overThreshold = false
        synchronized(lock) {
            val date = todayString()
            val bucket = buckets.getOrPut(date) { LinkedHashMap() }
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                val uid = obj.optInt("uid", -1)
                val tx = obj.optLong("tx", 0L)
                val rx = obj.optLong("rx", 0L)
                if (uid <= 0 || (tx <= 0 && rx <= 0)) continue
                val packageName = uidPackageCache.packageForUid(uid)
                if (packageName.isBlank()) {
                    // Without a package there is no primary-key value, and the
                    // Dart reader groups by package name; a synthetic
                    // "uid:10123" row would render as an app that does not
                    // exist. Skip it — the next tick retries with a warm cache.
                    continue
                }
                val delta = bucket.getOrPut(packageName) { Delta() }
                delta.tx += tx
                delta.rx += rx
                bufferedBytes += tx + rx
            }
            overThreshold = bufferedBytes > FLUSH_THRESHOLD_BYTES
            // A persistently failing write must not turn this map into an
            // unbounded heap leak: past the hard cap the oldest date bucket is
            // dropped (its bytes are already lost to the same failure).
            if (bufferedBytes > MAX_BUFFERED_BYTES && buckets.size > 1) {
                val oldest = buckets.keys.first()
                val dropped = buckets.remove(oldest) ?: LinkedHashMap()
                bufferedBytes -= dropped.values.sumOf { it.tx + it.rx }
                Log.w(TAG, "Traffic buffer over ${MAX_BUFFERED_BYTES}B; dropped $oldest")
            }
        }
        // Enqueue only; the single-threaded executor owns the writing.
        if (overThreshold) submitFlush()
    }

    /// Force-writes the buffer and stops the executor. Every service stop path
    /// calls this: the 15s timer would otherwise drop up to 15s of deltas when
    /// the process is torn down. (`am force-stop` never runs `onDestroy`, so the
    /// exposure is the timer window, not the whole session.)
    ///
    /// `closed` gates only the *entry points* (`onTick`, `submitFlush`), never
    /// [writeBuffered]: the final flush below runs after `closed` is already set,
    /// and guarding the writer on it would silently discard exactly the tail this
    /// method exists to save.
    fun close() {
        if (closed) return
        closed = true
        flushTask.cancel(false)
        runCatching {
            // Explicit Runnable: `submit { }` is ambiguous between the Runnable
            // and Callable overloads on a Java interface, and the Callable form
            // would swallow the intent of a fire-and-wait flush.
            executor.submit(Runnable { writeBuffered() }).get(CLOSE_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        }.onFailure { Log.w(TAG, "Final traffic flush did not complete", it) }
        executor.shutdown()
        runCatching { executor.awaitTermination(CLOSE_TIMEOUT_MS, TimeUnit.MILLISECONDS) }
    }

    private fun submitFlush() {
        if (closed) return
        try {
            executor.execute { writeBuffered() }
        } catch (_: RejectedExecutionException) {
            // Shut down already: close() is committing the tail.
        }
    }

    private fun writeBuffered() {
        // Returned from the block rather than assigned to a captured `val`:
        // the assignment-in-lambda form depends on `synchronized`'s
        // callsInPlace contract, and this reads the same either way.
        val snapshot = synchronized(lock) {
            // `closed` must NOT gate this method: close() sets it before the
            // final flush runs. requeue() checks it instead, so a failed final
            // write is dropped rather than parked in a buffer nobody drains.
            if (buckets.isEmpty()) return
            val copy = buckets.map { it.key to it.value }
            buckets.clear()
            bufferedBytes = 0L
            copy
        }

        val failed = ArrayList<Pair<String, LinkedHashMap<String, Delta>>>(snapshot.size)
        val db = LegacyDb.open(context, databaseName)
        if (db == null) {
            // Missing file = fresh install (the Dart layer creates the schema
            // later) or server mode. Retrying cannot help and would buffer every
            // tick forever, so drop the batch. This is the one loss path with no
            // retry; it only happens when the destination table does not exist.
            Log.w(TAG, "$databaseName not openable; dropping traffic buffer")
            return
        }
        try {
            // `diting_express` deliberately has no app_traffic_daily
            // (ExpressRulesDatabase excludes the entity), so a wrong database
            // name must be a no-op instead of a "no such table" error per flush.
            if (!LegacyDb.hasTable(db, TABLE)) {
                Log.w(TAG, "$databaseName has no $TABLE; dropping traffic buffer")
                return
            }
            val now = System.currentTimeMillis()
            for ((date, bucket) in snapshot) {
                db.beginTransaction()
                try {
                    for ((packageName, delta) in bucket) {
                        if (delta.tx <= 0 && delta.rx <= 0) continue
                        applyDelta(db, date, packageName, delta, now)
                    }
                    db.setTransactionSuccessful()
                } catch (t: Throwable) {
                    Log.w(TAG, "Unable to persist traffic batch for $date", t)
                    failed.add(date to bucket)
                } finally {
                    runCatching { db.endTransaction() }
                }
            }
        } finally {
            runCatching { db.close() }
        }
        if (failed.isNotEmpty()) requeue(failed)
    }

    /// Applies one delta with `AppTrafficDao.upsertDelta`'s exact semantics:
    /// add both counters, keep the stored `app_name` when the new one is empty,
    /// stamp `updated_at`.
    ///
    /// Written as UPDATE-then-INSERT instead of the DAO's `ON CONFLICT DO UPDATE`
    /// because that syntax needs SQLite 3.24 (API 30) while `minSdk` is 24: on
    /// API 24–29 the UPSERT is a *syntax* error and every flush would fail. The
    /// two forms produce the same rows, and with a single writer thread (the one
    /// attached to [executor]) there is no interleaving that could turn the
    /// UPDATE-missed/INSERT pair into a duplicate-key error. The Dart side only
    /// reads this table.
    private fun applyDelta(db: SQLiteDatabase, date: String, packageName: String, delta: Delta, now: Long) {
        val appName = appLabelFor(packageName)
        val updated = db.compileStatement(UPDATE_SQL).use { statement ->
            // Bind order follows UPDATE_SQL: the replacement name is bound twice
            // because the CASE both tests it and assigns it.
            statement.bindString(1, appName)
            statement.bindString(2, appName)
            statement.bindLong(3, delta.tx)
            statement.bindLong(4, delta.rx)
            statement.bindLong(5, now)
            statement.bindString(6, date)
            statement.bindString(7, packageName)
            statement.executeUpdateDelete()
        }
        if (updated == 0) {
            // Explicit <Any>: without it the array's inferred type is an
            // intersection (Comparable & Serializable) and the compiler warns.
            db.execSQL(INSERT_SQL, arrayOf<Any>(date, packageName, appName, delta.tx, delta.rx, now))
        }
    }

    /// Puts an unwritten batch back under its original date so the next flush
    /// retries it. 1.4.3 kept `pendingDbDeltas` on failure as well: dropping the
    /// bytes outright would leave a gap the UI cannot explain.
    private fun requeue(failed: List<Pair<String, LinkedHashMap<String, Delta>>>) {
        synchronized(lock) {
            if (closed) return
            for ((date, bucket) in failed) {
                val target = buckets.getOrPut(date) { LinkedHashMap() }
                for ((packageName, delta) in bucket) {
                    val merged = target.getOrPut(packageName) { Delta() }
                    merged.tx += delta.tx
                    merged.rx += delta.rx
                    bufferedBytes += delta.tx + delta.rx
                }
            }
        }
    }

    /// `app_name` is what the traffic page shows; it comes from
    /// `PackageManager`, resolved at write time (once per package per flush).
    /// Empty on failure, and the UPDATE then keeps the previously stored name.
    private fun appLabelFor(packageName: String): String = runCatching {
        val pm = context.packageManager
        pm.getApplicationInfo(packageName, 0).loadLabel(pm).toString()
    }.getOrDefault("")

    private fun todayString(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private class Delta(var tx: Long = 0L, var rx: Long = 0L)

    private companion object {
        const val TAG = "TrafficIngest"
        const val TABLE = "app_traffic_daily"
        const val FLUSH_INTERVAL_MS = 15_000L
        const val FLUSH_THRESHOLD_BYTES = 1024L * 1024L
        const val CLOSE_TIMEOUT_MS = 500L

        /// Safety valve for a write path that keeps failing: without it the
        /// pending map grows for the whole session.
        const val MAX_BUFFERED_BYTES = 8L * 1024L * 1024L

        /// Same effect as `AppTrafficDao.upsertDelta`
        /// (`Android/.../data/dao/AppTrafficDao.kt:48-56`) — accumulate both
        /// counters, keep the stored name when the new one is empty, stamp
        /// `updated_at` — expressed as UPDATE + INSERT because `ON CONFLICT DO
        /// UPDATE` requires SQLite 3.24 (API 30) and this app supports API 24.
        /// The UPDATE binds the app name twice: the CASE both tests it and
        /// assigns it.
        const val UPDATE_SQL = """
            UPDATE app_traffic_daily SET
                app_name = CASE WHEN ? != '' THEN ? ELSE app_name END,
                tx_bytes = tx_bytes + ?,
                rx_bytes = rx_bytes + ?,
                updated_at = ?
            WHERE date = ? AND package_name = ?
        """

        const val INSERT_SQL = """
            INSERT INTO app_traffic_daily (date, package_name, app_name, tx_bytes, rx_bytes, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
        """
    }
}
