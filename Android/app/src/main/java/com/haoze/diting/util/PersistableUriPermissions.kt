package com.haoze.diting.util

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log

/**
 * Single place for SAF persistable URI grants.
 *
 * The app takes a persistable read grant for every file the user picks (rules
 * import, subscription file, custom background). Those grants survive reboots
 * until they are released, so every place that stops using a URI must release
 * it again; otherwise the app keeps read access to files the user has removed
 * from the app forever. Before this helper there were five `take` call sites and
 * no `release` at all.
 */
object PersistableUriPermissions {
    private const val TAG = "PersistableUriPermissions"
    private const val READ_FLAGS = Intent.FLAG_GRANT_READ_URI_PERMISSION

    /** Takes (and persists) read access to [uri]. Never throws. */
    fun take(context: Context, uri: Uri) {
        runCatching {
            context.contentResolver.takePersistableUriPermission(uri, READ_FLAGS)
        }.onFailure { error ->
            // The picker intent may not have requested a persistable grant
            // (e.g. a plain ACTION_GET_CONTENT result); that is not fatal.
            Log.w(TAG, "takePersistableUriPermission failed for $uri", error)
        }
    }

    /**
     * Releases the persisted read grant for [uri] if one exists. Never throws:
     * releasing a grant that was never taken is a normal, expected outcome.
     */
    fun release(context: Context, uri: Uri) {
        runCatching {
            context.contentResolver.releasePersistableUriPermission(uri, READ_FLAGS)
        }.onFailure { error ->
            Log.d(TAG, "releasePersistableUriPermission skipped for $uri: ${error.message}")
        }
    }

    /**
     * Releases the persisted read grant for [uriString] if one exists. Used for
     * URIs stored in preferences as strings; blank or unparseable values are
     * ignored rather than throwing.
     */
    fun releaseString(context: Context, uriString: String?) {
        val value = uriString?.trim().orEmpty()
        if (value.isEmpty()) return
        val uri = runCatching { Uri.parse(value) }.getOrNull() ?: return
        release(context, uri)
    }
}
