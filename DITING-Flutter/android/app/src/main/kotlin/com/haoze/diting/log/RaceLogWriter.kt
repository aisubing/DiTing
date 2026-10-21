package com.haoze.diting.log

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File

/// Persists the Go engine's race callback into the legacy `dns_race_log` table.
///
/// Provider names stay null: the Dart layer owns the provider catalog
/// (`dns_config_builder.dart`) and resolves ids to display names itself, which
/// keeps custom providers working without passing a second map through the
/// start intent.
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
            // Fresh installs have no legacy database yet; the Dart layer owns
            // schema creation, so writing here would race its migrations.
            return null
        }
        return runCatching {
            SQLiteDatabase.openDatabase(path.path, null, SQLiteDatabase.OPEN_READWRITE)
        }.onFailure { Log.w(TAG, "Unable to open $databaseName", it) }.getOrNull()
    }
}
