package com.haoze.diting.core.dns

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The DNS tools feed `isIpLiteral` results straight into
 * `InetAddress.getByName`, so anything accepted as a literal must be parseable
 * without a DNS lookup. "Contains a colon" used to be enough, which let
 * host:port input ("8.8.8.8:53") through and made the DNS lookup tool throw
 * UnknownHostException on a plain user typo.
 */
class DnsProviderIpLiteralTest {

    @Test
    fun acceptsIpv4Literals() {
        assertTrue(DnsProvider.isIpLiteral("8.8.8.8"))
        assertTrue(DnsProvider.isIpLiteral(" 1.1.1.1 "))
        assertTrue(DnsProvider.isIpLiteral("0.0.0.0"))
        assertTrue(DnsProvider.isIpLiteral("255.255.255.255"))
    }

    @Test
    fun rejectsOutOfRangeIpv4() {
        assertFalse(DnsProvider.isIpLiteral("256.1.1.1"))
        assertFalse(DnsProvider.isIpLiteral("1.1.1"))
        assertFalse(DnsProvider.isIpLiteral("1.1.1.1.1"))
    }

    @Test
    fun rejectsHostWithPort() {
        assertFalse(DnsProvider.isIpLiteral("8.8.8.8:53"))
        assertFalse(DnsProvider.isIpLiteral("223.5.5.5:853"))
        assertFalse(DnsProvider.isIpLiteral("dns.google:853"))
        assertFalse(DnsProvider.isIpLiteral("https://dns.google/dns-query"))
        assertFalse(DnsProvider.isIpLiteral("[::1]:53"))
        assertFalse(DnsProvider.isIpLiteral("[2001:db8::1]:853"))
    }

    @Test
    fun rejectsHostnames() {
        assertFalse(DnsProvider.isIpLiteral("dns.google"))
        assertFalse(DnsProvider.isIpLiteral(""))
        assertFalse(DnsProvider.isIpLiteral("   "))
    }

    @Test
    fun acceptsIpv6Literals() {
        assertTrue(DnsProvider.isIpLiteral("::1"))
        assertTrue(DnsProvider.isIpLiteral("::"))
        assertTrue(DnsProvider.isIpLiteral("2001:db8::1"))
        assertTrue(DnsProvider.isIpLiteral("2001:0db8:0000:0000:0000:0000:0000:0001"))
        assertTrue(DnsProvider.isIpLiteral("fe80::1%wlan0"))
        assertTrue(DnsProvider.isIpLiteral("[::1]"))
        assertTrue(DnsProvider.isIpLiteral("[2001:db8::1]"))
    }

    @Test
    fun rejectsMalformedIpv6() {
        assertFalse(DnsProvider.isIpLiteral("2001:db8::1::2"))
        assertFalse(DnsProvider.isIpLiteral("::gggg"))
        assertFalse(DnsProvider.isIpLiteral("2001:db8"))
        assertFalse(DnsProvider.isIpLiteral("[::1"))
        assertFalse(DnsProvider.isIpLiteral("::1]"))
    }

    @Test
    fun dotHostRejectsIpAndPortInput() {
        // DoT takes the host separately from the port, so neither an IP literal
        // nor host:port is a valid DoT host.
        assertFalse(DnsProvider.isValidDotHost("8.8.8.8"))
        assertFalse(DnsProvider.isValidDotHost("dns.google:853"))
        assertFalse(DnsProvider.isValidDotHost("::1"))
        assertTrue(DnsProvider.isValidDotHost("dns.google"))
    }

    @Test
    fun dnsHostAcceptsIpButNotPortInput() {
        assertTrue(DnsProvider.isValidDnsHost("223.5.5.5"))
        assertTrue(DnsProvider.isValidDnsHost("::1"))
        assertTrue(DnsProvider.isValidDnsHost("dns.google"))
        assertFalse(DnsProvider.isValidDnsHost("8.8.8.8:53"))
        assertFalse(DnsProvider.isValidDnsHost("dns.google:53"))
        assertFalse(DnsProvider.isValidDnsHost(""))
    }
}
