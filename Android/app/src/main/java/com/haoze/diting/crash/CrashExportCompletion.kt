package com.haoze.diting.crash

import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

/**
 * Completion bookkeeping of a manual crash-log export.
 *
 * A-058: the "already exported" flag was written by a statement in the body of
 * a `rememberCoroutineScope()` coroutine, right after the file write. That scope
 * is cancelled as soon as the screen leaves composition, so exporting and
 * immediately navigating away could drop the flag — leaving the crash streak at
 * or above the auto-backup threshold, so the next crash exported a full backup
 * the user had already taken by hand.
 *
 * Running the bookkeeping inside [NonCancellable] keeps it alive across the
 * scope's cancellation. It is a separate function rather than an inline block so
 * the guarantee can be asserted on the JVM (see CrashExportCompletionTest).
 */
internal object CrashExportCompletion {

    /**
     * Runs [block] in a non-cancellable context so it still completes when the
     * caller's (composition-scoped) coroutine has already been cancelled.
     */
    suspend fun commit(block: suspend () -> Unit) {
        withContext(NonCancellable) { block() }
    }
}
