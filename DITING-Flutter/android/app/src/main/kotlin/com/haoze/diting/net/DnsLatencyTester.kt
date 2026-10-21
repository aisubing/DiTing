package com.haoze.diting.net

import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URL
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory
import kotlin.math.roundToLong

/**
 * Measures the real round-trip latency of one DNS provider, ported from
 * 1.4.3's `core/dns/DnsLatencyTester`.
 *
 * The old app used OkHttp for the DoH path. This port has no third-party HTTP
 * dependency (the Flutter module ships only the Go tunnel AAR), so DoH goes
 * through `HttpURLConnection` and plain/DoT go through raw sockets. The
 * measurement contract is identical to the original:
 *
 * - **Resolve before timing.** DNS-over-TLS and DoH need the server's address
 *   first; host resolution is setup cost, not upstream latency, so the clock
 *   starts only after the socket / connection is ready. Timing the lookup as
 *   well would report tens of extra milliseconds for every provider.
 * - **A failed probe still reports elapsed time** so the UI can show "失败" with
 *   how long it took to fail, exactly like `Result.elapsedMs` did.
 * - **No `VpnService` involvement.** The probe sends a single A-record query
 *   straight to the provider; the app's own UID is excluded from the tunnel
 *   (`addDisallowedApplication`), so no request loop can form.
 *
 * Everything here blocks. The bridge runs it on a worker pool and posts the
 * result back to the platform thread.
 */
object DnsLatencyTester {

    /** One provider as handed down by the Dart layer. */
    data class Spec(
        val id: String,
        val name: String,
        val host: String,
        val port: Int,
        val protocol: Protocol,
        /**
         * DoH 的完整查询地址。
         *
         * 仓内预设目录（`defaultDnsProviders`）对 DoH 服务商只存 url、不存 host，
         * Dart 侧虽然会从 url 里解析 host 一起下发，但**原始 url 才是权威**：有的
         * 服务商路径不是 `/dns-query`（例如 `/resolve`），按约定拼路径会 404 而
         * 表现为「测速失败」。因此 DoH 探测优先用这个字段。DNS / DoT 服务商为空串。
         */
        val url: String = "",
    )

    enum class Protocol(val wire: String) {
        DNS("dns"),
        DOH("doh"),
        DOT("dot");

        companion object {
            fun fromWire(value: String?): Protocol =
                entries.firstOrNull { it.wire == value } ?: DNS
        }
    }

    /** One probe result. Mirrors the map the Dart side decodes. */
    data class Sample(
        val providerId: String,
        val providerName: String,
        val protocol: Protocol,
        val elapsedMs: Long,
        val success: Boolean,
        val message: String?,
        val attempts: Int,
        val successCount: Int,
        val elapsedSamplesMs: List<Long>,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "providerId" to providerId,
            "providerName" to providerName,
            "protocol" to protocol.wire,
            "elapsedMs" to elapsedMs,
            "success" to success,
            "message" to message,
            "attempts" to attempts,
            "successCount" to successCount,
            "elapsedSamplesMs" to elapsedSamplesMs,
        )
    }

    private const val TIMEOUT_MS = 5000
    private const val DEFAULT_PORT = 53
    private const val DEFAULT_DOT_PORT = 853

    /**
     * Runs [attempts] real queries against [spec] and averages the successful
     * samples.
     *
     * All attempts failing yields one `success = false` sample carrying the last
     * error message; a mix yields `success = true` with `successCount` telling
     * how many of them worked. This is 1.4.3's `testAverage` semantics, and the
     * UI shows both numbers ("3/3" vs "2/3").
     */
    fun probeAverage(spec: Spec, domain: String, attempts: Int): Sample {
        val safeAttempts = attempts.coerceAtLeast(1)
        val single = (1..safeAttempts).map { probeOnce(spec, domain) }
        val successful = single.filter { it.success }
        if (successful.isEmpty()) {
            return Sample(
                providerId = spec.id,
                providerName = spec.name,
                protocol = spec.protocol,
                elapsedMs = 0L,
                success = false,
                message = single.lastOrNull()?.message ?: "无响应",
                attempts = safeAttempts,
                successCount = 0,
                elapsedSamplesMs = emptyList(),
            )
        }
        val samples = successful.map { it.elapsedMs }
        return Sample(
            providerId = spec.id,
            providerName = spec.name,
            protocol = spec.protocol,
            elapsedMs = samples.average().roundToLong().coerceAtLeast(1L),
            success = true,
            message = single.firstOrNull { !it.success }?.message,
            attempts = safeAttempts,
            successCount = successful.size,
            elapsedSamplesMs = samples,
        )
    }

    /** One probe. Never throws: failures come back as `success = false`. */
    private fun probeOnce(spec: Spec, domain: String): Sample {
        val query = buildQuery(domain)
        val started = System.currentTimeMillis()
        return try {
            when (spec.protocol) {
                Protocol.DNS -> {
                    val response = queryPlain(spec, query)
                    finish(spec, response, started, isSuccess(response))
                }
                Protocol.DOH -> {
                    val response = queryDoh(spec, query)
                    finish(spec, response, started, isSuccess(response))
                }
                Protocol.DOT -> {
                    val response = queryDot(spec, query)
                    finish(spec, response, started, isSuccess(response))
                }
            }
        } catch (e: Exception) {
            Sample(
                providerId = spec.id,
                providerName = spec.name,
                protocol = spec.protocol,
                elapsedMs = (System.currentTimeMillis() - started).coerceAtLeast(1L),
                success = false,
                message = e.message ?: e.javaClass.simpleName,
                attempts = 1,
                successCount = 0,
                elapsedSamplesMs = emptyList(),
            )
        }
    }

    private fun finish(
        spec: Spec,
        response: ByteArray,
        started: Long,
        success: Boolean,
    ): Sample {
        val elapsed = (System.currentTimeMillis() - started).coerceAtLeast(1L)
        return Sample(
            providerId = spec.id,
            providerName = spec.name,
            protocol = spec.protocol,
            elapsedMs = elapsed,
            success = success,
            message = if (success) null else "响应异常",
            attempts = 1,
            successCount = if (success) 1 else 0,
            elapsedSamplesMs = if (success) listOf(elapsed) else emptyList(),
        )
    }

    // ------------------------------------------------------------------ DNS

    /**
     * Plain DNS over UDP.
     *
     * Address resolution happens before the clock starts (see the class doc), and
     * an IP literal in `host` short-circuits it: `InetAddress.getByName` on a
     * literal is a no-op parse, but skipping it makes the intent obvious.
     */
    private fun queryPlain(spec: Spec, query: ByteArray): ByteArray {
        val port = if (spec.port > 0) spec.port else DEFAULT_PORT
        val address = InetAddress.getByName(spec.host)
        DatagramSocket().use { socket ->
            socket.soTimeout = TIMEOUT_MS
            socket.send(DatagramPacket(query, query.size, address, port))
            val buffer = ByteArray(4096)
            val packet = DatagramPacket(buffer, buffer.size)
            socket.receive(packet)
            return packet.data.copyOf(packet.length)
        }
    }

    // ------------------------------------------------------------------ DoT

    private fun queryDot(spec: Spec, query: ByteArray): ByteArray {
        val port = if (spec.port > 0) spec.port else DEFAULT_DOT_PORT
        val factory = SSLSocketFactory.getDefault() as SSLSocketFactory
        val socket = factory.createSocket() as SSLSocket
        socket.use {
            it.soTimeout = TIMEOUT_MS
            it.connect(InetSocketAddress(spec.host, port), TIMEOUT_MS)
            it.startHandshake()
            // DNS-over-TCP framing: a two-byte big-endian length prefix.
            val out = DataOutputStream(it.outputStream)
            out.writeShort(query.size)
            out.write(query)
            out.flush()
            val input = DataInputStream(it.inputStream)
            val length = input.readUnsignedShort()
            val response = ByteArray(length)
            input.readFully(response)
            return response
        }
    }

    // ------------------------------------------------------------------ DoH

    /**
     * DNS-over-HTTPS (RFC 8484): POST the raw wire-format query.
     *
     * Prefers [Spec.url] when the Dart layer supplied one: provider directories
     * store DoH as a full endpoint URL and some of them do not use the
     * `/dns-query` path, so guessing the path turns a working provider into a
     * 404 that reads as "测速失败" in the UI. Only when the url is absent does it
     * fall back to `https://<host>/dns-query`.
     */
    private fun queryDoh(spec: Spec, query: ByteArray): ByteArray {
        val endpoint = when {
            spec.url.isNotBlank() -> spec.url
            spec.host.startsWith("http") -> spec.host
            else -> "https://${spec.host}/dns-query"
        }
        val connection = URL(endpoint).openConnection() as java.net.HttpURLConnection
        connection.requestMethod = "POST"
        connection.connectTimeout = TIMEOUT_MS
        connection.readTimeout = TIMEOUT_MS
        connection.doOutput = true
        connection.setRequestProperty("Content-Type", DNS_MEDIA_TYPE)
        connection.setRequestProperty("Accept", DNS_MEDIA_TYPE)
        connection.outputStream.use { it.write(query) }
        try {
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IllegalStateException("HTTP $code")
            }
            return connection.inputStream.use { it.readBytes() }
        } finally {
            connection.disconnect()
        }
    }

    // --------------------------------------------------------------- packing

    /**
     * Builds a minimal A-record query for [domain] with recursion desired.
     *
     * Hand-rolled instead of pulling a DNS library: the probe only needs one
     * fixed shape (one question, type A, class IN), and a missing dependency is
     * cheaper than a wrapper nobody else uses. QNAME is length-prefixed labels
     * terminated by a zero byte; a 16-bit random id keeps concurrent probes from
     * being confused with each other.
     */
    private fun buildQuery(domain: String): ByteArray {
        val out = ByteArrayOutputStream()
        val data = DataOutputStream(out)
        val id = (System.nanoTime() and 0xFFFF).toInt()
        data.writeShort(id) // ID
        data.writeShort(0x0100) // RD = 1
        data.writeShort(1) // QDCOUNT
        data.writeShort(0) // ANCOUNT
        data.writeShort(0) // NSCOUNT
        data.writeShort(0) // ARCOUNT
        for (label in domain.trim('.').split('.')) {
            val bytes = label.toByteArray(Charsets.US_ASCII)
            if (bytes.size > 63 || bytes.isEmpty()) {
                throw IllegalArgumentException("域名标签非法: $domain")
            }
            data.writeByte(bytes.size)
            data.write(bytes)
        }
        data.writeByte(0) // 根标签结束
        data.writeShort(1) // QTYPE = A
        data.writeShort(1) // QCLASS = IN
        data.flush()
        return out.toByteArray()
    }

    /**
     * True when the response has QR = 1 and RCODE = 0.
     *
     * The check reads only the fixed header: byte 2 bit 7 is QR, byte 3 low
     * nibble is RCODE. A truncated or TCP-framed body would already have thrown
     * while being read, so a length check here would be dead code.
     */
    private fun isSuccess(response: ByteArray): Boolean {
        if (response.size < 12) return false
        val qr = (response[2].toInt() and 0x80) != 0
        val rcode = response[3].toInt() and 0x0F
        return qr && rcode == 0
    }

    private const val DNS_MEDIA_TYPE = "application/dns-message"
}
