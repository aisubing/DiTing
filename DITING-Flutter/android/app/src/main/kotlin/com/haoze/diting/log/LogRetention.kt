package com.haoze.diting.log

import android.content.Context
import android.util.Log
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/**
 * Periodic retention sweep for the four request-log tables.
 *
 * Port of 1.4.3 `core/log/LogMaintenanceManager.kt` (`LogMaintenance`).
 *
 * ## Why this exists
 *
 * The Flutter port persisted `log_retention_days` and `traffic_stats_retention_days`
 * and the 日志模式 page promised 「超过所选时间的 DNS 请求日志会自动删除」, but nothing
 * ever read those keys back. The setting was a decoration: the tables grew without
 * bound and the promise was false. 1.4.3 started `LogMaintenance.start(...)` from
 * both tunnel services; this is the same schedule driven from the same place.
 *
 * ## Why native and not Dart
 *
 * The sweep has to run while no Flutter UI is alive — the tunnel is a foreground
 * service and the user may not open the app for days. The Dart side only observes
 * tables; the writers that fill them are already here, so the pruner belongs next
 * to them.
 *
 * ## Two independent windows
 *
 * `log_retention_days` covers the four request-log tables; `app_traffic_daily` has
 * its own `traffic_stats_retention_days`. Reusing one for the other silently
 * truncates the traffic history to a week (1.4.3 has an explicit comment about
 * this mistake), so the two are always passed in separately.
 */
internal object LogRetention {
    private const val TAG = "LogRetention"

    /** 1.4.3 `MAINTENANCE_INTERVAL_MS`. */
    private const val INTERVAL_MS = 60 * 60 * 1000L

    /**
     * 1.4.3 `INITIAL_DELAY_MS`.
     *
     * Not zero: the first sweep competes with the tunnel handshake for the disk and
     * the engine's own writes, and nothing is gained by pruning during startup.
     */
    private const val INITIAL_DELAY_MS = 30 * 1000L

    private const val DAY_MS = 24 * 60 * 60 * 1000L

    /** `SystemSettingsStore.DEFAULT_LOG_RETENTION_DAYS` / default traffic window. */
    private const val DEFAULT_LOG_RETENTION_DAYS = 7
    private const val DEFAULT_TRAFFIC_RETENTION_DAYS = 30

    private var executor: ScheduledExecutorService? = null

    /**
     * Starts the hourly sweep; a no-op when one is already running.
     *
     * [databaseName] is the file the current mode writes to (`diting_database` for
     * normal/server, `diting_express` for express mode), and [prefsName] is that
     * mode's dataset container — 1.4.3 keys the retention window per dataset, so
     * express and normal each carry their own value.
     * [includeHttpAndTraffic] is false for express: `ExpressRulesDatabase` has
     * neither `http_request_log` nor `app_traffic_daily`.
     */
    @Synchronized
    fun start(
        context: Context,
        databaseName: String,
        prefsName: String,
        includeHttpAndTraffic: Boolean,
    ) {
        if (executor != null) return
        val appContext = context.applicationContext
        val scheduler = Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "diting-log-retention").apply { isDaemon = true }
        }
        executor = scheduler
        scheduler.scheduleWithFixedDelay(
            {
                runCatching {
                    prune(
                        appContext,
                        databaseName = databaseName,
                        prefsName = prefsName,
                        includeHttpAndTraffic = includeHttpAndTraffic,
                    )
                }.onFailure { Log.w(TAG, "retention sweep failed", it) }
            },
            INITIAL_DELAY_MS,
            INTERVAL_MS,
            TimeUnit.MILLISECONDS,
        )
        Log.i(TAG, "retention sweep scheduled for $databaseName ($prefsName)")
    }

    /** Stops the sweep. Safe to call when it was never started. */
    @Synchronized
    fun stop() {
        executor?.shutdownNow()
        executor = null
    }

    /**
     * Deletes rows older than the configured windows.
     *
     * Returns the number of deleted rows, for tests. Each table is pruned inside
     * its own `runCatching`: a missing table (express has no `http_request_log`)
     * must not stop the other three.
     */
    fun prune(
        context: Context,
        databaseName: String,
        prefsName: String,
        includeHttpAndTraffic: Boolean,
    ): Int {
        val settings = RetentionSettings(context, prefsName)
        val logDays = settings.logRetentionDays()
        if (logDays <= 0) return 0
        val cutoff = System.currentTimeMillis() - logDays * DAY_MS

        val db = LegacyDb.open(context, databaseName) ?: return 0
        var deleted = 0
        try {
            for (table in PRUNED_LOG_TABLES) {
                if (!LegacyDb.hasTable(db, table)) continue
                deleted += runCatching {
                    db.delete(table, "timestamp < ?", arrayOf(cutoff.toString()))
                }.getOrDefault(0)
            }
            if (includeHttpAndTraffic && LegacyDb.hasTable(db, "app_traffic_daily")) {
                val trafficDays = settings.trafficRetentionDays()
                if (trafficDays > 0) {
                    // `date` is a `yyyy-MM-dd` string, so the cutoff is a date, not
                    // an epoch: comparing it against millis would delete everything.
                    val cutoffDate = dayStringAt(
                        System.currentTimeMillis() - trafficDays * DAY_MS,
                    )
                    deleted += runCatching {
                        db.delete("app_traffic_daily", "date < ?", arrayOf(cutoffDate))
                    }.getOrDefault(0)
                }
            }
        } finally {
            runCatching { db.close() }
        }
        if (deleted > 0) Log.i(TAG, "pruned $deleted rows older than $logDays d")
        return deleted
    }

    /** Tables carrying a `timestamp` column in epoch millis. */
    private val PRUNED_LOG_TABLES = arrayOf(
        "dns_log",
        "http_request_log",
        "dns_race_log",
        "bootstrap_log",
    )

    /** `yyyy-MM-dd` in the device zone — the key format `TrafficIngest` writes. */
    internal fun dayStringAt(millis: Long): String {
        val format = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
        return format.format(java.util.Date(millis))
    }

    /**
     * Reads the two windows from the same preference files the settings page writes.
     *
     * Kept as a small class instead of two `Context` lambdas so a test can point it
     * at any `Context` without touching the real segments.
     */
    internal class RetentionSettings(
        private val context: Context,
        private val prefsName: String,
    ) {
        fun logRetentionDays(): Int = runCatching {
            // Dataset-scoped: normal and express keep separate values, and reading
            // the wrong container silently applies the other mode's window.
            context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                .getInt(KEY_LOG_RETENTION_DAYS, DEFAULT_LOG_RETENTION_DAYS)
        }.getOrDefault(DEFAULT_LOG_RETENTION_DAYS).coerceIn(1, 30)

        fun trafficRetentionDays(): Int = runCatching {
            // 1.4.3 reads the traffic window from the global container only: the
            // two traffic tables exist in `diting_database` alone, so there is no
            // express value to confuse it with.
            context.getSharedPreferences(PREFS_GLOBAL, Context.MODE_PRIVATE)
                .getInt(KEY_TRAFFIC_RETENTION_DAYS, DEFAULT_TRAFFIC_RETENTION_DAYS)
        }.getOrDefault(DEFAULT_TRAFFIC_RETENTION_DAYS).coerceIn(1, 90)
    }

    private const val PREFS_GLOBAL = "dns_vpn_prefs"
    private const val KEY_LOG_RETENTION_DAYS = "log_retention_days"
    private const val KEY_TRAFFIC_RETENTION_DAYS = "traffic_stats_retention_days"
}
