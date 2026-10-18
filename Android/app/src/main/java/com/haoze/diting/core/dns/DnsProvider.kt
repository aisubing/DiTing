package com.haoze.diting.core.dns

import com.haoze.diting.core.diagnostic.ProviderHealthStore
import android.content.Context
import android.content.SharedPreferences
import com.haoze.diting.data.RuleDataset
import com.haoze.diting.ui.settings.ResolutionSettingsStore
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.UUID

enum class DnsProtocol(val label: String) {
    DNS("DNS"),
    DOH("DoH"),
    DOT("DoT");

    companion object {
        val MANAGED_PROTOCOLS = listOf(DNS, DOH, DOT)

        fun fromStorage(value: String?): DnsProtocol {
            return entries.firstOrNull { it.name.equals(value, ignoreCase = true) } ?: DOH
        }
    }
}

/**
 * DNS upstream provider. HTTP providers use [url]; DNS and DoT providers use [host] and [port].
 */
data class DnsProvider(
    val id: String,
    val name: String,
    val protocol: DnsProtocol = DnsProtocol.DOH,
    val url: String = "",
    val host: String = "",
    val port: Int = DEFAULT_DOT_PORT,
    val isPreset: Boolean = false
) {
    fun isUserProvider(): Boolean = !isPreset

    fun endpointLabel(): String {
        return when (protocol) {
            DnsProtocol.DNS -> "[${protocol.label}] $host:$port"
            DnsProtocol.DOH -> "[${protocol.label}] $url"
            DnsProtocol.DOT -> "[${protocol.label}] $host:$port"
        }
    }

    companion object {
        const val DEFAULT_DOT_PORT = 853
        const val DEFAULT_DNS_PORT = 53

        private const val PREFS_NAME = "dns_vpn_prefs"
        private const val KEY_USER_PROVIDERS_JSON = "user_providers_json"
        private const val KEY_SELECTED_PROVIDER_ID = "selected_provider_id"
        private const val DEFAULT_SELECTED_PROVIDER_ID = "preset_alidns_dns"

        val PRESETS = listOf(
            DnsProvider(
                id = "preset_alidns_dns",
                name = "阿里云",
                protocol = DnsProtocol.DNS,
                host = "223.5.5.5",
                port = DEFAULT_DNS_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_dnspod_dns",
                name = "腾讯云 DNSPod",
                protocol = DnsProtocol.DNS,
                host = "119.29.29.29",
                port = DEFAULT_DNS_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_360_dns",
                name = "360",
                protocol = DnsProtocol.DNS,
                host = "101.226.4.6",
                port = DEFAULT_DNS_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_onedns_dns",
                name = "OneDNS",
                protocol = DnsProtocol.DNS,
                host = "117.50.10.10",
                port = DEFAULT_DNS_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_cloudflare_dns",
                name = "Cloudflare",
                protocol = DnsProtocol.DNS,
                host = "1.1.1.1",
                port = DEFAULT_DNS_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_google_dns",
                name = "Google",
                protocol = DnsProtocol.DNS,
                host = "8.8.8.8",
                port = DEFAULT_DNS_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_alidns_doh",
                name = "阿里云",
                protocol = DnsProtocol.DOH,
                url = "https://dns.alidns.com/dns-query",
                isPreset = true
            ),
            DnsProvider(
                id = "preset_dnspod_doh",
                name = "腾讯云 DNSPod",
                protocol = DnsProtocol.DOH,
                url = "https://doh.pub/dns-query",
                isPreset = true
            ),
            DnsProvider(
                id = "preset_360_doh",
                name = "360",
                protocol = DnsProtocol.DOH,
                url = "https://doh.360.cn/dns-query",
                isPreset = true
            ),
            DnsProvider(
                id = "preset_onedns_doh",
                name = "OneDNS",
                protocol = DnsProtocol.DOH,
                url = "https://doh.onedns.net/dns-query",
                isPreset = true
            ),
            DnsProvider(
                id = "preset_cloudflare_doh",
                name = "Cloudflare",
                protocol = DnsProtocol.DOH,
                url = "https://cloudflare-dns.com/dns-query",
                isPreset = true
            ),
            DnsProvider(
                id = "preset_google_doh",
                name = "Google",
                protocol = DnsProtocol.DOH,
                url = "https://dns.google/dns-query",
                isPreset = true
            ),
            DnsProvider(
                id = "preset_alidns_dot",
                name = "阿里云",
                protocol = DnsProtocol.DOT,
                host = "dns.alidns.com",
                port = DEFAULT_DOT_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_dnspod_dot",
                name = "腾讯云 DNSPod",
                protocol = DnsProtocol.DOT,
                host = "dot.pub",
                port = DEFAULT_DOT_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_360_dot",
                name = "360",
                protocol = DnsProtocol.DOT,
                host = "dot.360.cn",
                port = DEFAULT_DOT_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_onedns_dot",
                name = "OneDNS",
                protocol = DnsProtocol.DOT,
                host = "dot.onedns.net",
                port = DEFAULT_DOT_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_cloudflare_dot",
                name = "Cloudflare",
                protocol = DnsProtocol.DOT,
                host = "one.one.one.one",
                port = DEFAULT_DOT_PORT,
                isPreset = true
            ),
            DnsProvider(
                id = "preset_google_dot",
                name = "Google",
                protocol = DnsProtocol.DOT,
                host = "dns.google",
                port = DEFAULT_DOT_PORT,
                isPreset = true
            )
        )

        private fun prefs(context: Context, dataset: RuleDataset = RuleDataset.NORMAL): SharedPreferences {
            return context.getSharedPreferences(dataset.prefsName(), Context.MODE_PRIVATE)
        }

        fun loadAll(context: Context, dataset: RuleDataset = RuleDataset.NORMAL): List<DnsProvider> {
            return PRESETS + loadUserProviders(context, dataset).filter { it.protocol in DnsProtocol.MANAGED_PROTOCOLS }
        }

        fun loadRuntimeProviders(context: Context, dataset: RuleDataset = RuleDataset.NORMAL): List<DnsProvider> {
            return loadAll(context, dataset)
        }

        fun loadSelected(context: Context, dataset: RuleDataset = RuleDataset.NORMAL): DnsProvider {
            val all = loadRuntimeProviders(context, dataset)
            val selectedId = prefs(context, dataset).getString(KEY_SELECTED_PROVIDER_ID, null)
            return all.find { it.id == selectedId }
                ?: all.find { it.id == DEFAULT_SELECTED_PROVIDER_ID }
                ?: PRESETS.first()
        }

        fun saveSelected(context: Context, id: String, dataset: RuleDataset = RuleDataset.NORMAL) {
            prefs(context, dataset).edit().putString(KEY_SELECTED_PROVIDER_ID, id).apply()
        }

        fun presetIdForProtocol(id: String, protocol: DnsProtocol): String? {
            val provider = PRESETS.firstOrNull { it.id == id } ?: return null
            if (provider.name !in SWITCHABLE_PRESET_PROVIDER_NAMES) return null
            return PRESETS.firstOrNull {
                it.name == provider.name && it.protocol == protocol
            }?.id
        }

        fun loadRaceProviderIds(context: Context, dataset: RuleDataset = RuleDataset.NORMAL): Set<String> {
            val all = loadRuntimeProviders(context, dataset)
            val allIds = all.map { it.id }.toSet()
            val ids = ResolutionSettingsStore.getRaceProviderIds(context, dataset).toMutableSet()
            return ids.filter { it in allIds }.toSet()
        }

        fun saveRaceProviderIds(context: Context, ids: Set<String>, dataset: RuleDataset = RuleDataset.NORMAL) {
            ResolutionSettingsStore.setRaceProviderIds(context, ids, dataset)
        }

        fun loadLatencyTestProviderIds(context: Context, dataset: RuleDataset = RuleDataset.NORMAL): Set<String> {
            val all = loadRuntimeProviders(context, dataset)
            val allIds = all.map { it.id }.toSet()
            val ids = ResolutionSettingsStore.getLatencyTestProviderIds(context, dataset).toMutableSet()
            return ids.filter { it in allIds }.toSet()
        }

        fun saveLatencyTestProviderIds(context: Context, ids: Set<String>, dataset: RuleDataset = RuleDataset.NORMAL) {
            ResolutionSettingsStore.setLatencyTestProviderIds(context, ids, dataset)
        }

        fun loadUserProviders(context: Context, dataset: RuleDataset = RuleDataset.NORMAL): List<DnsProvider> {
            val json = prefs(context, dataset).getString(KEY_USER_PROVIDERS_JSON, null) ?: return emptyList()
            return try {
                val array = JSONArray(json)
                val providers = buildList {
                    for (i in 0 until array.length()) {
                        val obj = array.getJSONObject(i)
                        obj.toDnsProvider()?.let(::add)
                    }
                }
                providers
            } catch (_: Exception) {
                emptyList()
            }
        }

        fun saveUserProviders(context: Context, providers: List<DnsProvider>, dataset: RuleDataset = RuleDataset.NORMAL) {
            val array = JSONArray()
            providers.forEach { provider ->
                array.put(
                    JSONObject().apply {
                        put("id", provider.id)
                        put("name", provider.name)
                        put("protocol", provider.protocol.name)
                        put("url", provider.url)
                        put("host", provider.host)
                        put("port", provider.port)
                    }
                )
            }
            prefs(context, dataset).edit()
                .putString(KEY_USER_PROVIDERS_JSON, array.toString())
                .apply()
        }

        fun addUserProvider(
            context: Context,
            name: String,
            protocol: DnsProtocol,
            url: String,
            host: String,
            port: Int,
            dataset: RuleDataset = RuleDataset.NORMAL
        ): DnsProvider {
            val provider = DnsProvider(
                id = UUID.randomUUID().toString(),
                name = name.trim(),
                protocol = protocol,
                url = url.trim(),
                host = host.trim(),
                port = port,
                isPreset = false
            )
            val updated = loadUserProviders(context, dataset) + provider
            saveUserProviders(context, updated, dataset)
            return provider
        }

        fun updateUserProvider(context: Context, provider: DnsProvider, dataset: RuleDataset = RuleDataset.NORMAL) {
            val updated = loadUserProviders(context, dataset).map {
                if (it.id == provider.id) provider else it
            }
            saveUserProviders(context, updated, dataset)
        }

        fun deleteUserProvider(context: Context, id: String, dataset: RuleDataset = RuleDataset.NORMAL) {
            val p = prefs(context, dataset)
            val updated = loadUserProviders(context, dataset).filter { it.id != id }
            saveUserProviders(context, updated, dataset)
            if (p.getString(KEY_SELECTED_PROVIDER_ID, null) == id) {
                saveSelected(context, DEFAULT_SELECTED_PROVIDER_ID, dataset)
            }
            val raceIds = ResolutionSettingsStore.getRaceProviderIds(context, dataset).toMutableSet()
            if (raceIds.remove(id)) {
                ResolutionSettingsStore.setRaceProviderIds(context, raceIds, dataset)
            }
            val primaryBackupIds = ResolutionSettingsStore.getPrimaryBackupProviderIds(context, dataset).filterNot { it == id }
            ResolutionSettingsStore.setPrimaryBackupProviderIds(context, primaryBackupIds, dataset)
            ResolutionSettingsStore.removeProviderFromResolutionModes(context, id, dataset)
            val latencyIds = ResolutionSettingsStore.getLatencyTestProviderIds(context, dataset).toMutableSet()
            if (latencyIds.remove(id)) {
                ResolutionSettingsStore.setLatencyTestProviderIds(context, latencyIds, dataset)
            }
            ProviderHealthStore.remove(context, id)
        }

        fun isValidDohUrl(url: String): Boolean {
            val trimmed = url.trim()
            return trimmed.isNotBlank() && trimmed.startsWith("https://", ignoreCase = true)
        }

        fun isValidDotHost(host: String): Boolean {
            val trimmed = host.trim()
            return trimmed.isNotBlank() && !isIpLiteral(trimmed) &&
                trimmed.contains(".") && !trimmed.contains(":")
        }

        fun isValidDnsHost(host: String): Boolean {
            val trimmed = host.trim()
            if (trimmed.isBlank()) return false
            if (isIpLiteral(trimmed)) return true
            // A colon that is not part of an IPv6 literal means "host:port" or a
            // URL; InetAddress cannot parse either, so reject them here instead
            // of letting them fail later at resolution time.
            return trimmed.contains(".") && !trimmed.contains(":")
        }

        fun isValidDotPort(port: Int): Boolean {
            return port in 1..65535
        }

        private fun JSONObject.toDnsProvider(): DnsProvider? {
            val protocolValue = optString("protocol", "").takeIf { it.isNotBlank() }
            val protocol = DnsProtocol.entries.firstOrNull { it.name.equals(protocolValue, ignoreCase = true) } ?: return null
            if (protocol !in DnsProtocol.MANAGED_PROTOCOLS) return null
            return DnsProvider(
                id = getString("id"),
                name = getString("name"),
                protocol = protocol,
                url = optString("url", ""),
                host = optString("host", ""),
                port = optInt("port", DEFAULT_DOT_PORT).takeIf { isValidDotPort(it) } ?: DEFAULT_DOT_PORT,
                isPreset = false
            )
        }

        private val IPV4_LITERAL = Regex("""^(\d{1,3}\.){3}\d{1,3}$""")

        /**
         * True only when [value] is an IP address literal that [java.net.InetAddress]
         * can parse locally without any name resolution.
         *
         * A bare "contains a colon" test is not enough: it also matches
         * "8.8.8.8:53" / "example.com:853" style host:port input, which is not a
         * literal and makes every later `InetAddress.getByName` call attempt a DNS
         * lookup (or throw). IPv6 literals are therefore recognised structurally:
         * compressed form ("::"), eight hextet groups, or the IPv4-embedded tail.
         */
        fun isIpLiteral(value: String): Boolean {
            var trimmed = value.trim()
            if (trimmed.isEmpty()) return false
            if (trimmed.startsWith("[") || trimmed.endsWith("]")) {
                // Bracketed form is only a literal when both brackets enclose an
                // IPv6 address; "[::1]:53" is host:port, not a literal.
                if (trimmed.length < 3 || !trimmed.startsWith("[") || !trimmed.endsWith("]")) return false
                trimmed = trimmed.substring(1, trimmed.length - 1)
                return trimmed.contains(":") && isIpv6Literal(trimmed)
            }
            if (IPV4_LITERAL.matches(trimmed)) {
                return trimmed.split(".").all { part -> part.toIntOrNull() in 0..255 }
            }
            if (!trimmed.contains(":")) return false
            return isIpv6Literal(trimmed)
        }

        private fun isIpv6Literal(value: String): Boolean {
            val address = value.substringBefore('%')
            if (!address.contains(":")) return false
            val compression = address.indexOf("::")
            if (compression >= 0 && address.indexOf("::", compression + 2) >= 0) return false

            val groups: List<String>
            if (compression >= 0) {
                val left = address.substring(0, compression)
                val right = address.substring(compression + 2)
                val leftGroups = if (left.isEmpty()) emptyList() else left.split(":")
                val rightGroups = if (right.isEmpty()) emptyList() else right.split(":")
                if (leftGroups.any { it.isEmpty() } || rightGroups.any { it.isEmpty() }) return false
                groups = leftGroups + rightGroups
            } else {
                groups = address.split(":")
            }

            var hextets = 0
            groups.forEachIndexed { index, group ->
                val isLast = index == groups.lastIndex
                if (isLast && group.contains(".")) {
                    // IPv4-embedded tail, e.g. "::ffff:1.2.3.4", counts as two hextets.
                    if (!IPV4_LITERAL.matches(group)) return false
                    if (group.split(".").any { it.toIntOrNull() !in 0..255 }) return false
                    hextets += 2
                    return@forEachIndexed
                }
                if (group.isEmpty() || group.length > 4) return false
                if (!group.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) return false
                hextets++
            }

            return if (compression >= 0) hextets < 8 else hextets == 8
        }

        const val GOOGLE_DOH_PROVIDER_ID = "preset_google_doh"
        private val SWITCHABLE_PRESET_PROVIDER_NAMES = setOf("阿里云", "腾讯云 DNSPod")

        /**
         * Generates a unique runtime provider ID for a dynamically supplied custom
         * DNS URL/host.
         */
        fun runtimeCustomProviderId(url: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(url.trim().toByteArray(Charsets.UTF_8))
            val suffix = digest.take(8).joinToString(separator = "") { byte ->
                "%02x".format(byte.toInt() and 0xff)
            }
            return "runtime_custom_$suffix"
        }
    }
}
