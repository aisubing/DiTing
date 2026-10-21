package com.haoze.diting.express

/**
 * IPv6 可用性判据 for Express Mode。
 *
 * 仅有全球单播地址（GUA）**不足以**判定 IPv6 可用：还必须存在 IPv6 路由
 * （默认路由 / 带网关路由 / 前缀长度 0 的路由），否则给 TUN 加上 IPv6 地址与
 * DNS 后，IPv6 流量无出口，表现为解析与连通性异常。
 *
 * 抽出为独立纯函数的原因：
 * - `normal/DnsVpnTunnelManager` 侧有行为逐字相同的 `isIpv6Usable`，但 `express/`
 *   反向依赖 `normal/` 会引入包环，故不可跨包复用；两侧各自持有同名实现，靠测试锁住一致。
 * - `ExpressTunnelManager` 已逼近 550 行上限，判据放这里留出余量。
 */
internal object ExpressIpv6Usability {

    /**
     * @param hasGlobalIpv6Address 是否已有 2000::/3 的全球单播地址
     * @param hasIpv6Route 是否存在可承载 IPv6 流量的路由
     */
    fun isIpv6Usable(hasGlobalIpv6Address: Boolean, hasIpv6Route: Boolean): Boolean =
        hasGlobalIpv6Address && hasIpv6Route
}
