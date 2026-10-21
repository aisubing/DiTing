package com.haoze.diting.server.model

/**
 * Pure input validation and display formatting for the DNS mode local listen
 * port. Error strings are Chinese dict keys resolved through localizedText at
 * the UI layer. Kept free of Android dependencies so unit tests can exercise it
 * directly.
 */
object DnsListenPortValidator {
    const val DEFAULT_PORT = 1053
    const val MIN_PORT = 1024
    const val MAX_PORT = 65535

    /** Returns null when acceptable, otherwise the error message key. */
    fun validate(portText: String): String? {
        val port = portText.trim().toIntOrNull() ?: return "端口必须为数字"
        if (port !in MIN_PORT..MAX_PORT) return "端口必须在 $MIN_PORT-$MAX_PORT 之间"
        return null
    }

    fun parse(portText: String): Int = portText.trim().toIntOrNull() ?: DEFAULT_PORT

    /**
     * True when the engine can actually bind this port. Anything outside
     * [MIN_PORT]..[MAX_PORT] is unbindable (privileged, zero, or out of range).
     */
    fun isBindable(port: Int): Boolean = port in MIN_PORT..MAX_PORT

    /**
     * Port used in user-facing LAN access instructions.
     *
     * Falls back to [DEFAULT_PORT] for values the engine can never bind, so a
     * corrupted or legacy stored value cannot be rendered as an unreachable
     * endpoint. The fallback is deliberately paired with [unusablePortWarning]:
     * silently showing 1053 would hide a real misconfiguration, leaving the user
     * to point their router at a port the engine never bound.
     */
    fun displayPort(port: Int): Int = if (isBindable(port)) port else DEFAULT_PORT

    /**
     * Warning to show next to the access instructions when the stored port is
     * unbindable and the displayed port is therefore a fallback, not the user's
     * setting. Returns null when the configured port is usable, which is the
     * normal case and must not produce any extra UI.
     *
     * Spliced rather than looked up in the translation table for the same reason
     * as [accessInstruction]: it embeds a runtime value.
     */
    fun unusablePortWarning(port: Int): String? =
        if (isBindable(port)) {
            null
        } else {
            "当前端口配置不可用（$port），接入信息已回退为 $DEFAULT_PORT；请到 DNS 模式设置中重新选择端口。"
        }

    /**
     * Renders the `ip:port` endpoints shown by the DNS mode home screen and the
     * onboarding wizard. The port is the user's configured listen port rather
     * than a hardcoded default, so the instructions stay correct after a change.
     */
    fun formatEndpoints(ips: List<String>, port: Int, separator: String = " / "): String {
        val display = displayPort(port)
        return ips.joinToString(separator) { "$it:$display" }
    }

    /** Single `ip:port` endpoint label. */
    fun formatEndpoint(ip: String, port: Int): String = "$ip:${displayPort(port)}"

    /**
     * Wizard step-three instruction text with the real listen port spliced in.
     * Splicing instead of a dict key is deliberate: these sentences embed a
     * runtime value, so an exact-match translation entry could never be hit.
     */
    fun accessInstruction(port: Int): String =
        "在电脑、手机、电视的 Wi-Fi 设置中，将 DNS 改为上述 IP，并将端口设为 ${displayPort(port)}（标准设备可使用路由器 DNS 转发）。"

    /** Wizard step-two "no VPN required" disclaimer with the real listen port. */
    fun noVpnDisclaimer(port: Int): String =
        "免 VPN 声明：服务器模式仅在本地 ${displayPort(port)} 端口提供局域网服务，不创建 VPN 接口，无需授予 VPN 权限。"
}
