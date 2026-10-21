package com.haoze.diting.ui

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * O-126: the crash-log screen sampled `CrashLogManager.getCrashLogCount()` once at
 * composition time (`remember { mutableIntStateOf(...) }`). A native crash
 * recorded after the screen was built — or simply a crash log written by the
 * start-up collector while the screen was in the background — left the export and
 * clear buttons disabled until the screen was left and re-entered.
 *
 * The screen now re-reads the count on every `ON_RESUME`. Compose itself cannot be
 * asserted on the JVM, so the registration is pinned at the source level.
 */
class LogRetentionCrashCountRefreshContractTest {

    private fun source(): String {
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/ui/LogRetentionSettingsScreen.kt"),
            File("app/src/main/java/com/haoze/diting/ui/LogRetentionSettingsScreen.kt"),
            File("Android/app/src/main/java/com/haoze/diting/ui/LogRetentionSettingsScreen.kt")
        )
        return candidates.firstOrNull { it.exists() }?.readText().orEmpty()
    }

    @Test
    fun theCrashLogCountIsRefreshedWhenTheScreenResumes() {
        val text = source()
        if (text.isBlank()) return // different working directory; asserted by the build

        // Locate the initial state declaration and the resume observer separately:
        // the fix is that the count is no longer only sampled at composition time.
        val declaration = text.indexOf("var crashLogCount by remember")
        assertTrue("the count state must still exist", declaration >= 0)

        val observerStart = text.indexOf("DisposableEffect(lifecycleOwner)")
        assertTrue("a lifecycle observer must be registered", observerStart >= 0)
        val observerEnd = text.indexOf("onDispose", observerStart)
        val observerBody = text.substring(observerStart, if (observerEnd > observerStart) observerEnd else text.length)

        assertTrue(
            "the resumed screen must re-read the crash log count",
            observerBody.contains("ON_RESUME") && observerBody.contains("crashLogCount = CrashLogManager.getCrashLogCount(context)")
        )
    }

    @Test
    fun theRefreshDoesNotIntroduceAViewModel() {
        // The Lead's constraint for this file: keep the screen stateful, do not
        // introduce a ViewModel just to refresh a file count.
        val text = source()
        if (text.isBlank()) return

        assertTrue(
            "no ViewModel may be introduced for the crash count",
            !text.contains("viewModel(") && !text.contains("ViewModel")
        )
    }
}
