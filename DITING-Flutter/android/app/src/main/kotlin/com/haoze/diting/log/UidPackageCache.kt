package com.haoze.diting.log

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process
import android.util.LruCache
import java.net.InetAddress
import java.net.InetSocketAddress

/// Resolves packet-origin UIDs to package names for the engine callbacks.
///
/// Ported from 1.4.3 `core/diagnostic/UidPackageCache` and kept behaviourally
/// identical, because both resolvers below are called on the Go hot path:
/// every DNS query and every TCP flow asks for a UID, so an IPC round trip per
/// packet is not affordable. Two LRU levels absorb that:
///  - `StringFlowKey` (5-tuple) -> UID, positive 10s / negative 2s.
///    The asymmetric TTL matters: a negative answer usually means "the socket is
///    not visible to ConnectivityManager yet", which resolves moments later,
///    while a positive answer stays valid for the life of the flow.
///  - UID -> package name, no TTL: the mapping cannot change while the process
///    lives (package installs/removals bump the UID, so a stale entry is dropped
///    by the negative lookup instead of being refreshed).
///
/// API < 29 has no `ConnectivityManager.getConnectionOwnerUid`, so [resolveUid]
/// degrades to `Process.INVALID_UID` and callers fall back to "unknown" instead
/// of mis-attributing traffic. `minSdk` is 24, so this is a reachable path.
class UidPackageCache(context: Context) {
    private val connectivityManager: ConnectivityManager? =
        context.getSystemService(ConnectivityManager::class.java)
    private val packageManager: PackageManager = context.packageManager

    private val flowUidCache = LruCache<StringFlowKey, CachedUid>(FLOW_CACHE_CAPACITY)
    private val uidPackageCache = LruCache<Int, String>(UID_PACKAGE_CACHE_CAPACITY)
    private val lock = Any()

    /// `getConnectionOwnerUid` is API 29+. Below that the platform has no
    /// equivalent (reading `/proc/net` needs root), so this stays false and
    /// [resolveUid] answers INVALID_UID.
    private val ownerUidSupported: Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    data class StringFlowKey(
        val protocol: Long,
        val localIP: String,
        val localPort: Long,
        val remoteIP: String,
        val remotePort: Long,
    )

    private data class CachedUid(val uid: Int, val timestamp: Long)

    /// `UIDResolver.resolveUID` payload: protocol is the IPPROTO number.
    fun resolveUid(
        protocol: Long,
        localIP: String,
        localPort: Long,
        remoteIP: String,
        remotePort: Long,
    ): Int {
        if (!ownerUidSupported) return Process.INVALID_UID
        val cm = connectivityManager ?: return Process.INVALID_UID
        val key = StringFlowKey(protocol, localIP, localPort, remoteIP, remotePort)
        val now = System.currentTimeMillis()

        synchronized(lock) {
            flowUidCache.get(key)?.let { cached ->
                val ttl = if (isKnownUid(cached.uid)) {
                    FLOW_CACHE_TTL_MS
                } else {
                    FLOW_NEGATIVE_CACHE_TTL_MS
                }
                if (now - cached.timestamp < ttl) return cached.uid
            }
        }

        // Direction: `resolveFlowUID` passes `id.appIP` as the FIRST argument
        // (named `localIP` in tunnel.UIDResolver) and `id.serverIP` as
        // `remoteIP`. So the app endpoint — the pair `getConnectionOwnerUid`
        // needs as `local` — is `localIP`, exactly as 1.4.3's
        // CachedConnectionOwnerUidResolver treated it. Swapping these two makes
        // every lookup return INVALID_UID, which silently blanks packageName.
        val uid = runCatching {
            val app = InetAddress.getByName(localIP)
            val server = InetAddress.getByName(remoteIP)
            cm.getConnectionOwnerUid(
                protocol.toInt(),
                InetSocketAddress(app, localPort.toInt()),
                InetSocketAddress(server, remotePort.toInt()),
            )
        }.getOrDefault(Process.INVALID_UID)

        synchronized(lock) { flowUidCache.put(key, CachedUid(uid, now)) }
        return uid
    }

    /// `AppUidResolver.packageForUid` payload. Empty string means "unknown" —
    /// the Go side writes that verbatim into `dns_log.packageName`'s `a` field,
    /// and [DnsLogWriter] converts a blank value to NULL.
    fun packageForUid(uid: Int): String {
        if (!isKnownUid(uid)) return ""
        synchronized(lock) { uidPackageCache.get(uid)?.let { return it } }
        val resolved = runCatching {
            packageManager.getPackagesForUid(uid)?.firstOrNull()
        }.getOrNull().orEmpty()
        if (resolved.isNotEmpty()) {
            synchronized(lock) { uidPackageCache.put(uid, resolved) }
        }
        return resolved
    }

    fun clear() {
        synchronized(lock) {
            flowUidCache.evictAll()
            uidPackageCache.evictAll()
        }
    }

    private fun isKnownUid(uid: Int): Boolean = uid > 0 && uid != Process.INVALID_UID

    private companion object {
        const val FLOW_CACHE_CAPACITY = 1024
        const val UID_PACKAGE_CACHE_CAPACITY = 256
        const val FLOW_CACHE_TTL_MS = 10_000L
        const val FLOW_NEGATIVE_CACHE_TTL_MS = 2_000L
    }
}
