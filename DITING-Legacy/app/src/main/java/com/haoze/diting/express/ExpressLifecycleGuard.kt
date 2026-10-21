package com.haoze.diting.express

/**
 * Serializes Express mode's "start tunnel" and "stop" paths.
 *
 * `ExpressVpnService.startVpn()` establishes the TUN interface synchronously and
 * then starts the data plane in a coroutine, because loading the rule caches
 * suspends. A stop that arrives while that coroutine is still running used to
 * lose the race: `stop()` closed the interface and reported the service stopped,
 * but the in-flight start then flipped `isRunning` back to true and launched the
 * TUN reader over a closed descriptor — an orphan data plane that never answers
 * and never exits on its own.
 *
 * Each start takes a token; a stop invalidates every outstanding token. A start
 * may only publish "running" (keep its interface, start its reader) while its
 * token is still current. Pure Kotlin so unit tests can drive the interleavings.
 */
class ExpressLifecycleGuard {

    private val lock = Any()
    private var generation = 0L
    private var stopped = true

    /** Registers a start attempt and returns its token. */
    fun beginStart(): Long = synchronized(lock) {
        stopped = false
        generation += 1
        generation
    }

    /** Invalidates every in-flight start; called by stop and by onDestroy. */
    fun onStopRequested() = synchronized(lock) {
        stopped = true
        generation += 1
    }

    /** Whether a start that finished with [token] may still publish "running". */
    fun canPublishRunning(token: Long): Boolean = synchronized(lock) {
        !stopped && token == generation
    }

    fun isStopped(): Boolean = synchronized(lock) { stopped }
}
