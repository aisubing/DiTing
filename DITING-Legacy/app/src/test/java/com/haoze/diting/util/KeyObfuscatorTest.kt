package com.haoze.diting.util

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-032：`java.util.Base64` 是 API 26 才引入的类，minSdk=24 且未开 desugaring。
 * A-059：非 ASCII 密钥往返曾被静默损坏。
 */
class KeyObfuscatorTest {

    @Test
    fun seal_open_roundTripsAsciiKey() {
        val key = "sk-ant-api03-abcdefg123456-XYZ!@#$"
        val sealed = KeyObfuscator.seal(key)
        assertTrue(sealed.isNotBlank())
        assertEquals(key, KeyObfuscator.open(sealed))
    }

    @Test
    fun seal_open_roundTripsNonAsciiKey() {
        // 旧实现把 UTF-16 code unit 截成单字节，「密钥abc」→「?abc」。
        val key = "密钥abc"
        val sealed = KeyObfuscator.seal(key)
        assertEquals(key, KeyObfuscator.open(sealed))
    }

    @Test
    fun seal_open_roundTripsEmojiAndMixedScript() {
        val key = "key-🔑-ключ-秘密-123"
        assertEquals(key, KeyObfuscator.open(KeyObfuscator.seal(key)))
    }

    @Test
    fun seal_open_roundTripsLongNonAsciiKey() {
        val key = "中文密钥".repeat(20)
        assertEquals(key, KeyObfuscator.open(KeyObfuscator.seal(key)))
    }

    @Test
    fun blankInputsStayEmpty() {
        assertEquals("", KeyObfuscator.seal(""))
        assertEquals("", KeyObfuscator.seal("   "))
        assertEquals("", KeyObfuscator.open(""))
        assertEquals("", KeyObfuscator.open("   "))
    }

    @Test
    fun open_returnsEmptyForMalformedCiphertext() {
        assertEquals("", KeyObfuscator.open("invalid_base64_???"))
        // 长度非 4 的倍数
        assertEquals("", KeyObfuscator.open("abc"))
        // 含非字母表字符
        assertEquals("", KeyObfuscator.open("ab*d"))
    }

    @Test
    fun seal_producesStandardPaddedBase64() {
        val sealed = KeyObfuscator.seal("a")
        assertEquals(0, sealed.length % 4)
        assertTrue(sealed.all { it.isLetterOrDigit() || it == '+' || it == '/' || it == '=' })
    }

    @Test
    fun base64Codec_matchesKnownVectors() {
        assertEquals("", Base64Codec.encode(ByteArray(0)))
        assertEquals("Zg==", Base64Codec.encode("f".toByteArray(Charsets.UTF_8)))
        assertEquals("Zm8=", Base64Codec.encode("fo".toByteArray(Charsets.UTF_8)))
        assertEquals("Zm9v", Base64Codec.encode("foo".toByteArray(Charsets.UTF_8)))
        assertEquals("Zm9vYmFy", Base64Codec.encode("foobar".toByteArray(Charsets.UTF_8)))
    }

    @Test
    fun base64Codec_roundTripsArbitraryBytes() {
        val data = ByteArray(256) { (it - 128).toByte() }
        assertArrayEquals(data, Base64Codec.decode(Base64Codec.encode(data)))
    }

    @Test
    fun base64Codec_decodesKnownVectors() {
        assertArrayEquals("f".toByteArray(Charsets.UTF_8), Base64Codec.decode("Zg=="))
        assertArrayEquals("foobar".toByteArray(Charsets.UTF_8), Base64Codec.decode("Zm9vYmFy"))
        assertArrayEquals(ByteArray(0), Base64Codec.decode(""))
    }

    @Test
    fun base64Codec_rejectsMalformedInput() {
        assertNull(Base64Codec.decode("abc"))
        assertNull(Base64Codec.decode("ab*d"))
        assertNull(Base64Codec.decode("a=bc"))
        assertNull(Base64Codec.decode("ab=c"))
    }
}
