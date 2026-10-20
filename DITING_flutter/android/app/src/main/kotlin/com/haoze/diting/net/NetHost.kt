package com.haoze.diting.net

/**
 * Strips protocol prefixes, paths, user info, and ports from pasted input,
 * leaving a bare hostname or IP literal.
 *
 * Ported verbatim from 1.4.3 `NetworkPingTool.sanitizeHost`, including its
 * deliberate blind spots, because the Flutter UI shows exactly the same
 * "无法解析目标地址" message for those inputs:
 *
 * | input                                        | result          |
 * |----------------------------------------------|-----------------|
 * | `https://user:pass@example.com:8443/p?q=1`   | `example.com`   |
 * | `[::1]:53`                                   | `::1`           |
 * | `[2001:db8::1]`                              | `2001:db8::1`   |
 * | `2001:db8::1`                                | `2001:db8::1`   |
 * | `example.com:8443`                           | `example.com`   |
 * | `example.com:`                               | `example.com:`  |
 * | `example.com.`                               | `example.com.`  |
 * | `   `                                        | ``              |
 *
 * Two negative cases are *intentionally* not "fixed" here:
 * - a malformed address such as `2001:db8::1::2` is passed through unchanged —
 *   the resolver rejects it, and inventing a repair would silently probe a
 *   different host than the user typed;
 * - `example.com:` keeps its trailing colon, again because guessing is worse
 *   than a clear resolution failure.
 */
internal object NetHost {

    fun sanitize(input: String): String {
        var value = input.trim()
        if (value.isEmpty()) return value
        val schemeIndex = value.indexOf("://")
        if (schemeIndex >= 0) value = value.substring(schemeIndex + 3)
        val cutIndex = value.indexOfAny(charArrayOf('/', '?', '#'))
        if (cutIndex >= 0) value = value.substring(0, cutIndex)
        val atIndex = value.lastIndexOf('@')
        if (atIndex >= 0) value = value.substring(atIndex + 1)
        if (value.startsWith("[")) {
            val endIndex = value.indexOf(']')
            if (endIndex > 0) value = value.substring(1, endIndex)
            return value
        }
        // Only a *single* colon with an all-digit tail is a port. Without the
        // `::` guard this rule would truncate `2001:db8::1` to `2001`.
        if (!value.contains("::") && value.count { it == ':' } == 1) {
            val afterColon = value.substringAfter(':')
            if (afterColon.isNotEmpty() && afterColon.all { it.isDigit() }) {
                value = value.substringBefore(':')
            }
        }
        return value
    }
}
