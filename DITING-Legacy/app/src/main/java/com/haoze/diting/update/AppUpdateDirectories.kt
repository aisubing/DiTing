package com.haoze.diting.update

import java.io.File

/**
 * The single source of truth for where update APKs are downloaded.
 *
 * `AppUpdateManager` writes the APK into `filesDir/app-update`, and the "clear
 * download cache" action must delete exactly that directory. The cleanup used to
 * hard-code `filesDir/updates`, which never contained an APK, so the action
 * reported success while deleting nothing and leaving the APK behind.
 */
object AppUpdateDirectories {

    /** `filesDir/app-update` — where [AppUpdateManager] stores downloaded APKs. */
    fun downloadDirectory(filesDir: File): File = File(filesDir, AppUpdateManager.UPDATE_DIRECTORY)
}
