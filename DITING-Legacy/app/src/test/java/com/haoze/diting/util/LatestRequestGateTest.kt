package com.haoze.diting.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-051: the rewrite/black/white list `loadPage` launched a new IO coroutine on
 * every keystroke and page/filter change without cancelling the previous one, so
 * a slow older query could finish after a newer one and overwrite the fresh page
 * (rows, page number, total pages and total count) with stale data.
 *
 * Cancelling the previous job fixes the common case, but a job that already
 * passed its last suspension point still runs to completion; the gate is the
 * second line of defence that rejects a result whose request is no longer the
 * newest.
 */
class LatestRequestGateTest {

    private data class Request(val page: Int, val query: String, val filter: String)

    @Test
    fun newestRequestIsLatest() {
        val gate = LatestRequestGate<Request>()
        val first = gate.begin(Request(1, "a", "ALL"))
        assertTrue(gate.isLatest(first))
    }

    @Test
    fun olderRequestStopsBeingLatest() {
        val gate = LatestRequestGate<Request>()
        val first = gate.begin(Request(1, "a", "ALL"))
        val second = gate.begin(Request(1, "ab", "ALL"))

        assertFalse(gate.isLatest(first))
        assertTrue(gate.isLatest(second))
    }

    @Test
    fun onlyTheLastOfManyRequestsIsLatest() {
        val gate = LatestRequestGate<Request>()
        val requests = (1..5).map { gate.begin(Request(it, "q$it", "ALL")) }

        requests.dropLast(1).forEach { assertFalse(gate.isLatest(it)) }
        assertTrue(gate.isLatest(requests.last()))
    }

    @Test
    fun nothingIsLatestBeforeAnyRequest() {
        val gate = LatestRequestGate<Request>()
        assertFalse(gate.isLatest(Request(1, "", "ALL")))
    }

    @Test
    fun sameRequestValuesButDifferentInstanceIsNotLatest() {
        // Two rapid clicks on the same page produce equal-valued requests. Only
        // the instance that was registered last may write, so a stale run cannot
        // pass the guard just because the query/filter/page happen to match.
        val gate = LatestRequestGate<Request>()
        val older = gate.begin(Request(1, "same", "ALL"))
        val newer = gate.begin(Request(1, "same", "ALL"))

        // The premise: structurally equal, but distinct objects. This is what makes
        // the guard's identity comparison (===) load-bearing rather than incidental.
        assertEquals(older, newer)
        assertNotSame(older, newer)

        assertFalse(gate.isLatest(older))
        assertTrue(gate.isLatest(newer))
    }

    @Test
    fun clearInvalidatesTheCurrentRequest() {
        val gate = LatestRequestGate<Request>()
        val request = gate.begin(Request(1, "a", "ALL"))
        assertTrue(gate.isLatest(request))

        gate.clear()
        assertFalse(gate.isLatest(request))
    }

    @Test
    fun beginReturnsTheRequestForCapturing() {
        val gate = LatestRequestGate<Request>()
        val request = Request(3, "dns", "IPV4")
        assertEquals(request, gate.begin(request))
    }

    @Test
    fun interleavedSearchAndPagingKeepsOnlyTheNewest() {
        // Typing "abc" while page 2 loads: the page load must be dropped.
        val gate = LatestRequestGate<Request>()
        val pageLoad = gate.begin(Request(2, "", "ALL"))
        val search = gate.begin(Request(1, "abc", "ALL"))

        assertFalse(gate.isLatest(pageLoad))
        assertTrue(gate.isLatest(search))
    }

    @Test
    fun aLookalikeNeverRegisteredInstanceIsNotLatest() {
        // Guards against "optimising" the comparison back to ==: a fresh object
        // that happens to equal the registered one was never begun, so it must
        // not be able to write over the pending result.
        val gate = LatestRequestGate<Request>()
        val registered = gate.begin(Request(2, "dns", "IPV4"))

        assertFalse(gate.isLatest(Request(2, "dns", "IPV4")))
        assertTrue(gate.isLatest(registered))
    }
}
