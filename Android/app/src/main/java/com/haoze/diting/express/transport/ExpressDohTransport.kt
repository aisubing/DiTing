package com.haoze.diting.express.transport

import com.haoze.diting.core.dns.DnsLatencyTester
import com.haoze.diting.express.dns.ExpressDnsMessageUtils
import com.haoze.diting.core.dns.DNS_UPSTREAM_TIMEOUT_MS
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.ConnectionSpec
import okhttp3.Dns
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.net.InetAddress
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import javax.net.SocketFactory
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Isolated DNS-over-HTTPS (DoH) transport for Express Mode.
 *
 * Source-level adaptation of DoH POST implementation from DnsLatencyTester.kt
 * with OkHttp, bootstrap DNS binding, socket protection, and coroutine cancellation.
 */
object ExpressDohTransport {

    private val DNS_MEDIA_TYPE = "application/dns-message".toMediaType()

    // Reuse one OkHttpClient per configuration. Each client owns a connection
    // pool and a dispatcher thread pool; building a new one per query leaked
    // threads, file descriptors and connections under sustained DNS traffic.
    // Keyed by timeout + DoH host + bootstrap addresses + socket protector, all
    // of which are effectively fixed per provider, so the map stays tiny.
    private const val MAX_CACHED_CLIENTS = 16
    private val clients = ConcurrentHashMap<ClientKey, OkHttpClient>()

    /**
     * The protector is part of the key by identity, so two different lambdas never
     * share a client. It also means the map holds the protector (and through it
     * the owning VpnService) alive, which is why [releaseClients] must be called
     * when the VPN session ends.
     */
    private class ClientKey(
        val timeoutMs: Long,
        val host: String?,
        val addresses: List<InetAddress>?,
        val protector: ((Socket) -> Boolean)?
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (other !is ClientKey) return false
            return timeoutMs == other.timeoutMs &&
                host == other.host &&
                addresses == other.addresses &&
                protector === other.protector
        }

        override fun hashCode(): Int {
            var result = timeoutMs.hashCode()
            result = 31 * result + (host?.hashCode() ?: 0)
            result = 31 * result + (addresses?.hashCode() ?: 0)
            result = 31 * result + System.identityHashCode(protector)
            return result
        }
    }

    private fun clientFor(
        timeoutMs: Long,
        httpUrl: HttpUrl,
        addresses: List<InetAddress>?,
        protectSocket: ((Socket) -> Boolean)?
    ): OkHttpClient {
        val host = httpUrl.host
        val key = ClientKey(
            timeoutMs = timeoutMs,
            host = if (addresses.isNullOrEmpty()) null else host,
            addresses = addresses,
            protector = protectSocket
        )
        clients[key]?.let { return it }

        val created = buildClient(timeoutMs, host, addresses, protectSocket)
        // getOrPut is not atomic on ConcurrentHashMap: a racing caller may have
        // won, in which case drop the client we just built instead of leaking it.
        val existing = clients.putIfAbsent(key, created)
        if (existing != null) {
            created.closeQuietly()
            return existing
        }
        evictOverflow()
        return created
    }

    private fun buildClient(
        timeoutMs: Long,
        host: String,
        addresses: List<InetAddress>?,
        protectSocket: ((Socket) -> Boolean)?
    ): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .connectTimeout(timeoutMs, TimeUnit.MILLISECONDS)
            .readTimeout(timeoutMs, TimeUnit.MILLISECONDS)
            .callTimeout(timeoutMs, TimeUnit.MILLISECONDS)
            .connectionSpecs(listOf(ConnectionSpec.MODERN_TLS))
        if (protectSocket != null) {
            builder.socketFactory(ExpressProtectingSocketFactory(protectSocket))
        }
        if (!addresses.isNullOrEmpty()) {
            builder.dns(object : Dns {
                override fun lookup(hostname: String): List<InetAddress> {
                    return if (hostname.equals(host, ignoreCase = true)) {
                        addresses
                    } else {
                        Dns.SYSTEM.lookup(hostname)
                    }
                }
            })
        }
        return builder.build()
    }

    /** Trims the cache down to [MAX_CACHED_CLIENTS], closing what it drops. */
    private fun evictOverflow() {
        if (clients.size <= MAX_CACHED_CLIENTS) return
        clients.keys.take(clients.size - MAX_CACHED_CLIENTS).forEach { key ->
            clients.remove(key)?.closeQuietly()
        }
    }

    /**
     * Drops every cached client, shutting down its dispatcher and connection
     * pool. Must be called when the VPN session that supplied the socket
     * protectors ends: the protectors reference the service, so keeping the
     * clients would retain a whole service graph per session.
     *
     * A client is rebuilt lazily on the next query, so calling this while a query
     * is in flight only fails that query, which the caller retries.
     */
    fun releaseClients() {
        clients.keys.toList().forEach { key ->
            clients.remove(key)?.closeQuietly()
        }
    }

    private fun OkHttpClient.closeQuietly() {
        runCatching { dispatcher.executorService.shutdown() }
        runCatching { connectionPool.evictAll() }
        runCatching { cache?.close() }
    }

    suspend fun query(
        url: String,
        bootstrapAddresses: List<InetAddress>? = null,
        protectSocket: ((Socket) -> Boolean)? = null,
        query: ByteArray,
        timeoutMs: Long = DNS_UPSTREAM_TIMEOUT_MS.toLong()
    ): ByteArray {
        val httpUrl = url.toHttpUrl()
        val addresses = bootstrapAddresses?.takeIf { it.isNotEmpty() }
        val client = clientFor(timeoutMs, httpUrl, addresses, protectSocket)

        val request = Request.Builder()
            .url(httpUrl)
            .post(query.toRequestBody(DNS_MEDIA_TYPE))
            .header("Accept", DNS_MEDIA_TYPE.toString())
            .header("Content-Type", DNS_MEDIA_TYPE.toString())
            .build()

        val call = client.newCall(request)
        val response = call.await()
        return response.use { r ->
            if (!r.isSuccessful) {
                throw IOException("DoH HTTP error ${r.code}")
            }
            val body = r.body?.bytes() ?: throw IOException("Empty DoH response body")
            if (!ExpressDnsMessageUtils.isUsableUpstreamResponse(body, query)) {
                throw IOException("DoH server returned invalid DNS response")
            }
            body
        }
    }

    private suspend fun Call.await(): Response = suspendCancellableCoroutine { continuation ->
        continuation.invokeOnCancellation {
            cancel()
        }
        enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                if (continuation.isActive) {
                    continuation.resumeWithException(e)
                }
            }

            override fun onResponse(call: Call, response: Response) {
                if (continuation.isActive) {
                    continuation.resume(response)
                }
            }
        })
    }

    private class ExpressProtectingSocketFactory(
        private val protectSocket: (Socket) -> Boolean,
        private val delegate: SocketFactory = SocketFactory.getDefault()
    ) : SocketFactory() {
        private fun protect(socket: Socket): Socket {
            protectSocket(socket)
            return socket
        }

        override fun createSocket(): Socket = protect(delegate.createSocket())

        override fun createSocket(host: String?, port: Int): Socket =
            protect(delegate.createSocket(host, port))

        override fun createSocket(host: String?, port: Int, localHost: InetAddress?, localPort: Int): Socket =
            protect(delegate.createSocket(host, port, localHost, localPort))

        override fun createSocket(host: InetAddress?, port: Int): Socket =
            protect(delegate.createSocket(host, port))

        override fun createSocket(address: InetAddress?, port: Int, localAddress: InetAddress?, localPort: Int): Socket =
            protect(delegate.createSocket(address, port, localAddress, localPort))
    }
}
