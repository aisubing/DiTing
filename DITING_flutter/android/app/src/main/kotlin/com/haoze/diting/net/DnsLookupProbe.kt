package com.haoze.diting.net

import org.json.JSONArray
import org.json.JSONObject
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress

/**
 * One manual DNS lookup, in the shape `DnsLookupResult.fromMap` reads:
 * `{domain,source,answers,elapsedMs,error}` with `answers` entries of
 * `{type,value,ttl}` and `source` in `upstream` / `rewrite` / `blocked` /
 * `error` (the Dart model also documents `cache`, which this path never
 * produces — see below).
 *
 * Two backends:
 * - **tunnel** (`viaTunnel=true`): `Engine.resolveDomain(domain, ipv4)`, i.e. the
 *   running tunnel's own decision path — rewrite map, then policy blocking, then
 *   the configured upstream. The JSON contract is the engine's
 *   (`source ∈ {rewrite, blocked, upstream, nodata}` or `{error:...}`), parsed the
 *   same way 1.4.3's `TunnelDiagnosticsResolver` parsed it.
 * - **system** (`viaTunnel=false`): `InetAddress.getAllByName`, i.e. whatever the
 *   device resolver answers. TTL is unavailable there, so answers report `ttl: 0`
 *   rather than inventing a value.
 *
 * `cache` is never reported: `Engine.resolveDomain` consults the rewrite map and
 * policy engine, then goes straight to the upstream resolver — it does not read
 * the DNS cache, so claiming a cache hit would be a fabrication.
 */
internal object DnsLookupProbe {

    fun lookup(domain: String, viaTunnel: Boolean, ipv4: Boolean): Map<String, Any?> {
        val host = NetHost.sanitize(domain)
        // `domain` in the result names what was actually looked up, so the empty
        // case reports "" rather than echoing the raw input back.
        if (host.isEmpty()) return error("", "请输入要查询的域名")
        return if (viaTunnel) tunnelLookup(host, ipv4) else systemLookup(host, ipv4)
    }

    private fun tunnelLookup(host: String, ipv4: Boolean): Map<String, Any?> {
        val engine = EngineAccess.current()
            ?: return error(host, "隧道未运行，无法经内核解析（可用系统解析）")

        val startedAt = System.nanoTime()
        val raw = runCatching { engine.resolveDomain(host, ipv4) }.getOrNull()
        val elapsed = (System.nanoTime() - startedAt) / 1_000_000.0
        if (raw.isNullOrBlank()) return error(host, "隧道解析未返回结果", elapsed)

        val json = runCatching { JSONObject(raw) }.getOrNull()
            ?: return error(host, "隧道解析结果无效", elapsed)

        // Error object wins over everything else: the engine returns
        // `{"error":"tunnel resolver not active"}` when there is no upstream yet.
        json.optString("error").takeIf { it.isNotEmpty() }?.let { message ->
            return error(host, translateEngineError(message), elapsed)
        }

        val source = json.optString("source")
        val answers = answersOf(json.optJSONArray("ips"), json.optJSONArray("ttls"), ipv4)
        val reason = json.optString("reason").takeIf { it.isNotEmpty() }

        return when (source) {
            "rewrite", "upstream", "blocked" -> result(host, source, answers, elapsed, null)
            // `nodata` is "the resolver answered, but with no address record".
            // The Dart model has no such label; reporting it as `upstream` would
            // claim an answer that does not exist, so it is surfaced as an error
            // whose text names the actual rcode.
            else -> error(host, noDataMessage(reason), elapsed)
        }
    }

    private fun systemLookup(host: String, ipv4: Boolean): Map<String, Any?> {
        val startedAt = System.nanoTime()
        val addresses = runCatching { InetAddress.getAllByName(host) }.getOrNull()
            ?: return error(
                host,
                "系统解析失败，请检查网络或域名",
                (System.nanoTime() - startedAt) / 1_000_000.0,
            )
        val elapsed = (System.nanoTime() - startedAt) / 1_000_000.0
        val answers = addresses.mapNotNull { address ->
            when {
                ipv4 && address is Inet4Address -> answer("A", address.hostAddress ?: "")
                !ipv4 && address is Inet6Address -> answer("AAAA", address.hostAddress ?: "")
                else -> null
            }
        }
        if (answers.isEmpty()) return error(host, "系统解析未返回对应记录", elapsed)
        // The OS resolver did reach *a* resolver (possibly the tunnel's own DNS
        // when the VPN is up); that is what `upstream` means in this contract.
        return result(host, "upstream", answers, elapsed, null)
    }

    private fun answersOf(ips: JSONArray?, ttls: JSONArray?, ipv4: Boolean): List<Map<String, Any?>> {
        if (ips == null) return emptyList()
        val type = if (ipv4) "A" else "AAAA"
        val answers = mutableListOf<Map<String, Any?>>()
        for (index in 0 until ips.length()) {
            val value = ips.optString(index).takeIf { it.isNotEmpty() } ?: continue
            answers.add(
                mapOf(
                    "type" to type,
                    "value" to value,
                    // TTLs are optional in the engine payload; 0 means "not
                    // reported", never "expired".
                    "ttl" to (ttls?.optInt(index, 0) ?: 0),
                ),
            )
        }
        return answers
    }

    private fun answer(type: String, value: String): Map<String, Any?> =
        mapOf("type" to type, "value" to value, "ttl" to 0)

    /** Same wording 1.4.3's `errorLabel()` used for the one token users hit. */
    private fun translateEngineError(raw: String): String = when (raw) {
        "tunnel resolver not active" -> "隧道解析器未就绪（DNS 尚未生效）"
        "empty domain" -> "请输入要查询的域名"
        else -> raw
    }

    private fun noDataMessage(reason: String?): String = when {
        reason == null -> "解析未返回地址记录"
        reason.contains("NXDOMAIN", ignoreCase = true) -> "域名不存在（NXDOMAIN）"
        reason.contains("SERVFAIL", ignoreCase = true) -> "上游解析失败（SERVFAIL）"
        reason == "no answer records" -> "解析未返回地址记录"
        else -> "解析无结果：$reason"
    }

    private fun result(
        domain: String,
        source: String,
        answers: List<Map<String, Any?>>,
        elapsedMs: Double,
        error: String?,
    ): Map<String, Any?> = mapOf(
        "domain" to domain,
        "source" to source,
        "answers" to answers,
        "elapsedMs" to elapsedMs,
        "error" to error,
    )

    private fun error(domain: String, message: String, elapsedMs: Double = 0.0) =
        result(domain, "error", emptyList(), elapsedMs, message)
}
