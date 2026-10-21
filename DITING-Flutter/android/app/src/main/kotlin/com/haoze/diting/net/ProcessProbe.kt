package com.haoze.diting.net

/**
 * Runs a system binary (`ping` / `ping6`) and returns its combined output.
 *
 * 1.4.3 relied on `withTimeout` from coroutines to bound these calls. The Flutter
 * bridge has no coroutine scope, so the bound has to live here: a child process
 * that never closes stdout would otherwise park a diagnostics worker thread
 * forever, and every later probe would queue behind it.
 *
 * Returns null when no candidate binary could be started (some builds ship no
 * standalone `ping6`); the caller must then take its fallback path instead of
 * reporting a synthetic 100% loss as a measurement.
 */
internal object ProcessProbe {

    fun run(command: List<String>, capMs: Long): String? {
        val process = try {
            ProcessBuilder(command).redirectErrorStream(true).start()
        } catch (_: Exception) {
            return null
        }
        val output = StringBuilder()
        val reader = Thread({ drain(process, output) }, "diting-probe-reader").apply {
            isDaemon = true
            start()
        }
        return try {
            ProcessSupport.waitOrKill(process, capMs)
            // The reader can still be blocked in readLine after a kill; waiting
            // briefly beats returning a half-built string that the parser would
            // read as "no replies".
            reader.join(READER_JOIN_MS)
            synchronized(output) { output.toString() }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            runCatching { process.destroy() }
            synchronized(output) { output.toString() }
        } finally {
            runCatching { process.destroy() }
        }
    }

    /**
     * First candidate that starts *and* says something.
     *
     * Blank output is treated as "this binary did not answer" so the next
     * candidate gets a turn: on some builds `ping6` exists but exits immediately
     * with nothing on stdout, while `ping -6` works.
     */
    fun runFirst(candidates: List<List<String>>, capMs: Long): String? {
        for (command in candidates) {
            val output = run(command, capMs)
            if (!output.isNullOrBlank()) return output
        }
        return null
    }

    private fun drain(process: Process, output: StringBuilder) {
        runCatching {
            process.inputStream.bufferedReader().use { reader ->
                while (true) {
                    val line = reader.readLine() ?: break
                    synchronized(output) { output.appendLine(line) }
                }
            }
        }
    }

    private const val READER_JOIN_MS = 500L
}
