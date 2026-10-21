package com.haoze.diting.log

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/// Persists the Go engine's batch DNS log JSON into the legacy Room table.
///
/// The payload is the same `logItem` array 1.4.3 consumed in
/// `GoTunnelLogProcessor`; field meanings are documented in
/// `DITING-Legacy/tunnel/log_aggregator.go`. Writes go straight through SQLite so the
/// Flutter side can keep reading the same `dns_log` table with sqflite.
object DnsLogWriter {
    const val DB_NORMAL = "diting_database"
    const val DB_EXPRESS = "diting_express"

    const val MODE_ALL = "all"
    const val MODE_BLOCKED_AND_ERRORS = "blocked_and_errors"
    const val MODE_OFF = "off"

    private const val TAG = "DnsLogWriter"

    fun writeBatch(context: Context, databaseName: String, mode: String, jsonLogs: String) {
        if (mode == MODE_OFF || jsonLogs.isBlank()) return
        val array = runCatching { JSONArray(jsonLogs) }.getOrNull() ?: return
        if (array.length() == 0) return

        val db = open(context, databaseName) ?: return
        try {
            db.beginTransaction()
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                val entity = toEntity(obj, mode) ?: continue
                db.insertWithOnConflict(
                    "dns_log",
                    null,
                    android.content.ContentValues().apply {
                        put("timestamp", entity.timestamp)
                        put("queryName", entity.queryName)
                        put("queryType", entity.queryType)
                        put("result", entity.result)
                        put("message", entity.message)
                        put("cached", if (entity.cached) 1 else 0)
                        put("blockSubscriptionId", entity.blockSubscriptionId)
                        put("packageName", entity.packageName)
                    },
                    SQLiteDatabase.CONFLICT_IGNORE,
                )
            }
            db.setTransactionSuccessful()
        } catch (t: Throwable) {
            Log.w(TAG, "Unable to persist DNS log batch", t)
        } finally {
            runCatching { db.endTransaction() }
            runCatching { db.close() }
        }
    }

    private fun open(context: Context, databaseName: String): SQLiteDatabase? {
        val path = context.getDatabasePath(databaseName)
        if (!File(path.path).exists()) {
            // Fresh installs have no legacy database yet; the Dart layer will
            // create it through its own migrations before logs are displayed.
            return null
        }
        return runCatching {
            SQLiteDatabase.openDatabase(path.path, null, SQLiteDatabase.OPEN_READWRITE)
        }.onFailure { Log.w(TAG, "Unable to open $databaseName", it) }.getOrNull()
    }

    private fun toEntity(obj: JSONObject, mode: String): LogEntity? {
        val domain = obj.optString("d")
        if (domain.isBlank()) return null
        val blocked = obj.optBoolean("b")
        val blockedBy = obj.optString("k")
        val error = obj.optString("e")
        val result = when {
            error.isNotBlank() -> "ERROR"
            blockedBy.startsWith("rewrite=") -> "REWRITTEN"
            blocked -> "BLOCKED"
            else -> "PASSED"
        }
        if (mode == MODE_BLOCKED_AND_ERRORS && result == "PASSED") return null
        val resolved = obj.optString("i")
        val app = obj.optString("a")
        val elapsed = obj.optLong("r")
        val message = listOfNotNull(
            app.takeIf { it.isNotBlank() }?.let { "app=$it" },
            resolved.takeIf { it.isNotBlank() }?.let { "resolved=$it" },
            blockedBy.takeIf { it.isNotBlank() }?.let { "blocked_by=$it" },
            error.takeIf { it.isNotBlank() }?.let { "error=$it" },
            elapsed.takeIf { it > 0 }?.let { "elapsed=${it}ms" },
        ).joinToString(", ").takeIf { it.isNotEmpty() }
        return LogEntity(
            timestamp = obj.optLong("ts").takeIf { it > 0 } ?: System.currentTimeMillis(),
            queryName = domain.lowercase(),
            queryType = obj.optInt("t"),
            result = result,
            message = message,
            cached = obj.optBoolean("c"),
            blockSubscriptionId = subscriptionIdOf(blockedBy),
            packageName = app.ifBlank { null },
        )
    }

    private fun subscriptionIdOf(blockedBy: String): Long? = blockedBy
        .split(',')
        .map { it.trim() }
        .firstNotNullOfOrNull { token ->
            if (token.startsWith("sub_")) token.removePrefix("sub_").toLongOrNull() else null
        }

    private data class LogEntity(
        val timestamp: Long,
        val queryName: String,
        val queryType: Int,
        val result: String,
        val message: String?,
        val cached: Boolean,
        val blockSubscriptionId: Long?,
        val packageName: String?,
    )
}
