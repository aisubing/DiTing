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

/// Writes per-UID traffic into `app_traffic_daily`, batched every 15s or 1MB; deltas are ADDED.
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

    /// date -> (packageName -> delta); keyed by date so a retried write is not mis-dated
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

    fun onTick(jsonDeltas: String) {
        if (jsonDeltas.isBlank() || closed) return
        val array = runCatching { JSONArray(jsonDeltas) }.getOrNull() ?: return
        if (array.length() == 0) return

        var overThreshold = false
        var tickTx = 0L
        var tickRx = 0L
        synchronized(lock) {
            val date = todayString()
            val bucket = buckets.getOrPut(date) { LinkedHashMap() }
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                val uid = obj.optInt("uid", -1)
                val tx = obj.optLong("tx", 0L)
                val rx = obj.optLong("rx", 0L)
                if (uid <= 0 || (tx <= 0 && rx <= 0)) continue
                // Device-wide rates: every delta counts, including package-less rows.
                tickTx += tx
                tickRx += rx
                val packageName = uidPackageCache.packageForUid(uid)
                if (packageName.isBlank()) {
                    // No package name yet; the next tick retries with a warm cache.
                    continue
                }
                val delta = bucket.getOrPut(packageName) { Delta() }
                delta.tx += tx
                delta.rx += rx
                bufferedBytes += tx + rx
            }
            overThreshold = bufferedBytes > FLUSH_THRESHOLD_BYTES
            // Past the cap the oldest date bucket is dropped, so a failing write cannot leak.
            if (bufferedBytes > MAX_BUFFERED_BYTES && buckets.size > 1) {
                val oldest = buckets.keys.first()
                val dropped = buckets.remove(oldest) ?: LinkedHashMap()
                bufferedBytes -= dropped.values.sumOf { it.tx + it.rx }
                Log.w(TAG, "Traffic buffer over ${MAX_BUFFERED_BYTES}B; dropped $oldest")
            }
        }
        // Outside the lock: the monitor only stores two numbers.
        TrafficRateMonitor.onTick(tickTx, tickRx)
        if (overThreshold) submitFlush()
    }

    /// Force-writes the buffer and stops the executor, so the 15s timer cannot drop the tail
    fun close() {
        if (closed) return
        closed = true
        flushTask.cancel(false)
        runCatching {
            // Explicit Runnable: `submit { }` is ambiguous with the Callable overload.
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
        // Returned from the block, not assigned to a captured `val`: that relies on callsInPlace.
        val snapshot = synchronized(lock) {
            // `closed` must NOT gate this method: close() sets it before the final flush.
            if (buckets.isEmpty()) return
            val copy = buckets.map { it.key to it.value }
            buckets.clear()
            bufferedBytes = 0L
            copy
        }

        val failed = ArrayList<Pair<String, LinkedHashMap<String, Delta>>>(snapshot.size)
        val db = LegacyDb.open(context, databaseName)
        if (db == null) {
            // No database yet (fresh install) or server mode: retrying would buffer every tick.
            Log.w(TAG, "$databaseName not openable; dropping traffic buffer")
            return
        }
        try {
            // Express has no app_traffic_daily: a wrong database must be a no-op.
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

    /// Adds both counters, keeps a stored non-empty `app_name`. ON CONFLICT needs API 30
    private fun applyDelta(db: SQLiteDatabase, date: String, packageName: String, delta: Delta, now: Long) {
        val appName = appLabelFor(packageName)
        val updated = db.compileStatement(UPDATE_SQL).use { statement ->
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
            // Explicit <Any>: otherwise the array type is inferred as Comparable & Serializable.
            db.execSQL(INSERT_SQL, arrayOf<Any>(date, packageName, appName, delta.tx, delta.rx, now))
        }
    }

    /// Puts an unwritten batch back under its original date for the next flush
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

    /// PackageManager label at write time; empty on failure
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

        const val MAX_BUFFERED_BYTES = 8L * 1024L * 1024L

        /// UPSERT as UPDATE + INSERT. The CASE keeps a non-empty stored name, so it is bound twice
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
