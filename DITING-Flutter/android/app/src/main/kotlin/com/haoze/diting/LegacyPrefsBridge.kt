package com.haoze.diting

import android.content.Context
import android.content.SharedPreferences
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes the SharedPreferences containers written by DITING 1.4.3.
 *
 * The Flutter side must read and write the *same* files with the *same* keys,
 * otherwise an upgraded install would silently lose every setting. The plugin
 * `shared_preferences` cannot do that: it keeps everything in a single
 * `FlutterSharedPreferences` file with a `flutter.` prefix, so we go straight
 * through the platform API instead.
 */
class LegacyPrefsBridge(private val context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/legacy_prefs"

        /**
         * Allowed containers.
         *
         * The first eleven exist in 1.4.3 and carry the upgrade-compatibility
         * contract (same file, same keys). A whitelist means a typo in a
         * container name fails loudly instead of silently creating a parallel
         * prefs file that the tunnel services never read.
         *
         * `diting_config_resources` is **not** from 1.4.3: it holds this port's
         * own icon-set / user-agent / on-demand tables, which 1.4.3 had no
         * equivalent for. It is listed here because it goes through the same
         * channel; one channel beats two.
         */
        val CONTAINERS = setOf(
            "dns_vpn_prefs",
            "diting_express_prefs",
            "diting_dns_mode_prefs",
            "express_vpn_prefs",
            "diting_settings",
            "permission_disclosures",
            "mode_permission_preferences",
            "notification_settings_prefs",
            "diting_crash_state",
            "network_tools_settings",
            "recognition_members",
            // 本仓自有（1.4.3 无对应功能），与上面十一个不共享兼容契约。
            "diting_config_resources",
        )
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "versionCode") {
            result.success(versionCode())
            return
        }
        val container = call.argument<String>("container")
        if (container == null || container !in CONTAINERS) {
            result.error("invalid_container", "Unknown SharedPreferences container", container)
            return
        }
        val prefs = context.getSharedPreferences(container, Context.MODE_PRIVATE)
        when (call.method) {
            "readAll" -> result.success(readable(prefs.all))
            "put" -> put(call, prefs, result)
            "remove" -> {
                val key = call.argument<String>("key")
                if (key == null) {
                    result.error("invalid_key", "Missing key", null)
                } else {
                    prefs.edit().remove(key).apply()
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Used for the version-gated preset whitelist seed, same as 1.4.3. */
    private fun versionCode(): Long {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun put(call: MethodCall, prefs: SharedPreferences, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        val type = call.argument<String>("type")
        val value = call.argument<Any>("value")
        if (key == null || type == null) {
            result.error("invalid_argument", "Missing key or type", null)
            return
        }
        val editor = prefs.edit()
        try {
            when (type) {
                "string" -> editor.putString(key, value as String)
                "bool" -> editor.putBoolean(key, value as Boolean)
                "int" -> editor.putInt(key, (value as Number).toInt())
                "long" -> editor.putLong(key, (value as Number).toLong())
                // SharedPreferences has a dedicated float slot; the channel only
                // carries doubles, so the type has to be explicit.
                "float" -> editor.putFloat(key, (value as Number).toFloat())
                "string_set" -> editor.putStringSet(key, (value as List<*>).map { it.toString() }.toSet())
                else -> {
                    result.error("invalid_type", "Unsupported value type", type)
                    return
                }
            }
        } catch (error: ClassCastException) {
            result.error("invalid_value", "Value does not match type $type", value)
            return
        }
        editor.apply()
        result.success(null)
    }

    /** `getAll` can return `Set<String>`, which the standard codec cannot carry. */
    private fun readable(values: Map<String, *>): Map<String, Any?> {
        val output = HashMap<String, Any?>(values.size)
        values.forEach { (key, value) ->
            output[key] = when (value) {
                is Set<*> -> value.map { it.toString() }
                else -> value
            }
        }
        return output
    }
}
