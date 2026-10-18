package com.haoze.diting.server.model

/**
 * One-shot repair for local listen ports stored by builds whose default was
 * 5353/5354. That range belongs to mDNS, so the engine could not bind it and the
 * user-visible configuration silently disagreed with the running engine.
 *
 * The rewrite happens once and is persisted, so a port the user deliberately
 * selects afterwards is honoured instead of being replaced on every read. Pure
 * and Android-free so unit tests can pin the decision table directly.
 */
object DnsListenPortMigration {
    private val LEGACY_MDNS_PORTS = setOf(5353, 5354)

    /**
     * Replacement port for a stored legacy value, or null when the stored value
     * must be kept as-is (already fine, or a user choice we do not touch).
     */
    fun migratedPort(storedPort: Int): Int? =
        if (storedPort in LEGACY_MDNS_PORTS) DnsListenPortValidator.DEFAULT_PORT else null
}
