package com.haoze.diting.notification

import com.haoze.diting.express.ExpressTunnelManager
import com.haoze.diting.normal.DnsVpnTunnelManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class ServiceStartupDefectFixTest {

    @Test
    fun testVpnMonitorServiceConstants() {
        assertEquals(1002, VpnMonitorService.NOTIFICATION_ID_VPN_MONITOR)
    }

    @Test
    fun testExpressTunnelManagerUnstartedSafety() {
        val tunnelManager = ExpressTunnelManager()
        assertFalse(tunnelManager.isRunning)
        assertFalse(tunnelManager.isIpv6Active)
        assertNull(tunnelManager.vpnInterface)

        // Safety on unstarted operations
        tunnelManager.stop()
        tunnelManager.clearCache()
        assertFalse(tunnelManager.isRunning)
    }

    @Test
    fun testDnsVpnTunnelManagerUnstartedSafety() {
        val tunnelManager = DnsVpnTunnelManager()
        assertFalse(tunnelManager.isIpv6Active)
        assertNull(tunnelManager.vpnInterface)
        assertNull(tunnelManager.goInspectionTunnel)

        // Safety on unstarted operations
        tunnelManager.stopInspectionDataPlane()
        tunnelManager.disconnectVpnInterface()
        assertFalse(tunnelManager.isIpv6Active)
    }
}
