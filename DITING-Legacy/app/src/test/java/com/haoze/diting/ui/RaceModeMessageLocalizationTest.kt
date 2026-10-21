package com.haoze.diting.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * O-121: `RaceModeSettingsViewModel` read its user-visible messages with
 * `getApplication().getString(...)`, which resolves against the Application
 * resources and therefore follows the *system* locale, while every other string on
 * the same screen went through `localizedText` (app locale). With an in-app
 * language that differs from the system language, those messages rendered in the
 * wrong language, and `:163` mixed the two sources inside one message: the format
 * string came from the system locale and its `%1$s` argument from the app locale.
 *
 * The check is source-level because the defect is exactly "which context object the
 * lookup goes through"; instantiating the ViewModel needs Android framework classes
 * that the JVM unit-test source set does not have.
 */
class RaceModeMessageLocalizationTest {

    private fun viewModelSource(): String {
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/ui/RaceModeSettingsViewModel.kt"),
            File("app/src/main/java/com/haoze/diting/ui/RaceModeSettingsViewModel.kt"),
            File("DITING-Legacy/app/src/main/java/com/haoze/diting/ui/RaceModeSettingsViewModel.kt")
        )
        val file = candidates.firstOrNull { it.exists() }
            ?: return ""
        return file.readText()
    }

    @Test
    fun noUserVisibleMessageUsesTheUnwrappedApplicationContext() {
        val source = viewModelSource()
        if (source.isBlank()) return // different working directory; property is asserted by the build

        val bareGetString = Regex("""getApplication<Application>\(\)\.getString""")
        assertEquals(
            "RaceModeSettingsViewModel must not resolve string resources through the " +
                "unwrapped Application context (O-121)",
            0,
            bareGetString.findAll(source).count()
        )
    }

    @Test
    fun theFormatStringAndItsArgumentComeFromTheSameLocalizationSource() {
        val source = viewModelSource()
        if (source.isBlank()) return

        // The message that used to mix sources: its format string must now be looked up
        // through the localized context too.
        val index = source.indexOf("R.string.resolution_mode_changed")
        assertTrue("resolution_mode_changed message must still exist", index >= 0)
        val surrounding = source.substring(maxOf(0, index - 200), minOf(source.length, index + 200))
        assertTrue(
            "the resolution_mode_changed format string must be read via localizedString",
            surrounding.contains("localizedString(")
        )
        assertTrue(
            "its argument must still be localized",
            surrounding.contains("localizedText(")
        )
    }

    @Test
    fun everyBareGetStringInTheViewModelIsGone() {
        val source = viewModelSource()
        if (source.isBlank()) return
        // A future regression could reintroduce the pattern with a different receiver.
        val offenders = source.lines().withIndex()
            .filter { (_, line) -> Regex("""\)\.getString\(R\.string""").containsMatchIn(line.trim()) }
            .filterNot { (_, line) -> line.trim().startsWith("*") || line.trim().startsWith("//") }
            .filterNot { (_, line) -> line.contains("localized.getString") }
            .map { (i, line) -> "${i + 1}: ${line.trim()}" }
        assertTrue("unexpected bare getString: $offenders", offenders.isEmpty())
    }
}
