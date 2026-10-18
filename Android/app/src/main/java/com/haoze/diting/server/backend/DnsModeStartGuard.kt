package com.haoze.diting.server.backend

/**
 * Serializes DNS mode's "start engine" and "stop service" paths.
 *
 * `DnsModeService.startDnsEngine()` runs on a coroutine, but the blocking
 * `DnsServerEngine.start()` call inside it is not a suspension point, so a stop
 * intent (or service destruction) that arrives while the port is being bound
 * cannot interrupt it. Before this guard existed the coroutine simply carried
 * on: it assigned the freshly bound engine and published RUNNING *after*
 * `onDestroy()` had already run, leaving an orphan engine holding the listen
 * port while the UI showed the service as running.
 *
 * Each start takes a token; a stop invalidates every outstanding token. A start
 * may only publish RUNNING (and keep its engine) while its token is still the
 * current one. Pure Kotlin so unit tests can drive the interleavings directly.
 */
class DnsModeStartGuard {

    private val lock = Any()
    private var generation = 0L
    private var stopped = true

    /** Registers a start attempt and returns its token. */
    fun beginStart(): Long = synchronized(lock) {
        stopped = false
        generation += 1
        generation
    }

    /** Invalidates every in-flight start; called on stop and on destroy. */
    fun onStopRequested() = synchronized(lock) {
        stopped = true
        generation += 1
    }

    /**
     * Whether a start that finished with [token] may still take ownership of the
     * engine and report RUNNING.
     */
    fun canPublishRunning(token: Long): Boolean = synchronized(lock) {
        !stopped && token == generation
    }

    fun isStopped(): Boolean = synchronized(lock) { stopped }
}
