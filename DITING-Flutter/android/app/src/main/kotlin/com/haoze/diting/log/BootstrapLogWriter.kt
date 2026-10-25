package com.haoze.diting.log

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log

/// `bootstrap_log` writer: one row per bootstrap probe the engine reports.
///
/// The engine already races bootstrap IPs and reports every attempt through
/// `BootstrapLogCallback`; nothing consumed it before, so the table stayed empty and the
/// dashboard card had no data. Rows are inserted one by one like `RaceLogWriter`: the
/// callback fires per resolved host, not per DNS query.
object BootstrapLogWriter {
    private const val TAG = "BootstrapLogWriter"
    private const val TABLE = "bootstrap_log"

    fun write(
        context: Context,
        databaseName: String,
        ipId: String,
        ipName: String,
        ip: String,
        host: String,
        success: Boolean,
        elapsedMs: Long,
        fallbackUsed: Boolean,
        errorMessage: String,
    ) {
        if (host.isBlank()) return
        val db = LegacyDb.open(context, databaseName) ?: return
        try {
            if (!LegacyDb.hasTable(db, TABLE)) return
            val values = ContentValues().apply {
                put("timestamp", System.currentTimeMillis())
                put("ipId", ipId.ifBlank { "unknown" })
                put("ipName", ipName.ifBlank { ipId })
                put("ip", ip)
                put("host", host.lowercase())
                put("success", if (success) 1 else 0)
                put("elapsedMs", elapsedMs)
                put("fallbackUsed", if (fallbackUsed) 1 else 0)
                put("message", errorMessage.ifBlank { null })
            }
            db.insertWithOnConflict(TABLE, null, values, SQLiteDatabase.CONFLICT_IGNORE)
        } catch (t: Throwable) {
            Log.w(TAG, "Unable to persist bootstrap log", t)
        } finally {
            runCatching { db.close() }
        }
    }
}
