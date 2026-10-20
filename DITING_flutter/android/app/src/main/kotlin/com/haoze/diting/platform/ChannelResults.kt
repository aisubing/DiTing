package com.haoze.diting.platform

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges worker-thread results back to the platform thread.
 *
 * Flutter's `MethodChannel.Result` may only be touched on the thread that owns
 * the channel; every bridge in this app does its real work (PackageManager
 * enumeration, keystore unwrap, ICMP probes) off the UI thread, so they all need
 * the same "post the answer back" step.
 */
object ChannelResults {
    private val handler = Handler(Looper.getMainLooper())

    /**
     * Settles [result] with [value].
     *
     * `Unit` is translated to `null` on purpose: several channel methods are
     * declared `Future<void>` on the Dart side, and the standard message codec
     * cannot encode `kotlin.Unit` — passing it through would throw
     * `IllegalArgumentException: Unsupported value` inside the plugin and leave the
     * Dart future hanging.
     */
    fun success(result: MethodChannel.Result, value: Any?) {
        val payload = if (value is Unit) null else value
        handler.post { result.success(payload) }
    }

    /**
     * Reports [error] as a channel error. Callers use this for "the platform said
     * no" cases; a `MethodChannel.Result` that is never settled would leave the
     * Dart `Future` hanging forever, which is strictly worse than an error the UI
     * can render.
     */
    fun error(result: MethodChannel.Result, code: String, error: Throwable) {
        val message = error.message ?: error.javaClass.simpleName
        handler.post { result.error(code, message, null) }
    }

    fun <T> ship(result: MethodChannel.Result, value: Result<T>, code: String) {
        value.fold(
            onSuccess = { success(result, it) },
            onFailure = { error(result, code, it) },
        )
    }
}
