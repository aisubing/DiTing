package com.haoze.diting.ui.transfer

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for A-025: importing a backup that omitted 「禁止联网名单」
 * must not silently disable the blocked-apps master switch.
 *
 * Export only writes `blockedAppsEnabled` when the user ticked the list
 * (`ConfigExporter`), but `ConfigTransferParser` defaults a missing field to
 * `false` and `TransferConfigDto.blockedAppsEnabled` is a non-null `Boolean`, so
 * "not exported" and "exported as false" are indistinguishable. Applying that
 * default unconditionally turned the switch off behind the user's back.
 */
class AppRuleConfigImporterBlockedAppsSwitchTest {

    @Test
    fun `a backup without the list leaves the switch untouched`() {
        // Exported without 「禁止联网名单」: the parser yields the `false` default
        // and no packages. The switch must stay as the user left it.
        assertFalse(
            AppRuleConfigImporter.shouldApplyImportedBlockedAppsEnabled(
                hasImportedList = false,
                currentEnabled = true,
                importedEnabled = false
            )
        )
        // Even an explicit-looking `true` with no list is not a real export of
        // the switch, so it must not be applied either.
        assertFalse(
            AppRuleConfigImporter.shouldApplyImportedBlockedAppsEnabled(
                hasImportedList = false,
                currentEnabled = false,
                importedEnabled = true
            )
        )
    }

    @Test
    fun `a backup that exported the list and enabled false turns the switch off`() {
        // Reverse case: the user did tick the list, and the backup says the
        // switch was off. That is a genuine export and must be honoured.
        assertTrue(
            AppRuleConfigImporter.shouldApplyImportedBlockedAppsEnabled(
                hasImportedList = true,
                currentEnabled = true,
                importedEnabled = false
            )
        )
    }

    @Test
    fun `a backup that exported the list and enabled true turns the switch on`() {
        assertTrue(
            AppRuleConfigImporter.shouldApplyImportedBlockedAppsEnabled(
                hasImportedList = true,
                currentEnabled = false,
                importedEnabled = true
            )
        )
    }

    @Test
    fun `an already matching switch is left alone`() {
        assertFalse(
            AppRuleConfigImporter.shouldApplyImportedBlockedAppsEnabled(
                hasImportedList = true,
                currentEnabled = true,
                importedEnabled = true
            )
        )
        assertFalse(
            AppRuleConfigImporter.shouldApplyImportedBlockedAppsEnabled(
                hasImportedList = true,
                currentEnabled = false,
                importedEnabled = false
            )
        )
    }
}
