package com.haoze.diting.express

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for A-040: a stop that lands while Express is still starting
 * must prevent the in-flight start from reporting the tunnel as running.
 *
 * `ExpressVpnService.startVpn()` launches the data plane in a coroutine because
 * `ExpressTunnelManager.start()` suspends while it loads the rule caches. A stop
 * arriving in that window closed the interface and reported the service stopped,
 * after which the in-flight start flipped `isRunning` back to true and launched
 * the TUN reader over a closed descriptor — an orphan data plane.
 */
class ExpressLifecycleGuardTest {

    @Test
    fun `start may publish running while no stop intervened`() {
        val guard = ExpressLifecycleGuard()
        val token = guard.beginStart()
        assertFalse(guard.isStopped())
        assertTrue(guard.canPublishRunning(token))
    }

    @Test
    fun `stop during the start window blocks publishing running`() {
        val guard = ExpressLifecycleGuard()
        val token = guard.beginStart()
        // The user hits stop while the rule caches are still loading.
        guard.onStopRequested()
        assertFalse("a stopped service must not report a running tunnel", guard.canPublishRunning(token))
        assertTrue(guard.isStopped())
    }

    @Test
    fun `restart after a stop may publish running`() {
        val guard = ExpressLifecycleGuard()
        val first = guard.beginStart()
        guard.onStopRequested()
        assertFalse(guard.canPublishRunning(first))

        val second = guard.beginStart()
        assertTrue(guard.canPublishRunning(second))
        assertFalse("the superseded start must stay invalid", guard.canPublishRunning(first))
    }

    @Test
    fun `only the latest of two overlapping starts may publish running`() {
        val guard = ExpressLifecycleGuard()
        val stale = guard.beginStart()
        val current = guard.beginStart()
        assertFalse(guard.canPublishRunning(stale))
        assertTrue(guard.canPublishRunning(current))
    }

    @Test
    fun `guard starts in the stopped state`() {
        val guard = ExpressLifecycleGuard()
        assertTrue(guard.isStopped())
        assertFalse(guard.canPublishRunning(0L))
    }

    @Test
    fun `repeated stops are idempotent and still block every outstanding token`() {
        val guard = ExpressLifecycleGuard()
        val token = guard.beginStart()
        guard.onStopRequested()
        guard.onStopRequested()
        assertFalse(guard.canPublishRunning(token))
    }
}
