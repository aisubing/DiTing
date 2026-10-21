package com.haoze.diting.core.dns

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * A-042: `testDoh` called `provider.url.toHttpUrl()` outside its try block, so a
 * provider whose DoH URL does not parse threw IllegalArgumentException straight
 * out of the latency tester and took down the whole speed test instead of
 * failing that one row.
 *
 * A provider URL is not always app-generated: config import
 * (`ui/transfer/ConfigTransferParser.kt`) and hand-edited providers reach the
 * tester, and `DnsProvider.isValidDohUrl` only checks the `https://` prefix, so
 * empty or unparseable hosts are reachable.
 */
class DohUrlParserTest {

    @Test
    fun parsesValidDohUrls() {
        assertNotNull(DohUrlParser.parseOrNull("https://dns.google/dns-query"))
        assertNotNull(DohUrlParser.parseOrNull("https://cloudflare-dns.com/dns-query"))
        assertNotNull(DohUrlParser.parseOrNull("https://doh.pub/dns-query"))
    }

    @Test
    fun trimsSurroundingWhitespace() {
        val parsed = DohUrlParser.parseOrNull("  https://dns.google/dns-query  ")
        assertNotNull(parsed)
        assertEquals("dns.google", parsed!!.host)
    }

    @Test
    fun returnsNullForNullOrBlankInput() {
        assertNull(DohUrlParser.parseOrNull(null))
        assertNull(DohUrlParser.parseOrNull(""))
        assertNull(DohUrlParser.parseOrNull("   "))
    }

    @Test
    fun returnsNullForMissingScheme() {
        // isValidDohUrl only checks the prefix, so these shapes can reach us.
        assertNull(DohUrlParser.parseOrNull("dns.google/dns-query"))
        assertNull(DohUrlParser.parseOrNull("://dns.google/dns-query"))
    }

    @Test
    fun returnsNullForUnparseableUrl() {
        // OkHttp returns null (which toHttpUrl turns into a throw) when there is no
        // usable host at all: empty authority, whitespace in the host, no scheme.
        assertNull(DohUrlParser.parseOrNull("https://"))
        assertNull(DohUrlParser.parseOrNull("https://a b c/"))
    }

    @Test
    fun emptyAuthorityFallsBackToTheFirstPathSegmentAsHost() {
        // OkHttp is lenient about an empty authority: "https:///dns-query" parses
        // as host "dns-query" (single-label hosts are legal DNS names, and this is
        // how LAN endpoints like https://dns/ work). Such a URL is well-formed, so
        // the guard must NOT reject it — the connection then simply fails on the
        // network, which is the per-row failure A-042 wanted, not a crash.
        //
        // This leniency is exactly why the raw toHttpUrl() call could not stay
        // outside the try block: the same parser that throws for "https://" happily
        // rewrites a malformed authority into a different host, so callers must not
        // assume parsing success implies the URL means what the user typed.
        val parsed = DohUrlParser.parseOrNull("https:///dns-query")

        assertNotNull(parsed)
        assertEquals("dns-query", parsed!!.host)
    }

    @Test
    fun reportsEmptyUrlDistinctlyFromInvalidUrl() {
        // The failure message is shown per provider row, so an empty URL must not
        // be reported as "invalid: " with a dangling suffix.
        assertEquals("DoH 地址为空", DohUrlParser.invalidUrlMessage(""))
        assertEquals("DoH 地址为空", DohUrlParser.invalidUrlMessage("   "))
        assertEquals("DoH 地址为空", DohUrlParser.invalidUrlMessage(null))
    }

    @Test
    fun invalidUrlMessageQuotesTheOffendingValue() {
        assertEquals("DoH 地址无效：dns.google/dns-query", DohUrlParser.invalidUrlMessage("dns.google/dns-query"))
        assertEquals("DoH 地址无效：dns.google/dns-query", DohUrlParser.invalidUrlMessage("  dns.google/dns-query  "))
    }

    @Test
    fun neverThrowsForAnyInput() {
        // The whole point of the helper: no input may propagate an exception.
        val inputs = listOf(null, "", " ", "http://", "https://", "%%%", "https://a b c/", "javascript:alert(1)")
        inputs.forEach { DohUrlParser.parseOrNull(it) }
        inputs.forEach { DohUrlParser.invalidUrlMessage(it) }
    }
}
