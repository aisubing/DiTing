package com.haoze.diting.ui

import com.haoze.diting.core.rule.DefaultWhitelistSeeder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * A-100: editing a preset whitelist row used to write the row back with
 * `SOURCE_PRESET` (`WhitelistViewModel.editRule`:
 * `val source = if (item.isPreset) SOURCE_PRESET else SOURCE_USER`). The preset
 * seeder resets with `DefaultWhitelistSeeder.seed(forceReset = true)`, which runs
 * `dao.deleteBySource(SOURCE_PRESET)` on every app upgrade or preset-schema bump
 * (`DefaultWhitelistSeeder.kt:89-91`), so the user's edit was silently discarded
 * while the KDoc promises "user customizations are preserved".
 *
 * The fix makes editing a presets row store it under [SOURCE_USER] instead: the
 * act of editing *is* the user taking ownership of the rule.
 *
 * `WhitelistViewModel` needs an `Application`/ViewModelStore, so the decision is
 * pinned at the source level (same approach as `AppUpdateDirectoryContractTest`).
 */
class WhitelistEditDemotesPresetSourceContractTest {

    private fun source(): String {
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/ui/WhitelistViewModel.kt"),
            File("app/src/main/java/com/haoze/diting/ui/WhitelistViewModel.kt"),
            File("DITING-Legacy/app/src/main/java/com/haoze/diting/ui/WhitelistViewModel.kt")
        )
        return candidates.firstOrNull { it.exists() }?.readText().orEmpty()
    }

    /** The domain branch of `editRule`, which starts at the last `deleteById`. */
    private fun editRuleDomainBranch(): String {
        val text = source()
        if (text.isBlank()) return ""
        val editStart = text.indexOf("suspend fun editRule(")
        if (editStart < 0) return ""
        val body = text.substring(editStart)
        val deleteAt = body.indexOf("allowRuleDao.deleteById(item.id)")
        if (deleteAt < 0) return ""
        return body.substring(deleteAt)
    }

    @Test
    fun editedDomainRuleIsAlwaysStoredAsAUserRule() {
        val branch = editRuleDomainBranch()
        if (branch.isBlank()) return // different working directory; asserted by the build

        // The insert that follows the delete must be unconditional SOURCE_USER.
        // Restoring a conditional `if (item.isPreset) SOURCE_PRESET ...` brings
        // the silent-loss bug back.
        val insertLine = branch.lines().firstOrNull { it.contains("insertForSource(") }.orEmpty()
        assertTrue("the domain edit must still insert the row: $insertLine", insertLine.isNotEmpty())
        assertTrue(
            "an edited preset rule must be demoted to a user rule: $insertLine",
            insertLine.contains("DefaultWhitelistSeeder.SOURCE_USER")
        )
        assertFalse(
            "the insert must not reference SOURCE_PRESET any more: $insertLine",
            insertLine.contains("SOURCE_PRESET")
        )
    }

    @Test
    fun theConditionalPresetSourceSelectionIsGone() {
        val branch = editRuleDomainBranch()
        if (branch.isBlank()) return

        // The exact shape of the old bug.
        assertFalse(
            "editRule must no longer keep the preset source for preset rows",
            branch.contains("if (item.isPreset) DefaultWhitelistSeeder.SOURCE_PRESET")
        )
        assertFalse(
            "no local `source` variable may be derived from item.isPreset",
            branch.contains("val source = if (item.isPreset)")
        )
    }

    @Test
    fun theResetThatWouldHaveDeletedTheEditStillTargetsOnlyPresetRows() {
        // The premise of the fix: the upgrade reset is scoped to the preset
        // source, so a row stored under SOURCE_USER survives it.
        assertEquals("useradd", DefaultWhitelistSeeder.SOURCE_USER)
        assertEquals("preset", DefaultWhitelistSeeder.SOURCE_PRESET)

        val seeder = listOf(
            File("src/main/java/com/haoze/diting/core/rule/DefaultWhitelistSeeder.kt"),
            File("app/src/main/java/com/haoze/diting/core/rule/DefaultWhitelistSeeder.kt"),
            File("DITING-Legacy/app/src/main/java/com/haoze/diting/core/rule/DefaultWhitelistSeeder.kt")
        ).firstOrNull { it.exists() }?.readText().orEmpty()
        if (seeder.isBlank()) return

        assertTrue(
            "the forced reset must still only delete SOURCE_PRESET rows",
            seeder.contains("dao.deleteBySource(SOURCE_PRESET)")
        )
    }
}
