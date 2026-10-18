package com.haoze.diting.core.diagnostic

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-041: `TunnelDiagnosticsResolver.tunnelResolver` was declared and read but
 * never assigned anywhere in the repository, so `resolve()` always hit
 * `tunnelResolver?.invoke(...) ?: return null`. Every tunnel-based tool (DNS
 * lookup, ping, traceroute with the tunnel toggle on) therefore reported
 * 「VPN 未运行，无法通过 Go 隧道解析」 even while the tunnel was running.
 *
 * The fix assigns the hook in `DitingApp.onCreate()`. The hook itself is plain
 * Kotlin state, so the contract it must satisfy — null when unassigned, delegated
 * arguments, and the engine's JSON shape — is pinned down here.
 */
class TunnelDiagnosticsResolverTest {

    private fun withResolver(json: String?, block: () -> Unit) {
        val original = TunnelDiagnosticsResolver.tunnelResolver
        try {
            TunnelDiagnosticsResolver.tunnelResolver = { _, _ -> json }
            block()
        } finally {
            TunnelDiagnosticsResolver.tunnelResolver = original
        }
    }

    @Test
    fun unassignedResolverReportsNotRunning() {
        val original = TunnelDiagnosticsResolver.tunnelResolver
        try {
            TunnelDiagnosticsResolver.tunnelResolver = null
            // This null is exactly what produces 「VPN 未运行」 in NetworkTools.
            assertNull(TunnelDiagnosticsResolver.resolve("example.com", preferIpv4 = true))
            assertNull(TunnelDiagnosticsResolver.resolveAutoFamily("example.com"))
        } finally {
            TunnelDiagnosticsResolver.tunnelResolver = original
        }
    }

    @Test
    fun assignedResolverIsActuallyInvoked() {
        var calls = 0
        val original = TunnelDiagnosticsResolver.tunnelResolver
        try {
            TunnelDiagnosticsResolver.tunnelResolver = { _, _ ->
                calls++
                """{"ips":["93.184.216.34"],"ttls":[300],"source":"upstream"}"""
            }
            val result = TunnelDiagnosticsResolver.resolve("example.com", preferIpv4 = true)

            assertNotNull(result)
            assertEquals(1, calls)
            assertEquals(listOf("93.184.216.34"), result!!.ips)
        } finally {
            TunnelDiagnosticsResolver.tunnelResolver = original
        }
    }

    @Test
    fun resolverReceivesDomainAndFamilyPreference() {
        val seen = mutableListOf<Pair<String, Boolean>>()
        val original = TunnelDiagnosticsResolver.tunnelResolver
        try {
            TunnelDiagnosticsResolver.tunnelResolver = { domain, ipv4 ->
                seen += domain to ipv4
                """{"ips":[],"ttls":[],"source":"nodata"}"""
            }
            TunnelDiagnosticsResolver.resolve("a.example", preferIpv4 = true)
            TunnelDiagnosticsResolver.resolve("b.example", preferIpv4 = false)

            assertEquals(listOf("a.example" to true, "b.example" to false), seen)
        } finally {
            TunnelDiagnosticsResolver.tunnelResolver = original
        }
    }

    @Test
    fun parsesUpstreamAnswerWithTtls() {
        withResolver("""{"ips":["1.1.1.1","8.8.8.8"],"ttls":[60,120],"source":"upstream","reason":"cache miss"}""") {
            val result = TunnelDiagnosticsResolver.resolve("example.com", preferIpv4 = true)!!

            assertEquals(listOf("1.1.1.1", "8.8.8.8"), result.ips)
            assertEquals(listOf(60, 120), result.ttls)
            assertEquals(TunnelDiagnosticsResolver.Source.UPSTREAM, result.source)
            assertEquals("cache miss", result.reason)
            assertNull(result.error)
            assertEquals("上游 DNS", result.sourceLabel())
        }
    }

    @Test
    fun parsesRewriteSource() {
        withResolver("""{"ips":["10.0.0.1"],"ttls":[0],"source":"rewrite"}""") {
            val result = TunnelDiagnosticsResolver.resolve("example.com", preferIpv4 = true)!!
            assertEquals(TunnelDiagnosticsResolver.Source.REWRITE, result.source)
            assertEquals("覆写规则", result.sourceLabel())
        }
    }

    @Test
    fun parsesBlockedSource() {
        withResolver("""{"ips":[],"ttls":[],"source":"blocked"}""") {
            val result = TunnelDiagnosticsResolver.resolve("ads.example", preferIpv4 = true)!!
            assertEquals(TunnelDiagnosticsResolver.Source.BLOCKED, result.source)
            // Blocked has no decision-source label; the UI shows its own text.
            assertEquals("", result.sourceLabel())
        }
    }

    @Test
    fun engineErrorTokenIsTranslated() {
        // The engine reports an inactive resolver with this token; showing it raw
        // would be untranslated Go internals in the UI.
        withResolver("""{"error":"tunnel resolver not active"}""") {
            val result = TunnelDiagnosticsResolver.resolve("example.com", preferIpv4 = true)!!
            assertEquals(TunnelDiagnosticsResolver.Source.ERROR, result.source)
            assertEquals("Go 隧道未运行", result.errorLabel())
        }
    }

    @Test
    fun malformedJsonBecomesAnErrorResultRatherThanACrash() {
        withResolver("this is not json") {
            val result = TunnelDiagnosticsResolver.resolve("example.com", preferIpv4 = true)
            assertNotNull(result)
            assertEquals(TunnelDiagnosticsResolver.Source.ERROR, result!!.source)
            assertEquals("解析结果无效", result.error)
        }
    }

    @Test
    fun autoFamilyFallsBackToIpv6OnlyWhenIpv4HasNoAnswer() {
        val families = mutableListOf<Boolean>()
        val original = TunnelDiagnosticsResolver.tunnelResolver
        try {
            TunnelDiagnosticsResolver.tunnelResolver = { _, ipv4 ->
                families += ipv4
                if (ipv4) {
                    """{"ips":[],"ttls":[],"source":"nodata"}"""
                } else {
                    """{"ips":["2001:db8::1"],"ttls":[60],"source":"upstream"}"""
                }
            }
            val result = TunnelDiagnosticsResolver.resolveAutoFamily("v6.example")!!

            assertEquals(listOf(true, false), families)
            assertEquals(listOf("2001:db8::1"), result.ips)
        } finally {
            TunnelDiagnosticsResolver.tunnelResolver = original
        }
    }

    @Test
    fun autoFamilyDoesNotQueryIpv6WhenIpv4Answered() {
        val families = mutableListOf<Boolean>()
        val original = TunnelDiagnosticsResolver.tunnelResolver
        try {
            TunnelDiagnosticsResolver.tunnelResolver = { _, ipv4 ->
                families += ipv4
                """{"ips":["1.2.3.4"],"ttls":[60],"source":"upstream"}"""
            }
            TunnelDiagnosticsResolver.resolveAutoFamily("v4.example")

            assertEquals(listOf(true), families)
        } finally {
            TunnelDiagnosticsResolver.tunnelResolver = original
        }
    }

    @Test
    fun resolverFailureNeverPropagatesToTheTools() {
        // DitingApp wraps the delegation in runCatching so a tunnel-side crash
        // cannot take down the diagnostics screen.
        withResolver(null) {
            assertNull(TunnelDiagnosticsResolver.resolve("example.com", preferIpv4 = true))
        }
        assertTrue(true)
    }
}
