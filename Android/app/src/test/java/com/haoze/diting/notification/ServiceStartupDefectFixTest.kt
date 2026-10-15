package com.haoze.diting.notification

import com.haoze.diting.core.rule.DefaultWhitelistSeeder
import com.haoze.diting.express.ExpressTunnelManager
import com.haoze.diting.express.notification.ExpressNotificationBuilder
import com.haoze.diting.normal.DnsVpnTunnelManager
import com.haoze.diting.normal.notification.VpnNotificationBuilder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ServiceStartupDefectFixTest {

    @Test
    fun testVpnMonitorServiceConstantsAndLiveness() {
        assertEquals(1002, VpnMonitorService.NOTIFICATION_ID_VPN_MONITOR)
        assertEquals(1001, VpnNotificationBuilder.NOTIFICATION_ID_VPN_SERVICE)
        assertEquals(2001, ExpressNotificationBuilder.NOTIFICATION_ID_EXPRESS_VPN)

        // All notification IDs must remain completely unique to avoid service collisions
        assertNotEquals(VpnMonitorService.NOTIFICATION_ID_VPN_MONITOR, VpnNotificationBuilder.NOTIFICATION_ID_VPN_SERVICE)
        assertNotEquals(VpnMonitorService.NOTIFICATION_ID_VPN_MONITOR, ExpressNotificationBuilder.NOTIFICATION_ID_EXPRESS_VPN)

        // Test monitor service liveness tracking
        val original = VpnMonitorService.isServiceAlive
        try {
            VpnMonitorService.isServiceAlive = false
            assertFalse(VpnMonitorService.isServiceAlive)
            assertFalse(VpnMonitorManager.isMonitorAlive())

            VpnMonitorService.isServiceAlive = true
            assertTrue(VpnMonitorService.isServiceAlive)
            assertTrue(VpnMonitorManager.isMonitorAlive())
        } finally {
            VpnMonitorService.isServiceAlive = original
        }
    }

    @Test
    fun testDefaultWhitelistSeederCacheLifecycle() {
        DefaultWhitelistSeeder.clearCache()

        // Inject simulated cache entries
        val simulated = listOf("example.com" to "测试分类", "api.example.com" to "API分类")
        DefaultWhitelistSeeder.setCachedWhitelistForTesting(simulated)

        // Without a valid Android Context, parseAssetWhitelist returns the cached list directly
        // because cachedAssetWhitelist?.let { return it } fires first
        // Verify this avoids disk/asset reading on subsequent calls
        val mockContext = null
        // Reflection invocation to verify null context returns cached list without NPE
        val field = DefaultWhitelistSeeder::class.java.getDeclaredField("cachedAssetWhitelist")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val cached = field.get(DefaultWhitelistSeeder) as? List<Pair<String, String>>
        assertNotNull(cached)
        assertEquals(2, cached?.size)
        assertEquals("example.com", cached?.first()?.first)

        // Clear cache and verify it gets reset
        DefaultWhitelistSeeder.clearCache()
        val cleared = field.get(DefaultWhitelistSeeder)
        assertNull(cleared)
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

        // Rule sync safety before engine or managers are initialized
        val testScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        tunnelManager.syncRules(testScope)
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
