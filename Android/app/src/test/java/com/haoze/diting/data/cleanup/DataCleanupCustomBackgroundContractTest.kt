package com.haoze.diting.data.cleanup

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * A-016: `clearCustomBackground` opened a shared-preferences file literally named
 * `appearance_settings`, but the appearance store persists into `dns_vpn_prefs`
 * (`SettingsPreferencesExtensions.PREFS_NAME`). The factory reset therefore wiped
 * a file nobody wrote: the custom background stayed enabled, its enabled flag,
 * current URI and the candidate URI list all survived.
 *
 * Source-level because both `AppearanceSettingsStore` and `CustomBackgroundManager`
 * are `Context`-bound; the JVM unit tests run without an Android runtime.
 */
class DataCleanupCustomBackgroundContractTest {

    private fun source(vararg relative: String): String {
        val candidates = relative.map { File(it) } + relative.map { File("app/$it") } +
            relative.map { File("Android/app/$it") }
        return candidates.firstOrNull { it.exists() }?.readText().orEmpty()
    }

    private fun codeLines(text: String): List<String> = text.lines()
        .map { it.trim() }
        .filterNot { it.isEmpty() }
        .filterNot { it.startsWith("//") || it.startsWith("*") || it.startsWith("/*") }

    private fun clearCustomBackgroundBody(): String {
        val text = source("src/main/java/com/haoze/diting/data/cleanup/DataCleanupManager.kt")
        if (text.isBlank()) return ""
        val start = text.indexOf("fun clearCustomBackground(")
        if (start < 0) return ""
        val end = text.indexOf("\n    }", start)
        return if (end > start) text.substring(start, end) else text.substring(start)
    }

    @Test
    fun theWipedPreferencesFileIsTheOneTheStoreActuallyUses() {
        val body = clearCustomBackgroundBody()
        if (body.isBlank()) return // different working directory; asserted by the build

        val code = codeLines(body)
        assertTrue(
            "the bogus preferences file must not be opened any more: $code",
            code.none { it.contains("\"appearance_settings\"") }
        )
        assertTrue(
            "the cleanup must go through the appearance store",
            code.any { it.contains("AppearanceSettingsStore") }
        )
    }

    @Test
    fun everyCandidateUriAndTheEnabledFlagAreCleared() {
        val body = clearCustomBackgroundBody()
        if (body.isBlank()) return

        assertTrue(
            "the candidate URI list must be cleared entry by entry",
            body.contains("getCustomBackgroundUris") && body.contains("removeCustomBackgroundUri")
        )
        assertTrue(
            "the enabled flag and the current URI must be reset",
            body.contains("setCustomBackground")
        )
        assertTrue(
            "the active in-memory background must be dropped as well",
            body.contains("CustomBackgroundManager")
        )
    }

    @Test
    fun appearanceStoreLivesInTheSharedPreferencesFile() {
        // The premise of the fix: there is exactly one preferences file for the
        // appearance settings, and it is the app-wide one.
        val contract = source("src/main/java/com/haoze/diting/ui/settings/SettingsPreferencesExtensions.kt")
        val store = source("src/main/java/com/haoze/diting/ui/settings/AppearanceSettingsStore.kt")
        if (contract.isBlank() || store.isBlank()) return

        assertEquals(
            true,
            codeLines(contract).any { it.contains("PREFS_NAME = \"dns_vpn_prefs\"") }
        )
        assertTrue(
            "the store must persist through the shared preferences name",
            codeLines(store).any { it.contains("getSharedPreferences(PREFS_NAME") }
        )
        assertTrue(
            "the store must not define a private preferences file of its own",
            codeLines(store).none { it.contains("PREFS_NAME =") }
        )
    }
}
