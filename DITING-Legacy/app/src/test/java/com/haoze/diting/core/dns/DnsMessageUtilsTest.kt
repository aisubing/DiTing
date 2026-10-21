package com.haoze.diting.core.dns

import com.haoze.diting.core.rule.BlockResponseMode
import com.haoze.diting.core.rule.RewriteAnswer
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DnsMessageUtilsTest {

    @Test
    fun nxdomainAndNodataResponses() {
        val queryA = DnsMessageUtils.buildQuery("blocked.example", DnsMessageUtils.TYPE_A, 0x1234)
        val nxdomain = DnsMessageUtils.buildBlockedResponse(queryA, BlockResponseMode.NXDOMAIN)

        assertEquals(0x1234, DnsMessageUtils.transactionId(nxdomain))
        assertEquals(3, DnsMessageUtils.responseCode(nxdomain))
        assertEquals(queryA.size, nxdomain.size)

        val queryTxt = DnsMessageUtils.buildQuery("blocked.example", 16, 0x1235)
        val nodata = DnsMessageUtils.buildBlockedResponse(queryTxt, BlockResponseMode.NODATA)

        assertEquals(0x1235, DnsMessageUtils.transactionId(nodata))
        assertEquals(0, DnsMessageUtils.responseCode(nodata))
        assertEquals(0L, DnsMessageUtils.cacheLifetimeSeconds(nodata))
        assertEquals(queryTxt.size, nodata.size)
    }

    @Test
    fun zeroAddressResponses() {
        val queryA = DnsMessageUtils.buildQuery("blocked.example", DnsMessageUtils.TYPE_A, 0x2001)
        val respA = DnsMessageUtils.buildBlockedResponse(queryA, BlockResponseMode.ZERO_ADDRESS)
        assertEquals(0, DnsMessageUtils.responseCode(respA))
        assertEquals("0.0.0.0", DnsMessageUtils.extractAddressRecords(respA).single().hostAddress)

        val queryAaaa = DnsMessageUtils.buildQuery("blocked.example", DnsMessageUtils.TYPE_AAAA, 0x2002)
        val respAaaa = DnsMessageUtils.buildBlockedResponse(queryAaaa, BlockResponseMode.ZERO_ADDRESS)
        assertEquals(0, DnsMessageUtils.responseCode(respAaaa))
        assertTrue(DnsMessageUtils.extractAddressRecords(respAaaa).single().address.all { it == 0.toByte() })
    }

    @Test
    fun refusedAndMalformedResponses() {
        val query = DnsMessageUtils.buildQuery("blocked.example", DnsMessageUtils.TYPE_A, 0x1236)
        val refused = DnsMessageUtils.buildBlockedResponse(query, BlockResponseMode.REFUSED)
        assertEquals(0x1236, DnsMessageUtils.transactionId(refused))
        assertEquals(5, DnsMessageUtils.responseCode(refused))

        val malformedQuery = byteArrayOf(0x12, 0x34)
        val servfail = DnsMessageUtils.buildBlockedResponse(malformedQuery, BlockResponseMode.NXDOMAIN)
        assertEquals(0x1234, DnsMessageUtils.transactionId(servfail))
        assertEquals(2, DnsMessageUtils.responseCode(servfail))
    }

    @Test
    fun detectsTruncatedDnsResponse() {
        val response = byteArrayOf(0x12, 0x34, 0x82.toByte(), 0x00) + ByteArray(8)
        assertTrue(DnsMessageUtils.isTruncatedResponse(response))
    }

    @Test
    fun rewriteResponsesAnswerIpAndCnameTargets() {
        val queryA = DnsMessageUtils.buildQuery("hosts.example", DnsMessageUtils.TYPE_A, 0x3001)
        val respA = DnsRewriteMessage.buildResponse(
            queryA,
            setOf(RewriteAnswer("IPv4", "1.2.3.4"))
        )
        assertEquals(0x3001, DnsMessageUtils.transactionId(respA!!))
        assertEquals(0, DnsMessageUtils.responseCode(respA))
        assertEquals("1.2.3.4", DnsMessageUtils.extractAddressRecords(respA).single().hostAddress)

        val queryAaaa = DnsMessageUtils.buildQuery("hosts.example", DnsMessageUtils.TYPE_AAAA, 0x3002)
        val respAaaa = DnsRewriteMessage.buildResponse(
            queryAaaa,
            setOf(RewriteAnswer("IPv6", "::1"))
        )
        val address = DnsMessageUtils.extractAddressRecords(respAaaa!!).single()
        assertTrue(address.address.size == 16)
        assertTrue(address.address.dropLast(1).all { it == 0.toByte() })
        assertEquals(1.toByte(), address.address.last())
    }

    @Test
    fun buildQueryConvertsIdnToPunycode() {
        val query = DnsMessageUtils.buildQuery("中文.com", DnsMessageUtils.TYPE_A, 0x4242)
        // QNAME at offset 12: length byte + label bytes, then the root label.
        val firstLabelLen = query[12].toInt() and 0xFF
        val firstLabel = String(query, 13, firstLabelLen, Charsets.US_ASCII)
        assertEquals("xn--fiq228c", firstLabel)

        // The question length must be computed from the Punycode byte count,
        // not the original character count.
        val expectedName = "xn--fiq228c.com"
        var expectedQuestionLen = 1
        expectedName.split('.').forEach { expectedQuestionLen += 1 + it.length }
        expectedQuestionLen += 4
        assertEquals(12 + expectedQuestionLen, query.size)

        // Uppercase and a trailing root dot must normalize to the same wire name.
        assertEquals(
            DnsMessageUtils.extractQuestion(query)?.name,
            DnsMessageUtils.extractQuestion(
                DnsMessageUtils.buildQuery("中文.COM.", DnsMessageUtils.TYPE_A, 0x4242)
            )?.name
        )
    }

    @Test
    fun rewriteResponseReturnsNullWhenNoTargetFits() {
        // A query with only a CNAME target: no IP answer fits.
        val queryA = DnsMessageUtils.buildQuery("hosts.example", DnsMessageUtils.TYPE_A, 0x3003)
        assertEquals(
            null,
            DnsRewriteMessage.buildResponse(queryA, setOf(RewriteAnswer("CNAME", "alias.example")))
        )
        // Malformed query yields no rewrite response.
        assertEquals(
            null,
            DnsRewriteMessage.buildResponse(byteArrayOf(0x12, 0x34), setOf(RewriteAnswer("IPv4", "1.2.3.4")))
        )
        assertEquals(
            null,
            DnsRewriteMessage.buildResponse(queryA, emptySet())
        )
    }
}
