package com.haoze.diting.crash

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-053: after a successful automatic backup at the consecutive-crash
 * threshold, `onCrashOccurred` only set `KEY_PENDING_AUTO_EXPORT_NOTICE` — it
 * never set the suppression flag `KEY_HAS_MANUALLY_EXPORTED`. The check at the
 * threshold (`newCount >= 3 && !hasExported`) therefore stayed true forever, so
 * *every* subsequent crash in the same streak exported another full backup into
 * the Download directory.
 *
 * Note (documentation correction): `clearCrashLogs()` writes
 * `putBoolean(KEY_HAS_MANUALLY_EXPORTED, false)` at CrashLogManager.kt:364 —
 * that *clears* the suppression flag and re-arms auto backup for the next
 * streak. It is not "setting" the flag as the triage doc claims.
 */
class CrashLogManagerAutoExportTest {

    @Test
    fun belowThresholdNeverExports() {
        assertFalse(CrashLogManager.shouldAutoExport(consecutiveCount = 1, hasExported = false))
        assertFalse(CrashLogManager.shouldAutoExport(consecutiveCount = 2, hasExported = false))
    }

    @Test
    fun thresholdExportsOnceWhenNotYetBackedUp() {
        assertTrue(CrashLogManager.shouldAutoExport(consecutiveCount = 3, hasExported = false))
    }

    @Test
    fun alreadyBackedUpStreakDoesNotExportAgain() {
        // Crashes 4, 5, 6 ... in the same streak: the auto backup already ran.
        assertFalse(CrashLogManager.shouldAutoExport(consecutiveCount = 4, hasExported = true))
        assertFalse(CrashLogManager.shouldAutoExport(consecutiveCount = 99, hasExported = true))
    }

    @Test
    fun manualExportAlsoSuppressesAutoBackup() {
        assertFalse(CrashLogManager.shouldAutoExport(consecutiveCount = 3, hasExported = true))
    }
}
