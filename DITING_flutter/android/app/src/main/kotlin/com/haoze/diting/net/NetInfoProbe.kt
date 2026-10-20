package com.haoze.diting.net

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import java.net.Inet4Address
import java.net.Inet6Address

/**
 * Snapshot of the *physical* network, ported from 1.4.3 `NetworkInfoProbe`.
 *
 * The probes deliberately describe the underlying Wi-Fi/cellular link, not the
 * TUN device: the tools measure the real path, because 1.4.3 added this app's own
 * UID to `addDisallowedApplication`. `vpnActive` therefore answers a different
 * question — "is a VPN transport up at the same time" — and the UI shows it as a
 * separate note.
 *
 * Result shape matches `NetworkInfoSnapshot.fromMap`: `{interfaceName,
 * localIpv4, localIpv6, dnsServers, gateway, vpnActive, privateDns}`.
 */
internal object NetInfoProbe {

    fun snapshot(context: Context): Map<String, Any?> {
        val manager = runCatching {
            context.getSystemService(ConnectivityManager::class.java)
        }.getOrNull() ?: return empty()

        return runCatching { read(manager) }.getOrDefault(empty())
    }

    // `allNetworks` is deprecated since API 31 with no synchronous replacement;
    // this is a one-shot snapshot, same as 1.4.3's probe.
    @Suppress("DEPRECATION")
    private fun read(manager: ConnectivityManager): Map<String, Any?> {
        val networks = manager.allNetworks.toList()
        val vpnActive = networks.any { network ->
            manager.getNetworkCapabilities(network)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        }

        val active = manager.activeNetwork
        val candidate = when {
            active != null && isPhysical(manager, active) -> active
            else -> networks
                .filter { it != active && isPhysical(manager, it) }
                .firstOrNull {
                    manager.getNetworkCapabilities(it)
                        ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                }
                ?: networks.firstOrNull { isPhysical(manager, it) }
        } ?: return empty(vpnActive = vpnActive)

        val link = manager.getLinkProperties(candidate) ?: return empty(vpnActive = vpnActive)

        val ipv4 = mutableListOf<String>()
        val ipv6 = mutableListOf<String>()
        link.linkAddresses.forEach { linkAddress ->
            val address = linkAddress.address
            if (address.isLoopbackAddress) return@forEach
            val host = address.hostAddress ?: return@forEach
            when (address) {
                is Inet4Address -> ipv4.add(host)
                // Link-local IPv6 needs a scope id to be usable in a request,
                // and 1.4.3 filtered it out for the same reason.
                is Inet6Address -> if (!address.isLinkLocalAddress) ipv6.add(host)
            }
        }

        return mapOf(
            "interfaceName" to (link.interfaceName ?: ""),
            "localIpv4" to (ipv4.firstOrNull() ?: ""),
            "localIpv6" to ipv6.firstOrNull(),
            "dnsServers" to link.dnsServers.mapNotNull { it.hostAddress },
            "gateway" to link.routes.firstOrNull { it.gateway != null }?.gateway?.hostAddress,
            "vpnActive" to vpnActive,
            "privateDns" to privateDnsLabel(link),
        )
    }

    /**
     * Private DNS has three observable states:
     * - `off`: inactive;
     * - `opportunistic`: active with no hostname (auto-upgrade mode);
     * - `hostname`: active with a configured resolver name.
     *
     * A configured-but-inactive hostname still reports its name on some devices,
     * so `isPrivateDnsActive` decides between `off` and the two active modes —
     * reporting the stale name while the feature is off would be a lie.
     *
     * Both accessors are API 28; on older platforms the feature does not exist,
     * so `off` is the honest answer rather than a guess.
     */
    private fun privateDnsLabel(link: LinkProperties): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return "off"
        val active = runCatching { link.isPrivateDnsActive }.getOrDefault(false)
        if (!active) return "off"
        val name = runCatching { link.privateDnsServerName }.getOrNull()
        return if (name.isNullOrEmpty()) "opportunistic" else "hostname"
    }

    private fun isPhysical(manager: ConnectivityManager, network: Network): Boolean {
        val caps = manager.getNetworkCapabilities(network) ?: return false
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
    }

    /** Shape-compatible empty snapshot: the Dart model requires non-null fields. */
    private fun empty(vpnActive: Boolean = false): Map<String, Any?> = mapOf(
        "interfaceName" to "",
        "localIpv4" to "",
        "localIpv6" to null,
        "dnsServers" to emptyList<String>(),
        "gateway" to null,
        "vpnActive" to vpnActive,
        "privateDns" to "off",
    )
}
