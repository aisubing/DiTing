package com.haoze.diting.ui.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * A-035: importing a config backup dropped a custom notification text whenever the
 * other one was empty. `ConfigExporter` writes both fields unconditionally (an
 * unused field is exported as `""`), while `ConfigTransferParser` turns empty
 * strings into `null`. Importing then required *both* sides to be non-null, so a
 * backup with exactly one custom text silently imported neither.
 *
 * [mergedCustomNotificationTexts] keeps the imported side and falls back to the
 * locally stored value for the missing one; a backup that predates both fields
 * still must not touch the local settings.
 */
class NotificationTextsImportMergeTest {

    @Test
    fun onlyTheRunningTextExportedKeepsItAndPreservesStoredStoppedText() {
        val merged = mergedCustomNotificationTexts(
            importedRunning = "已连接",
            importedStopped = null,
            storedRunning = "旧的运行文案",
            storedStopped = "旧的停止文案"
        )
        assertEquals("已连接", merged?.first)
        assertEquals("旧的停止文案", merged?.second)
    }

    @Test
    fun onlyTheStoppedTextExportedKeepsItAndPreservesStoredRunningText() {
        val merged = mergedCustomNotificationTexts(
            importedRunning = null,
            importedStopped = "已断开",
            storedRunning = "旧的运行文案",
            storedStopped = "旧的停止文案"
        )
        assertEquals("旧的运行文案", merged?.first)
        assertEquals("已断开", merged?.second)
    }

    @Test
    fun bothTextsExportedAreBothApplied() {
        val merged = mergedCustomNotificationTexts(
            importedRunning = "运行中",
            importedStopped = "已停止",
            storedRunning = "旧的运行文案",
            storedStopped = "旧的停止文案"
        )
        assertEquals("运行中", merged?.first)
        assertEquals("已停止", merged?.second)
    }

    @Test
    fun aBackupWithNeitherFieldLeavesLocalSettingsUntouched() {
        // Both null means the fields are absent from the file, so the import must
        // not overwrite the local customisation with empty text.
        assertNull(
            mergedCustomNotificationTexts(
                importedRunning = null,
                importedStopped = null,
                storedRunning = "旧的运行文案",
                storedStopped = "旧的停止文案"
            )
        )
    }

    @Test
    fun anEmptyImportedStringIsStillAnExplicitValue() {
        // The parser maps "" to null, but a caller that passes "" means "clear
        // this field"; only null is treated as absent.
        val merged = mergedCustomNotificationTexts(
            importedRunning = "",
            importedStopped = null,
            storedRunning = "旧的运行文案",
            storedStopped = "旧的停止文案"
        )
        assertEquals("", merged?.first)
        assertEquals("旧的停止文案", merged?.second)
    }
}
