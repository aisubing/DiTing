package com.haoze.diting.update

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-060: the `download()` failure branch unconditionally called
 * `SystemSettingsStore.clearAppUpdateDownload(context)`. That record is a
 * *single global slot*: a failed download of a newer version therefore wiped the
 * record of an already-downloaded older APK, orphaning the file on disk (it is
 * never deleted, only its record is) and forcing a full re-download.
 *
 * Only the record belonging to the failed version may be dropped.
 */
class AppUpdateDownloadRecordRetentionTest {

    @Test
    fun recordOfTheFailedVersionIsCleared() {
        assertTrue(shouldClearDownloadRecord(recordedVersion = "3.0.18", failedVersion = "3.0.18"))
    }

    @Test
    fun recordOfAnOlderDownloadedVersionIsPreserved() {
        assertFalse(
            "a failed 3.0.18 download must not orphan the downloaded 3.0.17 APK",
            shouldClearDownloadRecord(recordedVersion = "3.0.17", failedVersion = "3.0.18")
        )
    }

    @Test
    fun missingRecordIsNotCleared() {
        assertFalse(shouldClearDownloadRecord(recordedVersion = "", failedVersion = "3.0.18"))
        assertFalse(shouldClearDownloadRecord(recordedVersion = null, failedVersion = "3.0.18"))
    }

    @Test
    fun recordedVersionIsComparedVerbatim() {
        // The stored value is written from AppUpdateInfo.version (no "v" prefix).
        assertFalse(shouldClearDownloadRecord(recordedVersion = "v3.0.18", failedVersion = "3.0.18"))
    }
}
