package com.haoze.diting.update

import com.haoze.diting.data.cleanup.DataCleanupManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * A-013: "清理下载与临时缓存" deleted `File(context.filesDir, "updates")` while
 * `AppUpdateManager` stores the downloaded APK in `File(filesDir, "app-update")`
 * (`AppUpdateManager.kt:52`). Nothing was ever deleted, the UI still reported
 * success, and the APK plus its `.part` leftover stayed on disk.
 *
 * `AppUpdateDirectories.downloadDirectory` is now the single source of truth
 * shared by the downloader and the cleanup.
 */
class AppUpdateDirectoryContractTest {

    @Test
    fun updateDirectoryNameIsAppUpdate() {
        assertEquals("app-update", AppUpdateManager.UPDATE_DIRECTORY)
        assertFalse(
            "the legacy cleanup path must not be reused",
            AppUpdateManager.UPDATE_DIRECTORY == "updates"
        )
    }

    @Test
    fun downloadDirectoryResolvesUnderFilesDir() {
        val filesDir = File("/data/user/0/com.haoze.diting/files")
        val target = AppUpdateDirectories.downloadDirectory(filesDir)

        assertEquals(File(filesDir, "app-update"), target)
        assertEquals(
            "/data/user/0/com.haoze.diting/files/app-update",
            target.path.replace('\\', '/')
        )
        assertFalse(
            "the legacy 'updates' directory is not where APKs live",
            target.path.replace('\\', '/').endsWith("/files/updates")
        )
    }

    @Test
    fun cleanupActuallyDeletesADownloadedApk() {
        val filesDir = Files.createTempDirectory("diting_files").toFile()
        try {
            val updateDir = AppUpdateDirectories.downloadDirectory(filesDir).apply { mkdirs() }
            val apk = File(updateDir, "DITING-arm64-v8a.apk").apply { writeText("apk") }
            val part = File(updateDir, "DITING-arm64-v8a.apk.part").apply { writeText("partial") }
            assertTrue(apk.exists())
            assertTrue(part.exists())

            // This is exactly what clearDownloadAndTempCache() does.
            DataCleanupManager.deleteDirectoryContents(
                AppUpdateDirectories.downloadDirectory(filesDir)
            )

            assertFalse("downloaded APK must be deleted", apk.exists())
            assertFalse("partial download must be deleted", part.exists())
            assertTrue("the directory itself is kept", updateDir.exists())
            assertEquals(0, updateDir.listFiles()?.size ?: 0)
        } finally {
            filesDir.deleteRecursively()
        }
    }

    @Test
    fun legacyUpdatesDirectoryIsNotTouched() {
        val filesDir = Files.createTempDirectory("diting_files").toFile()
        try {
            // A file in the old (wrong) location must survive: it is not an APK
            // and the cleanup no longer touches it.
            val legacyDir = File(filesDir, "updates").apply { mkdirs() }
            val legacyFile = File(legacyDir, "stale.txt").apply { writeText("legacy") }

            DataCleanupManager.deleteDirectoryContents(
                AppUpdateDirectories.downloadDirectory(filesDir)
            )

            assertTrue(legacyFile.exists())
        } finally {
            filesDir.deleteRecursively()
        }
    }
}
