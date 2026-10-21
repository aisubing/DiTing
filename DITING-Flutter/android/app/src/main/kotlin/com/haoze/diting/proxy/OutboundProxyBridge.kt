package com.haoze.diting.proxy

import android.content.Context
import com.haoze.diting.platform.ChannelResults
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Native side of `com.haoze.diting/outbound_proxy`.
 *
 * 1.4.3 kept the outbound proxy in `dns_vpn_prefs` (`OutboundProxySettingsStore`,
 * nine keys) and encrypted only the two credentials with an AndroidKeyStore
 * AES-GCM key. Dart cannot reach that keystore, so this bridge reads/writes the
 * whole record; the *non-secret* keys stay in the same prefs file and remain
 * readable through [com.haoze.diting.LegacyPrefsBridge], so an upgrade install
 * keeps its configuration.
 *
 * Contract frozen by `lib/data/native/outbound_proxy_bridge.dart`:
 * - `read` -> `{enabled,protocol,host,port,username,password,proxyAppPackage,
 *   status,statusMessage}`
 * - `write(enabled,protocol,host,port,username,password,proxyAppPackage)` -> null
 * - `reset` -> null (removes all nine keys)
 * - `setStatus(state,message)` -> null
 *
 * Key names are copied verbatim from `OutboundProxySettingsStore`; renaming one
 * would make an upgraded install lose that field without any visible error.
 */
class OutboundProxyBridge(private val context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/outbound_proxy"

        /** Same container as 1.4.3 (`SettingsPreferencesExtensions.PREFS_NAME`). */
        private const val PREFS_NAME = "dns_vpn_prefs"

        private const val KEY_ENABLED = "outbound_proxy_enabled"
        private const val KEY_PROTOCOL = "outbound_proxy_protocol"
        private const val KEY_HOST = "outbound_proxy_host"
        private const val KEY_PORT = "outbound_proxy_port"
        private const val KEY_USERNAME = "outbound_proxy_username"
        private const val KEY_PASSWORD = "outbound_proxy_password"
        private const val KEY_APP = "outbound_proxy_app"
        private const val KEY_STATUS = "outbound_proxy_status"
        private const val KEY_STATUS_MESSAGE = "outbound_proxy_status_message"

        private const val DEFAULT_HOST = "127.0.0.1"
        private const val DEFAULT_PORT = 7890
        private const val DEFAULT_PROTOCOL = "socks5"
        private const val DEFAULT_STATUS = "disabled"

        /**
         * Keystore unwrap is tens of milliseconds and `read` runs on every page
         * build; a serial background worker keeps the platform thread free
         * without risking a reordered write.
         */
        private val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "diting-outbound-proxy").apply { isDaemon = true }
        }
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "read" -> worker.execute { runCatching { read() }.ship(result) }
            "write" -> {
                val config = configFrom(call)
                worker.execute { runCatching { write(config) }.ship(result) }
            }
            "reset" -> worker.execute { runCatching { reset() }.ship(result) }
            "setStatus" -> {
                val state = call.argument<String>("state") ?: DEFAULT_STATUS
                val message = call.argument<String>("message").orEmpty()
                worker.execute { runCatching { setStatus(state, message) }.ship(result) }
            }
            else -> result.notImplemented()
        }
    }

    private fun read(): Map<String, Any?> {
        val preferences = prefs()
        val status = preferences.getString(KEY_STATUS, DEFAULT_STATUS)
            ?.takeIf { it.isNotEmpty() } ?: DEFAULT_STATUS
        return mapOf(
            "enabled" to preferences.getBoolean(KEY_ENABLED, false),
            "protocol" to protocolOf(preferences.getString(KEY_PROTOCOL, null)),
            "host" to (preferences.getString(KEY_HOST, DEFAULT_HOST) ?: DEFAULT_HOST),
            "port" to preferences.getInt(KEY_PORT, DEFAULT_PORT),
            // Decryption failure yields "" (keystore reset / restored backup):
            // the page then shows an empty credential and asks the user again,
            // which is the honest state — the old password is unrecoverable.
            "username" to ProxySecretCodec.decrypt(
                preferences.getString(KEY_USERNAME, null),
            ),
            "password" to ProxySecretCodec.decrypt(
                preferences.getString(KEY_PASSWORD, null),
            ),
            "proxyAppPackage" to preferences.getString(KEY_APP, "").orEmpty(),
            "status" to status,
            "statusMessage" to (preferences.getString(KEY_STATUS_MESSAGE, "") ?: ""),
        )
    }

    /**
     * Writes the seven configuration keys. The two `status` keys are deliberately
     * left alone: 1.4.3 reported engine state through a separate callback, and
     * clearing it here would blank the "last error" the user is about to read.
     */
    private fun write(config: Map<String, Any?>) {
        prefs().edit()
            .putBoolean(KEY_ENABLED, config["enabled"] == true)
            .putString(KEY_PROTOCOL, protocolOf(config["protocol"] as? String))
            .putString(KEY_HOST, config["host"] as? String ?: DEFAULT_HOST)
            .putInt(KEY_PORT, (config["port"] as? Number)?.toInt() ?: DEFAULT_PORT)
            .putString(
                KEY_USERNAME,
                ProxySecretCodec.encrypt(config["username"] as? String ?: ""),
            )
            .putString(
                KEY_PASSWORD,
                ProxySecretCodec.encrypt(config["password"] as? String ?: ""),
            )
            .putString(KEY_APP, config["proxyAppPackage"] as? String ?: "")
            .apply()
    }

    private fun reset() {
        prefs().edit()
            .remove(KEY_ENABLED)
            .remove(KEY_PROTOCOL)
            .remove(KEY_HOST)
            .remove(KEY_PORT)
            .remove(KEY_USERNAME)
            .remove(KEY_PASSWORD)
            .remove(KEY_APP)
            .remove(KEY_STATUS)
            .remove(KEY_STATUS_MESSAGE)
            .apply()
    }

    private fun setStatus(state: String, message: String) {
        prefs().edit()
            .putString(KEY_STATUS, state.ifEmpty { DEFAULT_STATUS })
            .putString(KEY_STATUS_MESSAGE, message)
            .apply()
    }

    private fun configFrom(call: MethodCall): Map<String, Any?> = mapOf(
        "enabled" to (call.argument<Boolean>("enabled") ?: false),
        "protocol" to call.argument<String>("protocol"),
        "host" to call.argument<String>("host"),
        "port" to call.argument<Int>("port"),
        "username" to call.argument<String>("username"),
        "password" to call.argument<String>("password"),
        "proxyAppPackage" to call.argument<String>("proxyAppPackage"),
    )

    /**
     * `OutboundProxyProtocol.fromStorageValue`: unknown values fall back to
     * `socks5` rather than being persisted as garbage the Go engine cannot parse.
     */
    private fun protocolOf(value: String?): String = when (value) {
        "http" -> "http"
        "socks5" -> "socks5"
        else -> DEFAULT_PROTOCOL
    }

    private fun prefs() = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Keeps the worker result on the platform thread, like every other bridge. */
    private fun <T> Result<T>.ship(result: MethodChannel.Result) =
        ChannelResults.ship(result, this, "outbound_proxy_unavailable")
}
