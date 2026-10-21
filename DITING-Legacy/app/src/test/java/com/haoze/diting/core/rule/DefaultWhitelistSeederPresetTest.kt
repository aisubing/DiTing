package com.haoze.diting.core.rule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-099: `DefaultWhitelistSeeder.seed()` deleted the preset rows *before* parsing
 * the asset, and the parse swallows its own errors. A failed read therefore wiped
 * the whole preset whitelist and inserted nothing — and `ensureInitialized` then
 * marked the seed as done, making the empty state permanent.
 */
class DefaultWhitelistSeederPresetTest {

    @Test
    fun emptyAssetKeepsExistingPresetRules() {
        assertEquals(
            DefaultWhitelistSeeder.PresetSeedOutcome.KEEP_EXISTING,
            DefaultWhitelistSeeder.presetSeedOutcome(0)
        )
    }

    @Test
    fun nonEmptyAssetWritesPresetRules() {
        assertEquals(
            DefaultWhitelistSeeder.PresetSeedOutcome.WRITE,
            DefaultWhitelistSeeder.presetSeedOutcome(5)
        )
    }

    @Test
    fun failedSeedIsNotMarkedInitialized() {
        // Nothing written => the version markers must stay untouched so the next
        // launch retries instead of permanently accepting an empty preset list.
        assertFalse(DefaultWhitelistSeeder.shouldMarkInitialized(0))
    }

    @Test
    fun successfulSeedIsMarkedInitialized() {
        assertTrue(DefaultWhitelistSeeder.shouldMarkInitialized(5))
    }

    @Test
    fun assetStillParsesToFivePassthroughDomains() {
        // The parse is Context-bound, so assert the raw asset contract instead:
        // assets/https_passthrough.txt holds exactly the 5 connectivity domains.
        val asset = java.io.File("src/main/assets/https_passthrough.txt")
        if (!asset.exists()) return // asset path differs when run from another root
        val domains = asset.readLines()
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("#") && !it.startsWith("//") }
            .map { it.lowercase().trimEnd('.') }
        assertEquals(5, domains.size)
        assertTrue(domains.contains("mtalk.google.com"))
        assertTrue(domains.contains("connectivitycheck.gstatic.com"))
    }
}
