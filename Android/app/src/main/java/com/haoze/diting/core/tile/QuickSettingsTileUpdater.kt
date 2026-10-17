package com.haoze.diting.core.tile

import android.content.ComponentName
import android.content.Context
import android.service.quicksettings.TileService
import android.util.Log

/**
 * Dispatches Quick Settings tile refresh requests to the system without
 * coupling backend services to the UI/Tile service class.
 */
object QuickSettingsTileUpdater {
    private const val TAG = "QuickSettingsTileUpdater"

    /** Fully-qualified class name of the tile service declared in the manifest. */
    const val TILE_SERVICE_CLASS = "com.haoze.diting.tile.DitingTileService"

    fun requestTileUpdate(context: Context) {
        runCatching {
            val appContext = context.applicationContext
            // ComponentName's second argument is a fully-qualified class name;
            // prefixing the package name again produced
            // `com.haoze.diting.com.haoze.diting.tile.DitingTileService`, so
            // requestListeningState never matched the real tile service.
            TileService.requestListeningState(
                appContext,
                ComponentName(appContext.packageName, TILE_SERVICE_CLASS)
            )
        }.onFailure { e ->
            Log.w(TAG, "Failed to request tile listening state", e)
        }
    }
}
