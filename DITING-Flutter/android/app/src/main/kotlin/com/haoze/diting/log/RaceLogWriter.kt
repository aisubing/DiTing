package com.haoze.diting.log

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File

/// Writes the race callback into `dns_race_log`; provider names stay null, Dart resolves ids.
object RaceLogWriter {
    private const val TAG = "RaceLogWriter"

    fun write(
        context: Context,
        databaseName: String,
        queryName: String,
        queryType: Int,
        strategy: String,
        providerCount: Int,
        success: Boolean,
        elapsedMs: Long,
        selectedProviderId: String,
        selectedElapsedMs: Long,
        winnerProviderId: String,
        winnerElapsedMs: Long,
        fallbackUsed: Boolean,
        fallbackSuccess: Boolean,
        errorMessage: String,
    ) {
        if (queryName.isBlank()) return
        val db = open(context, databaseName) ?: return
        try {
            val values = ContentValues().apply {
                put("timestamp", System.currentTimeMillis())
                put("queryName", queryName.lowercase())
                put("queryType", queryType)
                put("strategy", strategy)
                put("providerCount", providerCount)
                put("success", if (success) 1 else 0)
                put("elapsedMs", elapsedMs)
                put("selectedProviderId", selectedProviderId.ifBlank { null })
                put("selectedProviderName", null as String?)
                put("selectedElapsedMs", selectedElapsedMs.takeIf { it > 0 })
                put("winnerProviderId", winnerProviderId.ifBlank { null })
                put("winnerProviderName", null as String?)
                put("winnerElapsedMs", winnerElapsedMs.takeIf { it > 0 })
                put("fallbackUsed", if (fallbackUsed) 1 else 0)
                put("fallbackSuccess", if (fallbackSuccess) 1 else 0)
                put("message", errorMessage.ifBlank { null })
            }
            db.insertWithOnConflict(
                "dns_race_log",
                null,
                values,
                SQLiteDatabase.CONFLICT_IGNORE,
            )
        } catch (t: Throwable) {
            Log.w(TAG, "Unable to persist race log", t)
        } finally {
            runCatching { db.close() }
        }
    }

    private fun open(context: Context, databaseName: String): SQLiteDatabase? {
        val path = context.getDatabasePath(databaseName)
        if (!File(path.path).exists()) {
            // No database yet on a fresh install; writing now would race Dart's schema creation.
            return null
        }
        return runCatching {
            SQLiteDatabase.openDatabase(path.path, null, SQLiteDatabase.OPEN_READWRITE)
        }.onFailure { Log.w(TAG, "Unable to open $databaseName", it) }.getOrNull()
    }
}
