package com.haoze.diting.server

import com.haoze.diting.server.model.DnsFilterMasterSwitch
import com.haoze.diting.server.model.DnsListenPortValidator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for DNS mode defect fixes:
 * - A-084: LAN access instructions must use the configured listen port.
 * - A-020: the filtering master switch must reach the rule snapshot.
 */
class DnsModePortAndFilterSwitchTest {

    // ---- A-084: configured listen port instead of a hardcoded 1053 ----

    @Test
    fun `formatEndpoints uses the configured port for every address`() {
        val ips = listOf("192.168.1.10", "10.0.0.5")
        assertEquals("192.168.1.10:1053 / 10.0.0.5:1053", DnsListenPortValidator.formatEndpoints(ips, 1053))
        // The whole point of the fix: a changed port must show up in the copy.
        assertEquals("192.168.1.10:5353 / 10.0.0.5:5353", DnsListenPortValidator.formatEndpoints(ips, 5353))
        assertEquals("192.168.1.10:6000, 10.0.0.5:6000", DnsListenPortValidator.formatEndpoints(ips, 6000, ", "))
    }

    @Test
    fun `formatEndpoints renders nothing for an empty address list`() {
        assertEquals("", DnsListenPortValidator.formatEndpoints(emptyList(), 1053))
    }

    @Test
    fun `formatEndpoint appends the configured port`() {
        assertEquals("192.168.1.10:1053", DnsListenPortValidator.formatEndpoint("192.168.1.10", 1053))
        assertEquals("192.168.1.10:2053", DnsListenPortValidator.formatEndpoint("192.168.1.10", 2053))
    }

    @Test
    fun `displayPort keeps a valid port and falls back to the default otherwise`() {
        assertEquals(1053, DnsListenPortValidator.displayPort(1053))
        assertEquals(65535, DnsListenPortValidator.displayPort(65535))
        assertEquals(1024, DnsListenPortValidator.displayPort(1024))
        // Values the engine can never bind must not be advertised to LAN clients.
        assertEquals(DnsListenPortValidator.DEFAULT_PORT, DnsListenPortValidator.displayPort(0))
        assertEquals(DnsListenPortValidator.DEFAULT_PORT, DnsListenPortValidator.displayPort(53))
        assertEquals(DnsListenPortValidator.DEFAULT_PORT, DnsListenPortValidator.displayPort(65536))
        assertEquals(DnsListenPortValidator.DEFAULT_PORT, DnsListenPortValidator.displayPort(-1))
    }

    @Test
    fun `accessInstruction splices the configured port`() {
        assertTrue(DnsListenPortValidator.accessInstruction(1053).contains("1053"))
        assertTrue(DnsListenPortValidator.accessInstruction(5353).contains("5353"))
        assertFalse(DnsListenPortValidator.accessInstruction(5353).contains("1053"))
    }

    @Test
    fun `noVpnDisclaimer splices the configured port`() {
        assertTrue(DnsListenPortValidator.noVpnDisclaimer(1053).contains("本地 1053 端口"))
        assertTrue(DnsListenPortValidator.noVpnDisclaimer(6000).contains("本地 6000 端口"))
        assertFalse(DnsListenPortValidator.noVpnDisclaimer(6000).contains("1053"))
    }

    @Test
    fun `instruction helpers fall back to the default port for unbindable values`() {
        assertTrue(DnsListenPortValidator.accessInstruction(53).contains("1053"))
        assertTrue(DnsListenPortValidator.noVpnDisclaimer(0).contains("1053"))
    }

    @Test
    fun `isBindable accepts exactly the bindable range`() {
        assertTrue(DnsListenPortValidator.isBindable(1024))
        assertTrue(DnsListenPortValidator.isBindable(1053))
        assertTrue(DnsListenPortValidator.isBindable(65535))
        assertFalse(DnsListenPortValidator.isBindable(1023))
        assertFalse(DnsListenPortValidator.isBindable(53))
        assertFalse(DnsListenPortValidator.isBindable(0))
        assertFalse(DnsListenPortValidator.isBindable(-1))
        assertFalse(DnsListenPortValidator.isBindable(65536))
    }

    @Test
    fun `a usable port produces no warning`() {
        // The normal case must add no extra UI at all.
        assertNull(DnsListenPortValidator.unusablePortWarning(1053))
        assertNull(DnsListenPortValidator.unusablePortWarning(1024))
        assertNull(DnsListenPortValidator.unusablePortWarning(65535))
    }

    @Test
    fun `a silent fallback is never allowed - an unusable port must warn`() {
        // Regression guard for the review finding: falling back to 1053 without
        // telling the user hides the misconfiguration and points their router at
        // a port the engine never bound.
        val warning = DnsListenPortValidator.unusablePortWarning(53)
        assertNotNull("an unbindable port must never fall back silently", warning)
        assertTrue(warning!!.contains("53"))
        assertTrue(warning.contains("1053"))
        assertTrue(warning.contains("不可用"))

        // ...and the displayed port must agree with the port named in the warning.
        assertEquals(1053, DnsListenPortValidator.displayPort(53))
        assertNotNull(DnsListenPortValidator.unusablePortWarning(0))
        assertNotNull(DnsListenPortValidator.unusablePortWarning(65536))
    }

    // ---- A-020: the master switch must reach the rule snapshot ----

    @Test
    fun `master switch defaults to enabled and reports changes`() {
        val switch = DnsFilterMasterSwitch()
        assertTrue(switch.isEnabled())
        assertTrue(switch.snapshotFilterEnabled())

        assertTrue("disabling must report a change so the caller resyncs", switch.set(false))
        assertFalse(switch.isEnabled())
        assertFalse("snapshot must carry the disabled state", switch.snapshotFilterEnabled())

        assertFalse("setting the same value must not report a change", switch.set(false))
        assertTrue(switch.set(true))
        assertTrue(switch.snapshotFilterEnabled())
    }

    @Test
    fun `master switch can start disabled`() {
        val switch = DnsFilterMasterSwitch(enabled = false)
        assertFalse(switch.isEnabled())
        assertFalse(switch.snapshotFilterEnabled())
    }
}
