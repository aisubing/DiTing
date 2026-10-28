package com.haoze.diting.platform

import com.haoze.diting.log.DbWriteHealth
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Native side of `com.haoze.diting/db_health`: how many log rows the writers had to drop and why.
///
/// Without this the failure mode was silent — a locked `diting_database` produced empty log pages
/// and nothing else. The troubleshooting page shows these counters so "no logs at all" is
/// diagnosable from the device.
class DbHealthBridge : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/db_health"
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(DbWriteHealth.snapshot())
            else -> result.notImplemented()
        }
    }
}
