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

    /**
     * Releases the persisted read grant for [uriString] **only when this app
     * actually holds one**.
     *
     * Needed where the URI is merely stored in a row and could equally have been
     * handed over without a persistable grant — a local subscription keeps its
     * file URI in `SubscriptionEntity.url`, and the default documents provider
     * can surface a URI the app never called `take` on. Releasing
     * unconditionally there would revoke a grant the user granted to the
     * provider, not to us. [ContentResolver.getPersistedUriPermissions] is the
     * only way to tell those two cases apart, since the entity itself carries no
     * "did we persist this" flag.
     *
     * Returns true when a grant was found (and release was attempted).
     */
    fun releaseIfPersisted(context: Context, uriString: String?): Boolean {
        val value = uriString?.trim().orEmpty()
        if (value.isEmpty()) return false
        val uri = runCatching { Uri.parse(value) }.getOrNull() ?: return false
        if (!SafGrantDecisions.mayRelease(value, persistedUriStrings(context))) return false
        release(context, uri)
        return true
    }

    /** The URI strings this app currently holds a persisted read grant for. */
    private fun persistedUriStrings(context: Context): List<String> = runCatching {
        context.contentResolver.persistedUriPermissions
            .filter { it.isReadPermission }
            .map { it.uri.toString() }
    }.getOrDefault(emptyList())
}
