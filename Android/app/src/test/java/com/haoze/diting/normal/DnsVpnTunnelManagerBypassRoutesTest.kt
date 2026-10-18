package com.haoze.diting.normal

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * "绕过局域网" adds [DnsVpnTunnelManager.IPV4_BYPASS_LAN_ROUTES] as direct routes,
 * so every IPv4 address NOT covered by those routes is forced through the TUN
 * and stays under DNS filtering / MITM / UID blocking / traffic accounting.
 *
 * The complement is therefore the interesting value: it must be exactly the
 * intentionally excluded ranges (unspecified, private, loopback, link-local,
 * multicast/reserved). Public ranges that slip into the complement silently
 * bypass every control, which is what happened to 116-119/8 and 122-123/8.
 */
class DnsVpnTunnelManagerBypassRoutesTest {

    private fun prefixToRange(base: String, prefix: Int): LongRange {
        val octets = base.split(".").map { it.toInt() }
        require(octets.size == 4) { "bad IPv4 base: $base" }
        require(prefix in 0..32) { "bad prefix: $prefix" }
        val start = (octets[0].toLong() shl 24) or (octets[1].toLong() shl 16) or
            (octets[2].toLong() shl 8) or octets[3].toLong()
        val size = 1L shl (32 - prefix)
        return start until (start + size)
    }

    private fun complementOfBypassRoutes(): List<LongRange> {
        val routes = DnsVpnTunnelManager.IPV4_BYPASS_LAN_ROUTES
            .map { (base, prefix) -> prefixToRange(base, prefix) }
            .sortedBy { it.first }

        // Routes must not overlap: an overlap hides a hole in the complement check.
        routes.zipWithNext().forEach { (a, b) ->
            check(a.last < b.first) { "overlapping bypass routes: $a and $b" }
        }

        val gaps = mutableListOf<LongRange>()
        var cursor = 0L
        routes.forEach { route ->
            if (route.first > cursor) gaps += cursor until route.first
            cursor = route.last + 1
        }
        val end = (1L shl 32) - 1
        if (cursor <= end) gaps += cursor..end
        return gaps
    }

    private fun LongRange.toCidrList(): List<String> {
        val cidrs = mutableListOf<String>()
        var start = first
        while (start <= last) {
            var bits = 0
            while (bits < 32) {
                val size = 1L shl (bits + 1)
                if (start % size != 0L || start + size - 1 > last) break
                bits++
            }
            val size = 1L shl bits
            cidrs += "${ipToString(start)}/${32 - bits}"
            start += size
        }
        return cidrs
    }

    private fun ipToString(value: Long): String =
        "${(value shr 24) and 0xFF}.${(value shr 16) and 0xFF}.${(value shr 8) and 0xFF}.${value and 0xFF}"

    @Test
    fun bypassRoutesCoverOnlyNonTunnelRanges() {
        val expected = listOf(
            "0.0.0.0/8", // unspecified / "this network"
            "10.0.0.0/8", // private
            "127.0.0.0/8", // loopback
            "169.254.0.0/16", // link-local
            "172.16.0.0/12", // private
            "192.168.0.0/16", // private
            "224.0.0.0/3" // multicast (224/4) + reserved (240/4)
        )
        val actual = complementOfBypassRoutes().flatMap { it.toCidrList() }
        assertEquals(expected, actual)
    }

    @Test
    fun publicChinaTelecomAndUnicomRangesAreTunneled() {
        val gaps = complementOfBypassRoutes()
        // Ranges that used to be missing from the bypass list (thus leaked direct).
        listOf("116.0.0.1", "117.1.2.3", "118.4.5.6", "119.7.8.9", "122.10.11.12", "123.13.14.15")
            .forEach { ip ->
                val value = prefixToRange(ip, 32).first
                assertEquals("$ip must not be bypassed", false, gaps.any { value in it })
            }
    }

    @Test
    fun previouslyCoveredRangesStayCovered() {
        val gaps = complementOfBypassRoutes()
        // Public ranges that the old route list already captured; the 112/6 -> 112/7
        // + 114/8 + 115/8 split must not open a hole here.
        listOf("112.0.0.1", "112.255.255.254", "113.1.1.1", "114.1.1.1", "115.2.2.2",
            "120.3.3.3", "121.4.4.4", "124.5.5.5", "125.6.6.6", "126.7.7.7", "208.1.1.1")
            .forEach { ip ->
                val value = prefixToRange(ip, 32).first
                assertEquals("$ip must stay tunneled", false, gaps.any { value in it })
            }
    }
}
