package com.haoze.diting.net

import com.haoze.diting.express.ExpressVpnService
import com.haoze.diting.normal.DitingVpnService
import com.haoze.diting.server.DitingDnsServerService
import tunnel.Engine

/**
 * Finds the Go engine currently backing a tunnel, for the diagnostics channel.
 *
 * Only one of the three services can be running at a time (the work-mode switch
 * stops the old mode before starting the new one), so the first non-null answer
 * is the active engine. The order matters only if that invariant ever breaks;
 * it follows the UI's own ordering (normal → express → server).
 *
 * Each service exposes a read-only `engineForDiagnostics()` accessor because its
 * `activeEngine` field is private to the companion. Reading the field reflectively
 * was rejected: R8 renames private fields in release builds, so the lookup would
 * work in debug and fail silently in the shipped APK.
 */
internal object EngineAccess {

    fun current(): Engine? =
        DitingVpnService.engineForDiagnostics()
            ?: ExpressVpnService.engineForDiagnostics()
            ?: DitingDnsServerService.engineForDiagnostics()
}
