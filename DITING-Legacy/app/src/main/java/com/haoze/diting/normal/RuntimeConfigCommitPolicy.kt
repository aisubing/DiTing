package com.haoze.diting.normal

/**
 * O-103: `refreshRuntimeConfig` applies one settings bundle to two places - the Go
 * engine and the in-process Kotlin snapshot - and the two can disagree about the DNS
 * resolution mode.
 *
 * `activeResolutionMode` is what notifications and the UI render, so it is a claim
 * about what the engine is running. The refresh reads the requested mode from settings
 * up front and only later learns whether the engine actually accepted it, which makes
 * it easy to commit a mode the engine never applied.
 *
 * The defect this addresses: on the provider-resolution failure branch the engine is
 * re-synced with the *previous* providers (and therefore the *previous* mode), but the
 * code then committed the *newly requested* mode to the snapshot. The UI and the
 * notification could then show a resolution mode the engine was not running, until
 * some later change happened to make the two sides agree again.
 *
 * The invariant enforced here: the resolution mode stored in the snapshot is the mode
 * the engine actually accepted. Pure and Android-free so it is unit testable on the JVM.
 */
internal object RuntimeConfigCommitPolicy {

    /**
     * Picks the resolution mode to store in the Kotlin snapshot.
     *
     * @param current the mode the engine is currently running
     * @param requested the mode read from settings during this refresh
     * @param applied whether the engine accepted the new configuration
     */
    fun <T> committedResolutionMode(current: T, requested: T, applied: Boolean): T =
        if (applied) requested else current
}
