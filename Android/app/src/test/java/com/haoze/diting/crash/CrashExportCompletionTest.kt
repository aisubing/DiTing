package com.haoze.diting.crash

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.atomic.AtomicBoolean

/**
 * A-058: the manual crash-log export marked the streak as "already exported"
 * from a statement in the body of a `rememberCoroutineScope()` coroutine. That
 * scope is cancelled when the screen leaves composition, so exporting and then
 * navigating away immediately could drop the flag: the auto-backup threshold
 * stayed armed and the next crash exported a full backup the user had already
 * taken by hand.
 *
 * [CrashExportCompletion.commit] runs the bookkeeping under [NonCancellable], so
 * it still completes after the composition scope is cancelled.
 */
class CrashExportCompletionTest {

    @Test
    fun bookkeepingSurvivesCancellationOfTheCallingScope() = runBlocking {
        val started = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val committed = AtomicBoolean(false)
        val scope = CoroutineScope(Job() + Dispatchers.Default)

        scope.launch {
            CrashExportCompletion.commit {
                started.complete(Unit)
                // Suspends while the screen is being torn down below.
                release.await()
                committed.set(true)
            }
        }

        started.await()
        scope.cancel() // the composition scope dies mid-bookkeeping
        release.complete(Unit)

        withTimeout(5_000) {
            while (!committed.get()) delay(5)
        }
        assertTrue(
            "the exported flag must still be written after the scope is cancelled",
            committed.get()
        )
    }

    @Test
    fun bookkeepingStillRunsOnTheHappyPath() = runBlocking {
        var calls = 0
        CrashExportCompletion.commit { calls++ }
        assertEquals(1, calls)
    }
}
