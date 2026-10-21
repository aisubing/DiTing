package com.haoze.diting.crash

/**
 * Runs the crash-capture steps in a fixed order while isolating their failures.
 *
 * The crash handler must guarantee that the cheap, load-bearing bookkeeping
 * (consecutive-crash counting and the threshold auto backup) still runs when an
 * earlier step blows up. [CrashCollector.collectMinimalReport] allocates and
 * walks the whole thread table, so exactly the crashes that matter most —
 * OutOfMemoryError / StackOverflowError — used to throw out of it and skip the
 * counting entirely.
 *
 * Every step is therefore executed even if a previous one failed; failures are
 * reported through [onStepFailed] and returned by name for logging/tests.
 */
internal object CrashCaptureSequence {

    /**
     * @return the names of the steps that threw, in execution order.
     */
    fun run(
        steps: List<Pair<String, () -> Unit>>,
        onStepFailed: (String, Throwable) -> Unit = { _, _ -> }
    ): List<String> {
        val failed = ArrayList<String>(0)
        for ((name, step) in steps) {
            try {
                step()
            } catch (error: Throwable) {
                failed.add(name)
                runCatching { onStepFailed(name, error) }
            }
        }
        return failed
    }
}
