package com.haoze.diting.core.diagnostic

import com.haoze.diting.core.dns.DnsMessageUtils
import android.content.Context
import com.haoze.diting.data.RuleDataset
import com.haoze.diting.ui.settings.BootstrapDnsSettingsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.coroutines.cancellation.CancellationException
import kotlin.math.max
import java.io.IOException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

/**
 * Resolves hosts through the user's Bootstrap DNS list.
 *
 * [dataset] selects which settings set the Bootstrap list comes from: the
 * ordinary tunnel reads [RuleDataset.NORMAL], the Express engine reads
 * [RuleDataset.EXPRESS]. Reading the wrong one made the Express engine ignore
 * the user's Express Bootstrap configuration entirely.
 */
class BootstrapSelector(
    private val context: Context,
    private val healthEngine: BootstrapHealthEngine,
    private val logger: BootstrapLogger? = null,
    private val protectDatagramSocket: ((DatagramSocket) -> Boolean)? = null,
    private val dataset: RuleDataset = RuleDataset.NORMAL
) {
    private val cacheLock = Any()
    private val hostCache = HashMap<String, CachedBootstrapResolution>()

    suspend fun resolveHost(host: String): List<InetAddress> = withContext(Dispatchers.IO) {
        val entries = BootstrapDnsSettingsStore.loadEnabledBootstrapIpEntries(context, dataset)
        if (!BootstrapDnsSettingsStore.isBootstrapEnabled(context, dataset) || entries.isEmpty()) {
            return@withContext emptyList()
        }
        val normalizedHost = host.lowercase()
        val sourceKey = entries.joinToString(separator = "|") { "${it.id}:${it.ip}" }
        getCached(normalizedHost, sourceKey)?.let { return@withContext it }

        val plan = healthEngine.choosePlan(entries)
        val orderedIndices = buildList {
            if (plan.primaryIndex in entries.indices) add(plan.primaryIndex)
            plan.fallbackIndices.forEach { index ->
                if (index in entries.indices && index !in this) add(index)
            }
        }
        if (orderedIndices.isEmpty()) return@withContext emptyList()

        var lastError: Throwable? = null
        orderedIndices.forEachIndexed { attemptIndex, entryIndex ->
            val entry = entries[entryIndex]
            val startedAt = System.nanoTime()
            // Only the Bootstrap DNS round trip belongs inside this try: health
            // bookkeeping and log persistence are side effects, and letting their
            // failures reach the catch block recorded a successful resolution as a
            // failure (double count) and evicted the freshly cached entry.
            val addresses = try {
                resolveWithBootstrapDns(host, entry.ip).also { resolved ->
                    if (resolved.isEmpty()) {
                        throw IOException("Bootstrap DNS returned no A/AAAA records")
                    }
                }
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                lastError = e
                removeCached(normalizedHost)
                recordOutcome(
                    entry = entry,
                    host = host,
                    success = false,
                    elapsedMs = max(1L, (System.nanoTime() - startedAt) / 1_000_000L),
                    fallbackUsed = attemptIndex > 0,
                    message = e.message
                )
                null
            }

            if (addresses != null) {
                putCached(normalizedHost, sourceKey, addresses)
                recordOutcome(
                    entry = entry,
                    host = host,
                    success = true,
                    elapsedMs = max(1L, (System.nanoTime() - startedAt) / 1_000_000L),
                    fallbackUsed = attemptIndex > 0,
                    message = "exploration".takeIf { plan.exploration && attemptIndex == 0 }
                )
                return@withContext addresses
            }
        }
        throw lastError ?: IllegalStateException("All Bootstrap DNS attempts failed")
    }

    /**
     * Records the outcome without letting the health store or the log database
     * decide whether the resolution itself succeeded.
     */
    private suspend fun recordOutcome(
        entry: BootstrapIpEntry,
        host: String,
        success: Boolean,
        elapsedMs: Long,
        fallbackUsed: Boolean,
        message: String?
    ) {
        try {
            healthEngine.recordResult(entry.id, success = success, elapsedMs = elapsedMs)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // Health bookkeeping is advisory; never fail the resolution over it.
        }
        try {
            logger?.log(
                ipId = entry.id,
                ipName = entry.name,
                ip = entry.ip,
                host = host,
                success = success,
                elapsedMs = elapsedMs,
                fallbackUsed = fallbackUsed,
                message = message
            )
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // A log write failure must not be reported as a DNS failure.
        }
    }

    private fun getCached(host: String, sourceKey: String): List<InetAddress>? {
        val now = System.currentTimeMillis()
        return synchronized(cacheLock) {
            val cached = hostCache[host] ?: return@synchronized null
            if (cached.sourceKey == sourceKey && now < cached.expiresAt) {
                cached.addresses
            } else {
                hostCache.remove(host)
                null
            }
        }
    }

    private fun putCached(host: String, sourceKey: String, addresses: List<InetAddress>) {
        synchronized(cacheLock) {
            hostCache[host] = CachedBootstrapResolution(
                sourceKey = sourceKey,
                expiresAt = System.currentTimeMillis() + HOST_CACHE_TTL_MS,
                addresses = addresses
            )
        }
    }

    private fun removeCached(host: String) {
        synchronized(cacheLock) {
            hostCache.remove(host)
        }
    }

    private fun resolveWithBootstrapDns(host: String, bootstrapIp: String): List<InetAddress> {
        val addresses = mutableListOf<InetAddress>()
        var lastError: Exception? = null

        listOf(DnsMessageUtils.TYPE_A, DnsMessageUtils.TYPE_AAAA).forEach { qtype ->
            try {
                val query = DnsMessageUtils.buildQuery(host, qtype)
                val response = queryUdp(bootstrapIp, query)
                addresses += DnsMessageUtils.extractAddressRecords(response)
            } catch (e: Exception) {
                lastError = e
            }
        }

        val distinct = addresses.distinctBy { it.hostAddress }
        if (distinct.isEmpty() && lastError != null) {
            throw IOException("Bootstrap DNS lookup failed for $host via $bootstrapIp", lastError)
        }
        return distinct
    }

    private fun queryUdp(bootstrapIp: String, query: ByteArray): ByteArray {
        DatagramSocket().use { socket ->
            protectDatagramSocket?.invoke(socket)
            socket.soTimeout = DNS_TIMEOUT_MS
            val server = InetAddress.getByName(bootstrapIp)
            val request = DatagramPacket(query, query.size, server, DNS_PORT)
            socket.send(request)

            val buffer = ByteArray(DNS_RESPONSE_BUFFER_SIZE)
            val response = DatagramPacket(buffer, buffer.size)
            socket.receive(response)

            val bytes = response.data.copyOf(response.length)
            if (DnsMessageUtils.transactionId(bytes) != DnsMessageUtils.transactionId(query)) {
                throw IOException("Mismatched DNS transaction ID")
            }
            if (DnsMessageUtils.isTruncatedResponse(bytes)) {
                throw IOException("Truncated DNS response")
            }
            return bytes
        }
    }

    companion object {
        private const val DNS_PORT = 53
        private const val DNS_TIMEOUT_MS = 3_000
        private const val DNS_RESPONSE_BUFFER_SIZE = 1500
        private const val HOST_CACHE_TTL_MS = 60_000L
    }
}

private data class CachedBootstrapResolution(
    val sourceKey: String,
    val expiresAt: Long,
    val addresses: List<InetAddress>
)
