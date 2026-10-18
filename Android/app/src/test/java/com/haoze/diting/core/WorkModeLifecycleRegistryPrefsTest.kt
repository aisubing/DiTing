package com.haoze.diting.core

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * O-145: the default `updateNormalFloatingLogAppState` lambda wrote
 * `main_activity_foreground` into a shared-preferences file named
 * `system_settings`. No reader anywhere uses that file — the real store is
 * `SystemSettingsStore`, whose prefs file is `dns_vpn_prefs` — so the write was a
 * dead side channel that looked authoritative.
 *
 * Two properties are pinned here:
 *  - the registry no longer names that dead preferences file;
 *  - the surviving behaviour (dispatch the state to a running
 *    `DnsVpnService` via an intent, which is what actually persists it) is intact.
 *
 * Source-level because both the registry and the service need Android classes.
 */
class WorkModeLifecycleRegistryPrefsTest {

    private fun registrySource(): String {
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/core/WorkModeLifecycleRegistry.kt"),
            File("app/src/main/java/com/haoze/diting/core/WorkModeLifecycleRegistry.kt"),
            File("Android/app/src/main/java/com/haoze/diting/core/WorkModeLifecycleRegistry.kt")
        )
        return candidates.firstOrNull { it.exists() }?.readText().orEmpty()
    }

    private fun codeLines(source: String): List<String> = source.lines()
        .map { it.trim() }
        .filterNot { it.isEmpty() }
        .filterNot { it.startsWith("//") || it.startsWith("*") || it.startsWith("/*") }

    @Test
    fun theDeadPreferencesFileIsNoLongerWritten() {
        val source = registrySource()
        if (source.isBlank()) return // different working directory; asserted by the build

        // A quoted prefs name is what `getSharedPreferences` needs; the only
        // remaining mention may be a comment explaining the removal.
        val code = codeLines(source).filterNot { it.contains("//") }
        assertTrue(
            "the registry must not open a second preferences file: $code",
            code.none { it.contains("\"system_settings\"") && it.contains("getSharedPreferences") }
        )
        assertTrue(
            "no shared-preferences write may remain in the registry",
            code.none { it.contains("getSharedPreferences") && it.contains("putBoolean") }
        )
    }

    @Test
    fun theForegroundStateIsStillForwardedToTheRunningService() {
        val source = registrySource()
        if (source.isBlank()) return

        // The default lambda replaces itself with DnsVpnService's implementation
        // once that service is loaded; the dispatch intent is the fallback path
        // and must survive.
        val index = source.indexOf("var updateNormalFloatingLogAppState")
        assertTrue("the hook must still exist", index >= 0)
        // Slice to the end of the declaration rather than a fixed character
        // budget: the explanatory comment above the lambda is longer than the
        // code, so a fixed window would stop before the dispatch.
        val end = source.indexOf("fun refreshFloatingLogOverlay", index)
        val body = source.substring(index, if (end < 0) source.length else end)
        assertTrue("a running normal service must still be detected", body.contains("VpnStateRegistry.isNormalRunning"))
        assertTrue("the state must still be dispatched as an intent", body.contains("startService"))
        assertTrue("the extra key must survive", body.contains("app_foreground"))
    }

    @Test
    fun theRealStoreUsesTheDnsVpnPreferencesFile() {
        // The reason the removed write was dead: the authoritative store reads a
        // different file. If this ever changes, the removal must be revisited.
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/ui/settings/SettingsPreferencesExtensions.kt"),
            File("app/src/main/java/com/haoze/diting/ui/settings/SettingsPreferencesExtensions.kt"),
            File("Android/app/src/main/java/com/haoze/diting/ui/settings/SettingsPreferencesExtensions.kt")
        )
        val source = candidates.firstOrNull { it.exists() }?.readText().orEmpty()
        if (source.isBlank()) return
        assertTrue(
            "the authoritative store must still read dns_vpn_prefs",
            codeLines(source).any { it.contains("PREFS_NAME = \"dns_vpn_prefs\"") }
        )
    }
}
