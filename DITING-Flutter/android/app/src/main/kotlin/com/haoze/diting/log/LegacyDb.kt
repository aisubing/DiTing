package com.haoze.diting.log

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

/// Owns the one writable connection per database file used by the native readers and writers.
///
/// Opening a connection per log event is what broke 2.1.7: every `openDatabase` runs Android's
/// journal-mode probe (`PRAGMA journal_mode`), which needs the schema, so while the Flutter side
/// held the write lock every open threw `SQLiteDatabaseLockedException` and the event was dropped
/// (183 attempts, zero successes, four minutes). One long-lived connection plus `busy_timeout`
/// turns that into a short wait on the same connection the writers already share.
internal object LegacyDb {
    private const val BUSY_TIMEOUT_MS = 5_000

    /// Outcome of [open]. Writers must tell [Absent] (nothing to write to yet) from [Unavailable]
    /// (locked right now): only the latter is worth retrying, and only the former is worth dropping.
    sealed interface Open {
        class Ready(val db: SQLiteDatabase) : Open

        /// The file does not exist yet (fresh install): writing now would race schema creation.
        data object Absent : Open

        /// Locked or otherwise unopenable; the caller keeps its buffer and retries with backoff.
        class Unavailable(val cause: Throwable?) : Open
    }

    private val connections = HashMap<String, SQLiteDatabase>()

    @Synchronized
    fun open(context: Context, databaseName: String): Open {
        connections[databaseName]?.let { cached ->
            if (cached.isOpen) return Open.Ready(cached)
            // Closed behind our back (a reader that still owns a handle, or a service restart).
            connections.remove(databaseName)
        }
        val path = context.getDatabasePath(databaseName)
        if (!File(path.path).exists()) return Open.Absent
        return runCatching {
            SQLiteDatabase.openDatabase(
                path.path,
                null,
                SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING,
            ).apply {
                // WAL is what the sqflite side uses; asking for it explicitly keeps both sides on
                // the same journal mode instead of racing a switch under the other's lock.
                execSQL("PRAGMA busy_timeout = $BUSY_TIMEOUT_MS")
            }
        }.fold(
            onSuccess = { db ->
                connections[databaseName] = db
                Open.Ready(db)
            },
            onFailure = { error ->
                DbWriteHealth.onOpenFailure(databaseName, error)
                Open.Unavailable(error)
            },
        )
    }

    /// For readers that only need "the database, or null".
    fun writable(context: Context, databaseName: String): SQLiteDatabase? =
        (open(context, databaseName) as? Open.Ready)?.db

    /// Releases every cached connection; the next [open] re-opens on demand.
    @Synchronized
    fun closeAll() {
        for ((name, db) in connections) {
            runCatching { db.close() }
                .onFailure { DbWriteHealth.warn("LegacyDb", "close $name failed", it) }
        }
        connections.clear()
    }

    fun hasTable(db: SQLiteDatabase, table: String): Boolean = runCatching {
        db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
            arrayOf(table),
        ).use { it.moveToFirst() }
    }.getOrDefault(false)
}
