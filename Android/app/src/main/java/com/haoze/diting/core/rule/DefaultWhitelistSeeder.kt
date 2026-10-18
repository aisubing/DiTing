package com.haoze.diting.core.rule

import android.content.Context
import android.util.Log
import androidx.core.content.pm.PackageInfoCompat
import com.haoze.diting.data.AppDatabase
import com.haoze.diting.data.entity.AllowRuleEntity
import com.haoze.diting.ui.RuntimeDnsSettingsRefresher
import com.haoze.diting.ui.settings.AppRulesSettingsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader

object DefaultWhitelistSeeder {
    private const val TAG = "DefaultWhitelistSeeder"
    const val SOURCE_PRESET = "preset"
    const val SOURCE_USER = "useradd"

    private const val PRESET_SCHEMA_VERSION = 2L

    /** Result of deciding whether the preset asset is usable. */
    internal enum class PresetSeedOutcome { WRITE, KEEP_EXISTING }

    /**
     * Ensures the preset default whitelist is initialized in the database.
     *
     * Gated by the app version and preset schema revision: seeds/resets the preset
     * whitelist only once when upgraded or when schema changes. Later launches
     * within the same version do not re-seed, so user customizations are preserved.
     * The reset only deletes rows with source=preset; user-created rules are untouched.
     */
    suspend fun ensureInitialized(context: Context, database: AppDatabase) = withContext(Dispatchers.IO) {
        val currentVersion = currentVersionCode(context)
        val targetSeedVersion = currentVersion * 1000L + PRESET_SCHEMA_VERSION
        if (AppRulesSettingsStore.isDefaultWhitelistInitialized(context) &&
            AppRulesSettingsStore.getDefaultWhitelistSeededVersion(context) == targetSeedVersion
        ) {
            return@withContext
        }
        if (AppRulesSettingsStore.isDefaultWhitelistInitialized(context)) {
            Log.i(TAG, "App version or preset schema changed (target: $targetSeedVersion), resetting preset whitelist...")
        } else {
            Log.i(TAG, "Initializing default preset whitelist...")
        }
        val seeded = seed(context, database, forceReset = true)
        if (!shouldMarkInitialized(seeded)) {
            // The asset produced nothing: leave the initialized/version markers
            // alone so the next launch retries instead of permanently treating an
            // empty preset whitelist as "already seeded".
            Log.e(TAG, "Preset whitelist seeding produced no rules; will retry on next launch")
            return@withContext
        }
        AppRulesSettingsStore.setDefaultWhitelistInitialized(context, true)
        AppRulesSettingsStore.setDefaultWhitelistSeededVersion(context, targetSeedVersion)
        // The upgrade reset can happen while the VPN is running: keep the
        // service-side allowlist cache and Go-side passthrough snapshot in sync.
        RuntimeDnsSettingsRefresher.refreshRuleIndexesIfRunning(
            context.applicationContext,
            refreshBlock = false,
            refreshAllow = true,
            refreshRewrite = false
        )
    }

    private fun currentVersionCode(context: Context): Long = runCatching {
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
        PackageInfoCompat.getLongVersionCode(packageInfo)
    }.getOrDefault(-1L)

    /**
     * Seeds or resets preset whitelist from assets/https_passthrough.txt.
     *
     * Returns the number of rows written. The asset is parsed *before* the
     * existing preset rows are deleted: the parse swallows its own errors (a
     * missing or unreadable asset yields an empty list), so deleting first meant
     * a failed read wiped the whole preset whitelist and then inserted nothing.
     * Because [ensureInitialized] marked the seed as done either way, that empty
     * state was permanent — the passthrough hosts silently stopped being allowed.
     */
    suspend fun seed(context: Context, database: AppDatabase, forceReset: Boolean = false): Int =
        withContext(Dispatchers.IO) {
            val dao = database.allowRuleDao()
            val entries = parseAssetWhitelist(context)
            if (presetSeedOutcome(entries.size) == PresetSeedOutcome.KEEP_EXISTING) {
                Log.w(TAG, "Preset whitelist asset is empty or unreadable; keeping existing preset rules")
                return@withContext 0
            }
            if (forceReset) {
                dao.deleteBySource(SOURCE_PRESET)
            }

            val now = System.currentTimeMillis()
            val entities = entries.map { (domain, category) ->
                AllowRuleEntity(
                    pattern = domain,
                    rawLine = domain,
                    addedAt = now,
                    enabled = true,
                    groupName = category,
                    appScope = null,
                    appInverted = false,
                    isWildcard = domain.contains('*'),
                    important = false
                )
            }

            dao.insertAllForSource(entities, SOURCE_PRESET, sourceEnabled = true)
            Log.i(TAG, "Seeded ${entities.size} preset whitelist rules")
            entities.size
        }

    @Volatile
    private var cachedAssetWhitelist: List<Pair<String, String>>? = null

    /**
     * Parses assets/https_passthrough.txt into a list of (domain, category).
     */
    fun parseAssetWhitelist(context: Context): List<Pair<String, String>> {
        cachedAssetWhitelist?.let { return it }
        val results = mutableListOf<Pair<String, String>>()
        val seen = mutableSetOf<String>()
        var currentCategory = "默认预设"

        runCatching {
            context.assets.open("https_passthrough.txt").use { inputStream ->
                BufferedReader(InputStreamReader(inputStream)).useLines { lines ->
                    for (rawLine in lines) {
                        val trimmed = rawLine.trim()
                        if (trimmed.isEmpty()) continue

                        if (trimmed.startsWith("#") || trimmed.startsWith("//")) {
                            val comment = trimmed.removePrefix("#").removePrefix("//").trim()
                            val cleanedHeader = comment.replace("─", "").trim()
                            if (cleanedHeader.isNotEmpty() && !cleanedHeader.startsWith("Format:") && !cleanedHeader.startsWith("Comment:") && !cleanedHeader.startsWith("Each entry") && !cleanedHeader.startsWith("Domains in")) {
                                currentCategory = cleanedHeader
                            }
                            continue
                        }

                        val domain = trimmed.lowercase().trimEnd('.')
                        if (domain.isNotEmpty() && seen.add(domain)) {
                            results.add(domain to currentCategory)
                        }
                    }
                }
            }
        }.onFailure {
            Log.e(TAG, "Failed to read assets/https_passthrough.txt", it)
        }

        if (results.isNotEmpty()) {
            cachedAssetWhitelist = results
        }
        return results
    }

    internal fun clearCache() {
        cachedAssetWhitelist = null
    }

    /**
     * What [seed] should do for an asset that parsed into [parsedCount] entries.
     *
     * The preset whitelist is the only thing keeping the passthrough hosts
     * allowed, so an empty parse result must never be allowed to erase it.
     */
    internal fun presetSeedOutcome(parsedCount: Int): PresetSeedOutcome =
        if (parsedCount <= 0) PresetSeedOutcome.KEEP_EXISTING else PresetSeedOutcome.WRITE

    /** Whether [ensureInitialized] may record the seed as done. */
    internal fun shouldMarkInitialized(writtenCount: Int): Boolean = writtenCount > 0

    internal fun setCachedWhitelistForTesting(list: List<Pair<String, String>>?) {
        cachedAssetWhitelist = list
    }
}
