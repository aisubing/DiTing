package com.haoze.diting.util

/**
 * 轻量级 API 密钥混淆器。
 * 采用 3 组异或掩码与 Base64 编码，避免 API Key 在本地 SharedPreferences 中以纯明文形式直接暴露。
 *
 * 实现约束：
 * - Base64 走 [Base64Codec] 的纯 Kotlin 实现。原先的 `java.util.Base64` 是 API 26 才引入的类，
 *   本工程 `minSdk = 24` 且未开启 `coreLibraryDesugaring`，在 API 24/25 上必然
 *   `NoClassDefFoundError`（见 A-032）。
 * - 明文字节序列化用 UTF-8（[String.toByteArray]）而非逐 `Char` 截断。原先
 *   `plain[i].code.toByte()` 把 UTF-16 code unit 的低 8 位当字节，任何非 ASCII 字符
 *   （中文、emoji 等）往返都会被静默替换成 `?`（见 A-059）。
 */
object KeyObfuscator {
    private val ka = byteArrayOf(
        0x4D.toByte(), 0x1A.toByte(), 0xC8.toByte(), 0x37.toByte(),
        0x62.toByte(), 0x9E.toByte(), 0xFB.toByte(), 0x54.toByte()
    )
    private val kb = byteArrayOf(
        0x29.toByte(), 0x6C.toByte(), 0xD3.toByte(), 0x8E.toByte(),
        0x71.toByte(), 0x05.toByte(), 0xBA.toByte(), 0x4F.toByte()
    )
    private val kc = byteArrayOf(
        0xBE.toByte(), 0x34.toByte(), 0x65.toByte(), 0x8A.toByte(),
        0x71.toByte(), 0x22.toByte(), 0xD9.toByte(), 0x46.toByte()
    )

    fun seal(plain: String): String {
        if (plain.isBlank()) return ""
        val source = plain.toByteArray(Charsets.UTF_8)
        val mixed = ByteArray(source.size) { i ->
            (source[i].toInt() xor ka[i % ka.size].toInt() xor kb[i % kb.size].toInt() xor kc[i % kc.size].toInt()).toByte()
        }
        return Base64Codec.encode(mixed)
    }

    fun open(sealed: String): String {
        if (sealed.isBlank()) return ""
        return try {
            val mixed = Base64Codec.decode(sealed) ?: return ""
            val plain = ByteArray(mixed.size) { i ->
                (mixed[i].toInt() xor ka[i % ka.size].toInt() xor kb[i % kb.size].toInt() xor kc[i % kc.size].toInt()).toByte()
            }
            plain.toString(Charsets.UTF_8)
        } catch (_: Exception) {
            ""
        }
    }
}
