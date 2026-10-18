package com.haoze.diting.crash

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-054: in `CrashHandler.uncaughtException` the `collectMinimalReport` +
 * `saveCrashReport` pair ran *unprotected*, before the `collectReport`
 * enrichment (which was wrapped in `runCatching`). Under OutOfMemoryError /
 * StackOverflowError the unprotected step threw, jumped straight to the
 * `catch (e: Throwable)` block and skipped `CrashLogManager.onCrashOccurred` —
 * so the consecutive-crash counter and the threshold auto backup never ran for
 * exactly the crashes that matter most.
 *
 * `CrashCaptureSequence` runs every step even when an earlier one throws.
 */
class CrashCaptureSequenceTest {

    @Test
    fun everyStepRunsWhenAnEarlierStepThrows() {
        val executed = mutableListOf<String>()
        val failures = mutableListOf<String>()

        val failed = CrashCaptureSequence.run(
            steps = listOf(
                "breadcrumb" to { executed += "breadcrumb" },
                "minimal-report" to {
                    executed += "minimal-report"
                    throw OutOfMemoryError("simulated OOM while collecting the report")
                },
                "full-report" to { executed += "full-report" },
                "crash-bookkeeping" to { executed += "crash-bookkeeping" }
            ),
            onStepFailed = { name, _ -> failures += name }
        )

        assertEquals(
            listOf("breadcrumb", "minimal-report", "full-report", "crash-bookkeeping"),
            executed
        )
        assertEquals(listOf("minimal-report"), failed)
        assertEquals(listOf("minimal-report"), failures)
    }

    @Test
    fun bookkeepingRunsEvenWhenBothReportStepsFail() {
        var bookkeepingRuns = 0

        val failed = CrashCaptureSequence.run(
            steps = listOf(
                "minimal-report" to { throw StackOverflowError("deep stack") },
                "full-report" to { throw OutOfMemoryError("out of memory") },
                "crash-bookkeeping" to { bookkeepingRuns += 1 }
            )
        )

        assertEquals(1, bookkeepingRuns)
        assertEquals(listOf("minimal-report", "full-report"), failed)
    }

    @Test
    fun failingFailureCallbackDoesNotAbortTheRemainingSteps() {
        val executed = mutableListOf<String>()

        val failed = CrashCaptureSequence.run(
            steps = listOf(
                "minimal-report" to { throw IllegalStateException("boom") },
                "crash-bookkeeping" to { executed += "crash-bookkeeping" }
            ),
            onStepFailed = { _, _ -> throw IllegalStateException("logging itself failed") }
        )

        assertEquals(listOf("crash-bookkeeping"), executed)
        assertEquals(listOf("minimal-report"), failed)
    }

    @Test
    fun allSuccessfulStepsReportNoFailures() {
        var runs = 0
        val failed = CrashCaptureSequence.run(
            steps = listOf(
                "a" to { runs++ },
                "b" to { runs++ }
            )
        )

        assertEquals(2, runs)
        assertTrue(failed.isEmpty())
    }
}
