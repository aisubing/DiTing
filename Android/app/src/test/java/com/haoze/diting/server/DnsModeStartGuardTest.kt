package com.haoze.diting.server

import com.haoze.diting.server.backend.DnsModeStartGuard
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for A-021: a stop that lands while the DNS mode engine is
 * binding its port must prevent the in-flight start from publishing RUNNING.
 *
 * `DnsServerEngine.start()` blocks inside a native port bind and is not a
 * suspension point, so coroutine cancellation alone cannot stop the start from
 * finishing. Before the guard existed, that start then assigned the engine and
 * called `onServiceStarted()` after `onDestroy()` had already run, leaving an
 * orphan engine holding the listen port while the UI claimed the service was
 * running.
 */
class DnsModeStartGuardTest {

    @Test
    fun `start may publish running while no stop intervened`() {
        val guard = DnsModeStartGuard()
        val token = guard.beginStart()
        assertFalse(guard.isStopped())
        assertTrue(guard.canPublishRunning(token))
    }

    @Test
    fun `stop during a start blocks that start from publishing running`() {
        val guard = DnsModeStartGuard()
        val token = guard.beginStart()
        // The stop intent arrives while engine.start() is blocked in the bind.
        guard.onStopRequested()
        assertFalse("destroyed service must not be reported as running", guard.canPublishRunning(token))
        assertTrue(guard.isStopped())
    }

    @Test
    fun `a fresh start after a stop may publish running again`() {
        val guard = DnsModeStartGuard()
        val first = guard.beginStart()
        guard.onStopRequested()
        assertFalse(guard.canPublishRunning(first))

        // Restarting the service must work normally.
        val second = guard.beginStart()
        assertTrue(guard.canPublishRunning(second))
        // ...and the superseded token stays invalid, so the stale coroutine
        // cannot tear down or publish over the new start.
        assertFalse(guard.canPublishRunning(first))
    }

    @Test
    fun `only the latest of two concurrent starts may publish running`() {
        val guard = DnsModeStartGuard()
        val stale = guard.beginStart()
        val current = guard.beginStart()
        assertFalse("a superseded start must not publish running", guard.canPublishRunning(stale))
        assertTrue(guard.canPublishRunning(current))
    }

    @Test
    fun `guard starts in the stopped state`() {
        // onCreate() must not allow a publish before any start was requested.
        val guard = DnsModeStartGuard()
        assertTrue(guard.isStopped())
        assertFalse(guard.canPublishRunning(0L))
    }
}
