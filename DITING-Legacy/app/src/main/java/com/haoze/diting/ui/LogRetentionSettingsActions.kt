package com.haoze.diting.ui

/**
 * Side effects of changing the DNS log retention window in
 * [LogRetentionSettingsScreen].
 *
 * Kept out of the composable so the ordering is unit-testable: the running VPN
 * engine caches the retention days in `DnsVpnRuntimeConfigManager` and only
 * re-reads them on a runtime-config refresh. Persisting the new value without
 * notifying the engine leaves the prune sweep on the old window until the VPN
 * is restarted — which is exactly what happened to the retention radio while
 * the log-mode radio right above it did notify.
 */
internal object LogRetentionSettingsActions {

    /**
     * Applies a new retention window: updates the local UI state, persists the
     * value for the dataset, then notifies the running engine so the next prune
     * sweep uses it.
     */
    fun applyRetentionDays(
        days: Int,
        updateState: (Int) -> Unit,
        persist: (Int) -> Unit,
        notifyRuntime: () -> Unit
    ) {
        updateState(days)
        persist(days)
        notifyRuntime()
    }
}
