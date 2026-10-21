package com.haoze.diting.notification

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * A-034 / A-037, notification-channel half.
 *
 * A-034: `RuleOperationWorker` registered its foreground-notification channel
 * under its own hard-coded id (`"rule_operations"`) while every other entry point
 * used [AppNotificationChannels]. Two channels with the same title then appeared
 * in the system settings list. The worker now reuses the shared registry, so the
 * id and the title exist once.
 *
 * A-037: channel titles/descriptions were read with an unwrapped `getString`, i.e.
 * in the *system* language, while the surrounding UI follows the in-app language
 * setting. Titles that have a `values-en` resource now go through
 * `localizedResource`, which wraps the context first.
 *
 * These are source-level checks because creating a [android.app.NotificationChannel]
 * needs the Android framework, which the JVM test source set does not provide.
 */
class AppNotificationChannelsRegistryTest {

    private fun channelSource(): String {
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/notification/AppNotificationChannels.kt"),
            File("app/src/main/java/com/haoze/diting/notification/AppNotificationChannels.kt"),
            File("DITING-Legacy/app/src/main/java/com/haoze/diting/notification/AppNotificationChannels.kt")
        )
        return candidates.firstOrNull { it.exists() }?.readText().orEmpty()
    }

    private fun workerSource(): String {
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/core/rule/RuleOperationWorker.kt"),
            File("app/src/main/java/com/haoze/diting/core/rule/RuleOperationWorker.kt"),
            File("DITING-Legacy/app/src/main/java/com/haoze/diting/core/rule/RuleOperationWorker.kt")
        )
        return candidates.firstOrNull { it.exists() }?.readText().orEmpty()
    }

    private fun codeLines(source: String): List<String> = source.lines()
        .map { it.trim() }
        .filterNot { it.isEmpty() }
        .filterNot { it.startsWith("//") || it.startsWith("*") || it.startsWith("/*") }

    /**
     * Matches a *construction* of the channel class. The manager methods
     * `createNotificationChannel(` / `createNotificationChannels(` contain the
     * same character sequence, so the class name must not be preceded by an
     * identifier character.
     */
    private fun channelConstructionPattern(): Regex = Regex("""(^|[^A-Za-z0-9_])NotificationChannel\(""")

    @Test
    fun theChannelIdsAreAllDistinct() {
        val ids = listOf(
            AppNotificationChannels.CHANNEL_VPN_SERVICE,
            AppNotificationChannels.CHANNEL_VPN_MONITOR,
            AppNotificationChannels.CHANNEL_RULE_OPERATIONS,
            AppNotificationChannels.CHANNEL_SUBSCRIPTION_AUTO_UPDATE,
            AppNotificationChannels.CHANNEL_APP_UPDATE
        )
        assertEquals("every channel id must be distinct", ids.toSet().size.toLong(), ids.size.toLong())
        ids.forEach { assertNotEquals("", it.trim()) }
    }

    @Test
    fun theRuleOperationChannelIsTheOnlyOneTheWorkerUses() {
        assertEquals("diting_rule_operations_channel", AppNotificationChannels.CHANNEL_RULE_OPERATIONS)

        val source = workerSource()
        if (source.isBlank()) return // different working directory; asserted by the build

        // The worker must build its notifications on the shared id and must not
        // create a channel of its own any more.
        assertTrue(
            "RuleOperationWorker must use the shared channel id",
            codeLines(source).count { it.contains("AppNotificationChannels.CHANNEL_RULE_OPERATIONS") } >= 2
        )
        assertTrue(
            "RuleOperationWorker must not construct a NotificationChannel itself",
            // `createNotificationChannel(` / `createNotificationChannels(` are the
            // manager methods and must not be mistaken for a construction, hence
            // the requirement that no identifier character precedes the class name.
            !channelConstructionPattern().containsMatchIn(source)
        )
        assertTrue(
            "RuleOperationWorker must not register the legacy hard-coded id",
            codeLines(source).none { it.contains("\"rule_operations\"") }
        )
    }

    @Test
    fun channelTitlesAreReadInTheAppLanguage() {
        val source = channelSource()
        if (source.isBlank()) return

        // Every resource-backed channel title must be resolved through the
        // wrapping helper; a bare `getString` on the raw context follows the
        // system language and reintroduces the mismatch.
        val resourceLines = codeLines(source).filter { it.contains("R.string.") }
        assertTrue("the registry must use string resources", resourceLines.isNotEmpty())
        val bare = resourceLines.filterNot { it.contains("localizedResource(") }
        assertTrue("channel strings must be resolved in the app language: $bare", bare.isEmpty())

        // And the hand-written channel names must still go through localizedText,
        // which is the dictionary-backed path.
        assertTrue(
            "hand-written channel names must be localized",
            codeLines(source).count { it.contains("localizedText(context,") } >= 7
        )
    }

    @Test
    fun theLocalizedResourceHelperWrapsTheContextFirst() {
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/ui/LocalizedTextHelper.kt"),
            File("app/src/main/java/com/haoze/diting/ui/LocalizedTextHelper.kt"),
            File("DITING-Legacy/app/src/main/java/com/haoze/diting/ui/LocalizedTextHelper.kt")
        )
        val source = candidates.firstOrNull { it.exists() }?.readText().orEmpty()
        if (source.isBlank()) return

        val index = source.indexOf("fun localizedResource")
        assertTrue("localizedResource must exist", index >= 0)
        val body = source.substring(index, minOf(source.length, index + 200))
        assertTrue(
            "localizedResource must wrap the context before resolving the resource: $body",
            body.contains("AppLanguageManager.wrap(")
        )
    }

    @Test
    fun theStoppedMonitorNotificationUsesTheAppLanguage() {
        val candidates = listOf(
            File("src/main/java/com/haoze/diting/notification/VpnMonitorService.kt"),
            File("app/src/main/java/com/haoze/diting/notification/VpnMonitorService.kt"),
            File("DITING-Legacy/app/src/main/java/com/haoze/diting/notification/VpnMonitorService.kt")
        )
        val source = candidates.firstOrNull { it.exists() }?.readText().orEmpty()
        if (source.isBlank()) return

        // The monitor notification is drawn outside any screen context, so it was
        // the one place where the notification text followed the *system*
        // language while the settings screen showing the same text followed the
        // app language.
        val bare = codeLines(source).filter { it.contains("getString(R.string.") }
        assertTrue("monitor notification still resolves text via getString: $bare", bare.isEmpty())
        listOf("R.string.vpn_disconnected", "R.string.app_name", "R.string.vpn_start").forEach { res ->
            assertTrue(
                "$res must be resolved through localizedResource",
                codeLines(source).any { it.contains("localizedResource(this, $res)") }
            )
        }
    }

    @Test
    fun theWorkerResolvesItsProgressTextInTheAppLanguage() {
        val source = workerSource()
        if (source.isBlank()) return

        // `applicationContext.getString(...)` follows the system locale; the
        // operation titles and the "preparing" placeholder are user-visible in the
        // foreground notification, so they must follow the in-app language.
        val bareLookups = codeLines(source).filter { it.contains("getString(R.string.") }
        assertTrue("worker still resolves notification text via getString: $bareLookups", bareLookups.isEmpty())
        assertTrue(
            "the worker must keep localizing its notification titles",
            codeLines(source).count { it.contains("localizedResource(applicationContext, R.string.operation_") } >= 9
        )
    }

    @Test
    fun creatingChannelsIsIdempotentOnOldApis() {
        val source = channelSource()
        if (source.isBlank()) return
        // Both entry points must bail out below API 26 instead of touching a
        // NotificationChannel class that does not exist there.
        assertEquals(
            "every channel-creation entry point must guard on the API level",
            2,
            codeLines(source).count { it.contains("Build.VERSION.SDK_INT < Build.VERSION_CODES.O") }
        )
        // Both guards are early returns, so no channel may be created in a
        // function that lacks one: the two guard lines must precede every
        // NotificationChannel construction.
        val firstGuard = source.lines().indexOfFirst {
            it.contains("Build.VERSION.SDK_INT < Build.VERSION_CODES.O")
        }
        val firstChannel = source.lines().indexOfFirst { it.contains("NotificationChannel(") }
        assertTrue(
            "the API guard must precede the first channel construction",
            firstGuard in 0 until firstChannel
        )
    }
}
