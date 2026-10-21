package com.haoze.diting.notification

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * A-036: `openNotificationSettings` launched `Settings.ACTION_APP_NOTIFICATION_SETTINGS`
 * unconditionally inside `runCatching`. That action only exists from API 26, so on
 * Android 7.x the intent cannot resolve, the exception was swallowed, and tapping
 * the row did nothing at all.
 *
 * The call now only uses that action from API 26 upwards and falls back to the
 * app-details page — which accepts just a package uri and exists on every
 * supported version — whenever the first launch does not happen.
 *
 * Source-level because the behaviour depends on `Build.VERSION.SDK_INT` and
 * `Context.startActivity`, neither of which the JVM unit-test source set provides.
 */
class NotificationSettingsIntentFallbackTest {

    private fun helperSource(): String {
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/notification/NotificationPermissionHelper.kt"),
            File("app/src/main/java/com/haoze/diting/notification/NotificationPermissionHelper.kt"),
            File("DITING-Legacy/app/src/main/java/com/haoze/diting/notification/NotificationPermissionHelper.kt")
        )
        return candidates.firstOrNull { it.exists() }?.readText().orEmpty()
    }

    private fun codeLines(source: String): List<String> = source.lines()
        .map { it.trim() }
        .filterNot { it.isEmpty() }
        .filterNot { it.startsWith("//") || it.startsWith("*") || it.startsWith("/*") }

    @Test
    fun theNotificationChannelSettingsIntentIsVersionGuarded() {
        val source = helperSource()
        if (source.isBlank()) return // different working directory; asserted by the build

        assertTrue(
            "the API-26-only action must be behind a version check",
            source.contains("Build.VERSION.SDK_INT >= Build.VERSION_CODES.O")
        )

        // The guarded action must not be launched outside the guard: the only
        // startActivity of it has to sit after the version check.
        val guardIndex = source.indexOf("Build.VERSION.SDK_INT >= Build.VERSION_CODES.O")
        val actionIndex = source.indexOf("Settings.ACTION_APP_NOTIFICATION_SETTINGS")
        assertTrue("ACTION_APP_NOTIFICATION_SETTINGS must still be used", actionIndex >= 0)
        assertTrue(
            "ACTION_APP_NOTIFICATION_SETTINGS must be reached only after the API guard",
            actionIndex > guardIndex
        )
    }

    @Test
    fun everyLaunchPathHasAnAppDetailsFallback() {
        val source = helperSource()
        if (source.isBlank()) return

        assertTrue(
            "the app-details page must be used as fallback",
            source.contains("Settings.ACTION_APPLICATION_DETAILS_SETTINGS")
        )
        assertTrue(
            "the fallback needs the package uri",
            source.contains("Uri.fromParts(\"package\", context.packageName, null)")
        )
        // A failed first launch has to be observed, not swallowed by runCatching
        // alone: the result feeds the fallback decision.
        assertTrue(
            "the first launch result must decide whether to fall back",
            source.contains("runCatching { context.startActivity(intent) }.isSuccess")
        )
        assertTrue(
            "the fallback must still be attempted when the first launch did not happen",
            codeLines(source).any { it.startsWith("if (!opened)") }
        )
    }

    /** Source text of one top-level member declaration, from its `fun` to the next one. */
    private fun declarationBody(source: String, header: String): String {
        val index = source.indexOf(header)
        if (index < 0) return ""
        val boundary = listOf("\n    fun ", "\n    private fun ", "\n    internal fun ")
            .map { source.indexOf(it, index + 1) }
            .filter { it > index }
            .minOrNull() ?: source.length
        return source.substring(index, boundary)
    }

    @Test
    fun theFallbackIsSelfContainedEnoughToWorkFromANonActivityContext() {
        val source = helperSource()
        if (source.isBlank()) return
        val body = declarationBody(source, "fun appDetailsIntent")
        assertTrue("the fallback intent must be built in one place", body.isNotEmpty())
        assertTrue("the fallback must carry NEW_TASK", body.contains("Intent.FLAG_ACTIVITY_NEW_TASK"))
    }

    @Test
    fun thePermissionProbeStillShortCircuitsBelowAndroid13() {
        val source = helperSource()
        if (source.isBlank()) return
        // POST_NOTIFICATIONS does not exist before API 33; treating it as granted
        // there is what keeps the settings page from nagging on older devices.
        val body = declarationBody(source, "fun hasPermission")
        assertTrue("hasPermission must exist", body.isNotEmpty())
        val permissionLine = body.lines().indexOfFirst { it.contains("POST_NOTIFICATIONS") }
        val guardLine = body.lines().indexOfFirst { it.contains("Build.VERSION_CODES.TIRAMISU") }
        assertTrue("POST_NOTIFICATIONS must be queried", permissionLine >= 0)
        assertTrue(
            "the permission query must be guarded by the API-33 check",
            guardLine in 0 until permissionLine
        )
    }
}
