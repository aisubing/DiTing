package com.haoze.diting.server

import com.haoze.diting.server.model.DnsListenPortMigration
import com.haoze.diting.server.model.DnsListenPortValidator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * A-022: the stored local listen port used to be rewritten on *every* config
 * read, so a port the user deliberately picked from a previous build's default
 * (5353/5354, the mDNS range the engine can never bind) was silently replaced
 * forever. [DnsListenPortMigration] is the pure decision table behind the one-shot
 * persisted migration, so it is pinned here directly.
 */
class DnsListenPortMigrationTest {

    @Test
    fun legacyMdnsPortsAreMigratedToDefault() {
        assertEquals(DnsListenPortValidator.DEFAULT_PORT, DnsListenPortMigration.migratedPort(5353))
        assertEquals(DnsListenPortValidator.DEFAULT_PORT, DnsListenPortMigration.migratedPort(5354))
    }

    @Test
    fun defaultPortIsKept() {
        assertNull(DnsListenPortMigration.migratedPort(DnsListenPortValidator.DEFAULT_PORT))
    }

    @Test
    fun deliberateUserChoicesAreKept() {
        // Any other bindable port is a real user decision and must survive.
        assertNull(DnsListenPortMigration.migratedPort(1054))
        assertNull(DnsListenPortMigration.migratedPort(8053))
        assertNull(DnsListenPortMigration.migratedPort(DnsListenPortValidator.MIN_PORT))
        assertNull(DnsListenPortMigration.migratedPort(DnsListenPortValidator.MAX_PORT))
    }

    @Test
    fun unbindableValuesAreNotTreatedAsLegacyDefaults() {
        // Out-of-range junk is a different failure mode; the display layer already
        // falls back for it, so the migration must not claim these.
        assertNull(DnsListenPortMigration.migratedPort(0))
        assertNull(DnsListenPortMigration.migratedPort(-1))
        assertNull(DnsListenPortMigration.migratedPort(53))
        assertNull(DnsListenPortMigration.migratedPort(65536))
    }
}
