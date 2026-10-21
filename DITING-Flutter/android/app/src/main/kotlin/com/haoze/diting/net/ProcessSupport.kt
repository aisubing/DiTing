package com.haoze.diting.net

/**
 * API-24-safe process control for the `ping` probes.
 *
 * `Process.waitFor(timeout, unit)`, `isAlive()` and `destroyForcibly()` are all
 * API 26, but this app's `minSdk` is 24 (Flutter's default). Calling them
 * unguarded would throw `NoSuchMethodError` on Android 7 devices — a crash that
 * only shows up on the oldest supported hardware. The poll loop below uses
 * `exitValue()` + `destroy()`, which exist on every API level.
 *
 * The timeout is not optional: a child process that never closes stdout would
 * otherwise park a diagnostics worker thread forever, and every later probe
 * would queue behind it.
 */
internal object ProcessSupport {

    /** Returns true when the process exited within [capMs]; kills it otherwise. */
    fun waitOrKill(process: Process, capMs: Long): Boolean {
        val deadline = System.nanoTime() + capMs * 1_000_000L
        while (System.nanoTime() < deadline) {
            if (!isRunning(process)) return true
            try {
                Thread.sleep(POLL_INTERVAL_MS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                break
            }
        }
        runCatching { process.destroy() }
        return false
    }

    /** `exitValue()` throws while the child is still alive; that is the only probe API 24 has. */
    fun isRunning(process: Process): Boolean = try {
        process.exitValue()
        false
    } catch (_: IllegalThreadStateException) {
        true
    } catch (_: Exception) {
        // A process that cannot report an exit code is gone from our point of
        // view; treating it as alive would spin until the deadline.
        false
    }

    private const val POLL_INTERVAL_MS = 40L
}
