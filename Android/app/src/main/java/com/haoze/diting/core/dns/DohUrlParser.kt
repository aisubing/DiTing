package com.haoze.diting.core.dns

import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl

/**
 * Parses DoH endpoints defensively.
 *
 * `String.toHttpUrl()` throws [IllegalArgumentException] for anything that is not
 * a well-formed http(s) URL — an empty string, a missing scheme, a bad host. The
 * latency tester used to call it outside its try block, so a provider with a
 * malformed URL (reachable through config import or a hand-edited provider)
 * crashed the whole speed test instead of just failing that one provider.
 */
object DohUrlParser {
    /** Returns the parsed URL, or null when [raw] is not a usable DoH endpoint. */
    fun parseOrNull(raw: String?): HttpUrl? {
        val trimmed = raw?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        return runCatching { trimmed.toHttpUrl() }.getOrNull()
    }

    /** Failure message for a provider whose DoH URL could not be parsed. */
    fun invalidUrlMessage(raw: String?): String {
        val trimmed = raw?.trim().orEmpty()
        return if (trimmed.isEmpty()) "DoH 地址为空" else "DoH 地址无效：$trimmed"
    }
}
