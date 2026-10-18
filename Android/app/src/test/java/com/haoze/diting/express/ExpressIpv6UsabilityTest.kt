package com.haoze.diting.express

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for A-012 (Express side).
 *
 * 改前代码在 `ExpressTunnelManager` 里写成 `hasIpv6Route || hasGlobalIpv6`，
 * 而 `hasGlobalIpv6` 在其上一行已被 `if (!hasGlobalIpv6) return@any false`
 * 强制为 `true`，于是整个表达式**恒真**，`hasIpv6Route` 成了死代码：
 * 只要设备有 GUA 地址，即使没有 IPv6 默认路由也会被判为「IPv6 可用」，
 * 随后给 TUN 加 IPv6 地址与 DNS，造成 IPv6 流量无出口。
 *
 * 四种组合全部覆盖，其中 `(true, false) -> false` 是改前的错误答案，
 * 也是这条回归唯一真正的护栏。
 */
class ExpressIpv6UsabilityTest {

    @Test
    fun `global address with route is usable`() {
        assertTrue(ExpressIpv6Usability.isIpv6Usable(hasGlobalIpv6Address = true, hasIpv6Route = true))
    }

    @Test
    fun `global address without route is not usable`() {
        // 改前这里是 true（`hasIpv6Route || hasGlobalIpv6` 恒真）——正是 A-012 的缺陷。
        assertFalse(ExpressIpv6Usability.isIpv6Usable(hasGlobalIpv6Address = true, hasIpv6Route = false))
    }

    @Test
    fun `route without global address is not usable`() {
        assertFalse(ExpressIpv6Usability.isIpv6Usable(hasGlobalIpv6Address = false, hasIpv6Route = true))
    }

    @Test
    fun `neither address nor route is usable`() {
        assertFalse(ExpressIpv6Usability.isIpv6Usable(hasGlobalIpv6Address = false, hasIpv6Route = false))
    }

    @Test
    fun `verdict requires both inputs like the normal mode implementation`() {
        // 与 normal/DnsVpnTunnelManager.isIpv6Usable 的语义对齐：两侧都必须是 AND，
        // 否则 Express 与普通模式会对同一台设备给出相反的 IPv6 判定。
        for (address in booleanArrayOf(true, false)) {
            for (route in booleanArrayOf(true, false)) {
                assertTrue(
                    "mismatch at address=$address route=$route",
                    ExpressIpv6Usability.isIpv6Usable(address, route) == (address && route)
                )
            }
        }
    }
}
