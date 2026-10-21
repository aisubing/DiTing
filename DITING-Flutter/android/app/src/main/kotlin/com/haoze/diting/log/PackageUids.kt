package com.haoze.diting.log

import android.content.Context

/// Converts the Dart-side package lists into the UID CSV the Go engine expects.
///
/// `Engine.setBlockedUIDs` and `Engine.setMitmAllowedUIDs` are UID-based on
/// purpose: the engine sees UIDs on the packet path
/// (`socket_uid_resolver.go`'s `resolveFlowUID`), never package names, and
/// 1.4.3's `GoInspectionTunnel` converted with `packageUid()` at start time for
/// the same reason.
///
/// Uninstalled packages are dropped rather than mapped to a sentinel: the engine
/// parses the CSV with `strconv.Atoi`/digits-only and discards non-positive
/// values, so `-1` would be silently ignored anyway — but "package was removed
/// between the user's choice and the service start" must not turn into a
/// blocked UID that happens to be 0 or 1000.
object PackageUids {
    fun csv(context: Context, packages: Collection<String>): String = packages
        .asSequence()
        .filter { it.isNotBlank() }
        .mapNotNull { packageName ->
            runCatching { context.packageManager.getPackageUid(packageName, 0) }.getOrNull()
        }
        .filter { it > 0 }
        .distinct()
        .joinToString(",")
}
