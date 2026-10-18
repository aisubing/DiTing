package com.haoze.diting.ui.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * V10 stopped writing the outbound proxy username/password into the exported
 * JSON (they are KeyStore secrets; the plain-text copy leaked them with every
 * backup). These tests pin the format contract:
 *  - a V10 export parses without credentials,
 *  - a V9 file that still carries them keeps importing,
 *  - the version is bumped so old and new files stay distinguishable.
 */
class ConfigTransferParserOutboundProxyTest {

    private fun minimalConfig(version: Int, proxyJson: String): String = """
        {
          "formatVersion": $version,
          "outboundProxy": $proxyJson
        }
    """.trimIndent()

    @Test
    fun formatVersionIsBumpedPastCredentialExport() {
        assertTrue(ConfigTransferParser.FORMAT_VERSION >= 10)
    }

    @Test
    fun v10ExportWithoutCredentialsParses() {
        val json = minimalConfig(
            10,
            """{"enabled":true,"protocol":"socks5","host":"127.0.0.1","port":7890,
               "credentialsOmitted":true,"proxyAppPackage":"com.example.proxy"}"""
        )
        val config = ConfigTransferParser.parseAndValidate(json)
        val proxy = config.outboundProxy
        assertNotNull("outboundProxy must survive parsing", proxy)
        requireNotNull(proxy)
        assertTrue(proxy.enabled)
        assertEquals("socks5", proxy.protocol)
        assertEquals("127.0.0.1", proxy.host)
        assertEquals(7890, proxy.port)
        assertEquals("com.example.proxy", proxy.proxyAppPackage)
        assertEquals("", proxy.username)
        assertEquals("", proxy.password)
    }

    @Test
    fun legacyV9FileWithCredentialsStillImports() {
        val json = minimalConfig(
            9,
            """{"enabled":true,"protocol":"http","host":"::1","port":8080,
               "username":"alice","password":"s3cret"}"""
        )
        val config = ConfigTransferParser.parseAndValidate(json)
        val proxy = config.outboundProxy
        requireNotNull(proxy)
        assertEquals("http", proxy.protocol)
        assertEquals("::1", proxy.host)
        assertEquals("alice", proxy.username)
        assertEquals("s3cret", proxy.password)
    }

    @Test
    fun absentOutboundProxyStaysAbsent() {
        val config = ConfigTransferParser.parseAndValidate("""{"formatVersion":10}""")
        assertEquals(null, config.outboundProxy)
        assertFalse(config.outboundProxy != null)
    }
}
