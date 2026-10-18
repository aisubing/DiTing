package com.haoze.diting.normal

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-012: "AUTO" IPv6 mode used to treat a global-unicast IPv6 *address* as
 * sufficient, because the route check result was OR-ed with it:
 * `hasIpv6Route || hasGlobalIpv6` is always true once a GUA exists, so the route
 * probe was dead code. A network that hands out a 2000::/3 address but no IPv6
 * route then enabled IPv6 on the TUN interface with no working default route.
 */
class DnsVpnTunnelManagerIpv6UsableTest {

    @Test
    fun globalAddressWithoutRouteIsNotUsable() {
        assertFalse(
            "A GUA address alone must not enable IPv6",
            DnsVpnTunnelManager.isIpv6Usable(hasGlobalIpv6Address = true, hasIpv6Route = false)
        )
    }

    @Test
    fun routeWithoutGlobalAddressIsNotUsable() {
        assertFalse(
            DnsVpnTunnelManager.isIpv6Usable(hasGlobalIpv6Address = false, hasIpv6Route = true)
        )
    }

    @Test
    fun globalAddressWithRouteIsUsable() {
        assertTrue(
            DnsVpnTunnelManager.isIpv6Usable(hasGlobalIpv6Address = true, hasIpv6Route = true)
        )
    }

    @Test
    fun noAddressAndNoRouteIsNotUsable() {
        assertFalse(
            DnsVpnTunnelManager.isIpv6Usable(hasGlobalIpv6Address = false, hasIpv6Route = false)
        )
    }
}
