package com.haoze.diting.server.model

/**
 * Master switch for DNS mode domain filtering (`DnsModeConfig.adBlockEnabled`).
 *
 * DNS mode sets the switch in three different places (the Go `filterDNS` flag,
 * the standalone rule snapshot's `filterEnabled`, and the Kotlin policy
 * decision path), but only the Go VPN path ever read it back. Keeping the value
 * in one object that all three consumers read is what stops the paths from
 * drifting apart again — previously the snapshot carried a hardcoded `true`, so
 * turning filtering off left the standalone server blocking anyway.
 *
 * Deliberately free of Android dependencies so unit tests can exercise it.
 */
class DnsFilterMasterSwitch(enabled: Boolean = true) {

    @Volatile
    private var enabledState: Boolean = enabled

    fun isEnabled(): Boolean = enabledState

    /** Returns whether the value actually changed, so callers can skip resyncs. */
    fun set(enabled: Boolean): Boolean {
        if (enabledState == enabled) return false
        enabledState = enabled
        return true
    }

    /**
     * Value placed in the Go rule snapshot's `filterEnabled` field. The Go
     * policy engine treats a disabled snapshot as "no rule matches", so this is
     * the field that makes the switch effective on the standalone path.
     */
    fun snapshotFilterEnabled(): Boolean = enabledState
}
