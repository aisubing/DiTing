package com.haoze.diting.log

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File

/// Opens the database files owned by the Dart side for direct writes. A missing file is
/// skipped instead of created, and no version is passed to openDatabase because that
/// would rewrite `user_version`. `hasTable` guards tables present in only one database.
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
