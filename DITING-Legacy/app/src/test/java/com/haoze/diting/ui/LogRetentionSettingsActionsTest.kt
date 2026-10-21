package com.haoze.diting.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * A-082: the "自动清理时间" radio in the DNS log settings persisted the new
 * retention days but never notified the running engine, while the log-mode
 * radio directly above it did call `onRuntimeDnsSettingsChanged()`.
 *
 * `DnsVpnRuntimeConfigManager` keeps a snapshot (`activeLogRetentionDays`,
 * refreshed only on a runtime-config change), so `LogMaintenance` kept pruning
 * with the previous window until the VPN was restarted: selecting "保留 1 天"
 * deleted nothing, and selecting a longer window still deleted at the old one.
 */
class LogRetentionSettingsActionsTest {

    @Test
    fun retentionChangePersistsThenNotifiesRuntime() {
        val events = mutableListOf<String>()
        var state = 7

        LogRetentionSettingsActions.applyRetentionDays(
            days = 1,
            updateState = {
                state = it
                events += "state:$it"
            },
            persist = { events += "persist:$it" },
            notifyRuntime = { events += "notify" }
        )

        assertEquals(1, state)
        assertEquals(
            "the engine must be refreshed after the value is persisted",
            listOf("state:1", "persist:1", "notify"),
            events
        )
    }

    @Test
    fun notifyRunsEvenWhenPersistingTheSameValue() {
        var notified = 0
        LogRetentionSettingsActions.applyRetentionDays(
            days = 30,
            updateState = {},
            persist = {},
            notifyRuntime = { notified++ }
        )

        assertEquals("re-selecting the current value must still refresh the engine", 1, notified)
    }

    @Test
    fun everySupportedWindowNotifiesTheRuntime() {
        // The screen offers 1 / 7 / 30 days (logRetentionOptions).
        for (days in listOf(1, 7, 30)) {
            var persisted = -1
            var notified = false
            LogRetentionSettingsActions.applyRetentionDays(
                days = days,
                updateState = {},
                persist = { persisted = it },
                notifyRuntime = { notified = true }
            )
            assertEquals(days, persisted)
            assertEquals("days=$days must notify the runtime", true, notified)
        }
    }
}
