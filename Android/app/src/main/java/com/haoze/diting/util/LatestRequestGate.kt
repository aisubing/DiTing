package com.haoze.diting.util

/**
 * Tracks the most recent request of a cancellable load and answers whether a
 * result may still be applied.
 *
 * List screens reload on every search keystroke and filter change. Because each
 * reload runs on [kotlinx.coroutines.Dispatchers.IO], an older query could finish
 * after a newer one and overwrite the fresh page (and the page/total counters)
 * with stale rows. Cancelling the previous job covers the common case; this gate
 * additionally rejects a result whose request is no longer the latest, which
 * matters when the older job already passed its last suspension point.
 */
class LatestRequestGate<R> {
    private var latest: R? = null
    private var hasLatest = false

    /** Registers [request] as the latest one and returns it for convenience. */
    @Synchronized
    fun begin(request: R): R {
        latest = request
        hasLatest = true
        return request
    }

    /**
     * True when [request] is still the newest registered request.
     *
     * Compared by identity, not equality. Requests are data classes, so `==`
     * would report an *older* request as latest whenever a newer one happens to
     * carry the same values — exactly the "two rapid clicks on the same page"
     * case this guard exists for, and the stale run would then be allowed to
     * overwrite the fresh one. The question here is "is this the same request
     * object I registered?", which only `===` answers.
     */
    @Synchronized
    fun isLatest(request: R): Boolean = hasLatest && latest === request

    /** Forgets the current request, e.g. after the owning screen was torn down. */
    @Synchronized
    fun clear() {
        latest = null
        hasLatest = false
    }
}
