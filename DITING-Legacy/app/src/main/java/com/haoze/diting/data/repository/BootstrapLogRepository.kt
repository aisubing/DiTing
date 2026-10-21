package com.haoze.diting.data.repository

import android.content.Context
import com.haoze.diting.data.BootstrapIpStats
import com.haoze.diting.data.BootstrapOverallStats
import com.haoze.diting.data.BootstrapStats
import com.haoze.diting.data.BootstrapStatsRange
import com.haoze.diting.data.dao.BootstrapLogDao
import com.haoze.diting.data.RuleDataset
import com.haoze.diting.ui.settings.BootstrapDnsSettingsStore
import com.haoze.diting.util.statsRangeStartMillis
import com.haoze.diting.core.diagnostic.BootstrapHealthStore

class BootstrapLogRepository(
    private val context: Context,
    private val dao: BootstrapLogDao,
    private val dataset: RuleDataset = RuleDataset.NORMAL
) {
    suspend fun stats(range: BootstrapStatsRange): BootstrapStats {
        val since = statsRangeStartMillis(range)
        val overallRow = dao.overallStats(since)
        // Health and entry lookups must use the same dataset as the log DAO,
        // otherwise the Express engine's stats screen shows the ordinary
        // tunnel's weights and IP names.
        val healthByIp = BootstrapHealthStore.loadAll(context, dataset)
        val entriesById = BootstrapDnsSettingsStore.loadBootstrapIpEntries(context, dataset).associateBy { it.id }

        return BootstrapStats(
            overall = BootstrapOverallStats(
                attempts = overallRow.attempts,
                successes = overallRow.successes,
                failures = overallRow.failures,
                avgElapsedMs = overallRow.avgElapsedMs ?: 0.0,
                fallbackUses = overallRow.fallbackUses
            ),
            ipStats = dao.ipStats(since).map { row ->
                val health = healthByIp[row.ipId]
                val entry = entriesById[row.ipId]
                BootstrapIpStats(
                    ipId = row.ipId,
                    ipName = entry?.name ?: row.ipName ?: "未知 Bootstrap IP",
                    ip = entry?.ip ?: row.ip ?: "",
                    attempts = row.attempts,
                    successes = row.successes,
                    failures = row.failures,
                    avgElapsedMs = row.avgElapsedMs ?: 0.0,
                    fallbackUses = row.fallbackUses,
                    predictionWeight = health?.predictionWeight ?: 1.0,
                    ewmaMs = health?.ewmaMs ?: 0.0,
                    consecutiveFailures = health?.consecutiveFailures ?: 0,
                    cooldownUntil = health?.cooldownUntil ?: 0L
                )
            }
        )
    }

}
