package com.haoze.diting.log

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File

/// Opens the Room-owned legacy database files for direct writes.
///
/// Same contract as [DnsLogWriter]: the Dart layer owns schema creation, so a
/// missing file (fresh install) is skipped instead of created, and the version
/// is never passed to `openDatabase` (that would rewrite `user_version`).
///
/// A second guard covers tables that only exist in one of the two files:
/// `app_traffic_daily` / `http_request_log` belong to `diting_database` only
/// (`ExpressRulesDatabase` explicitly excludes both entities), so a writer that
/// got the wrong database name must find "no such table" instead of creating it.
internal object LegacyDb {
    private const val TAG = "LegacyDb"

    fun open(context: Context, databaseName: String): SQLiteDatabase? {
        val path = context.getDatabasePath(databaseName)
        if (!File(path.path).exists()) return null
        return runCatching {
            SQLiteDatabase.openDatabase(path.path, null, SQLiteDatabase.OPEN_READWRITE)
        }.onFailure { Log.w(TAG, "Unable to open $databaseName", it) }.getOrNull()
    }

    fun hasTable(db: SQLiteDatabase, table: String): Boolean = runCatching {
        db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
            arrayOf(table),
        ).use { it.moveToFirst() }
    }.getOrDefault(false)
}
