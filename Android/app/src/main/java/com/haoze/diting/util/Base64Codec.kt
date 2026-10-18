package com.haoze.diting.util

/**
 * 纯 Kotlin 实现的标准 Base64 编解码器（RFC 4648 字母表，带 `=` 填充）。
 *
 * 存在原因：`java.util.Base64` 是 API 26 才加入的类，而本工程 `minSdk = 24` 且未开启
 * `coreLibraryDesugaring`，在 API 24/25 设备上直接引用会抛 `NoClassDefFoundError`。
 * `android.util.Base64` 虽然自 API 1 起可用，但它属于 Android framework，JVM 单测里
 * 只会抛 "not mocked"，因此这里用可测试的纯 Kotlin 实现。
 *
 * 与 `java.util.Base64.getEncoder()` / `getDecoder()` 行为对齐：
 * - 编码输出带填充、无换行；
 * - 解码只接受标准字母表，非法字符/长度非 4 的倍数/填充位置错误一律返回 `null`。
 */
internal object Base64Codec {

    private const val ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    private val REVERSE: IntArray = IntArray(128) { -1 }.also { table ->
        ALPHABET.forEachIndexed { index, char -> table[char.code] = index }
    }

    fun encode(data: ByteArray): String {
        if (data.isEmpty()) return ""
        val builder = StringBuilder((data.size + 2) / 3 * 4)
        var index = 0
        while (index + 3 <= data.size) {
            val chunk = ((data[index].toInt() and 0xFF) shl 16) or
                ((data[index + 1].toInt() and 0xFF) shl 8) or
                (data[index + 2].toInt() and 0xFF)
            builder.append(ALPHABET[(chunk ushr 18) and 0x3F])
            builder.append(ALPHABET[(chunk ushr 12) and 0x3F])
            builder.append(ALPHABET[(chunk ushr 6) and 0x3F])
            builder.append(ALPHABET[chunk and 0x3F])
            index += 3
        }
        when (data.size - index) {
            1 -> {
                val chunk = (data[index].toInt() and 0xFF) shl 16
                builder.append(ALPHABET[(chunk ushr 18) and 0x3F])
                builder.append(ALPHABET[(chunk ushr 12) and 0x3F])
                builder.append("==")
            }
            2 -> {
                val chunk = ((data[index].toInt() and 0xFF) shl 16) or
                    ((data[index + 1].toInt() and 0xFF) shl 8)
                builder.append(ALPHABET[(chunk ushr 18) and 0x3F])
                builder.append(ALPHABET[(chunk ushr 12) and 0x3F])
                builder.append(ALPHABET[(chunk ushr 6) and 0x3F])
                builder.append('=')
            }
        }
        return builder.toString()
    }

    /** 非法输入返回 `null`（调用方据此判定「密文不可用」）。 */
    fun decode(text: String): ByteArray? {
        if (text.isEmpty()) return ByteArray(0)
        if (text.length % 4 != 0) return null
        val padding = when {
            text.endsWith("==") -> 2
            text.endsWith("=") -> 1
            else -> 0
        }
        val dataEnd = text.length - padding
        for (position in 0 until dataEnd) {
            if (text[position] == '=') return null
        }
        val out = ByteArray(text.length / 4 * 3 - padding)
        var outIndex = 0
        var index = 0
        while (index < text.length) {
            var buffer = 0
            for (offset in 0 until 4) {
                val char = text[index + offset]
                val value = when {
                    char == '=' -> 0
                    char.code < 128 && REVERSE[char.code] >= 0 -> REVERSE[char.code]
                    else -> return null
                }
                buffer = (buffer shl 6) or value
            }
            if (outIndex < out.size) out[outIndex++] = ((buffer ushr 16) and 0xFF).toByte()
            if (outIndex < out.size) out[outIndex++] = ((buffer ushr 8) and 0xFF).toByte()
            if (outIndex < out.size) out[outIndex++] = (buffer and 0xFF).toByte()
            index += 4
        }
        return out
    }
}
