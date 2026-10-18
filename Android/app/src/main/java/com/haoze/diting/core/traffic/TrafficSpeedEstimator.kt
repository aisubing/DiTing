package com.haoze.diting.core.traffic

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.pow

/**
 * Calculates and decays exponential moving average (EMA) speeds for total bandwidth and per-app traffic.
 */
internal class TrafficSpeedEstimator {

    private val totalTxSpeedEma = AtomicLong(0L)
    private val totalRxSpeedEma = AtomicLong(0L)
    private val appSpeedEma = ConcurrentHashMap<String, AppSpeedEma>()

    val currentTotalTxSpeedBps: Long get() = totalTxSpeedEma.get()
    val currentTotalRxSpeedBps: Long get() = totalRxSpeedEma.get()
    val activeAppPackages: Set<String> get() = appSpeedEma.keys

    fun getAppSpeed(packageName: String): AppSpeedEma? = appSpeedEma[packageName]

    fun updateSpeedEma(totalTxDelta: Long, totalRxDelta: Long, elapsedSeconds: Double) {
        val instantTxSpeed = (totalTxDelta / elapsedSeconds)
        val instantRxSpeed = (totalRxDelta / elapsedSeconds)

        val prevTx = totalTxSpeedEma.get().toDouble()
        val prevRx = totalRxSpeedEma.get().toDouble()

        val nextTx = if (instantTxSpeed > 0 || prevTx > 0) (EMA_ALPHA * instantTxSpeed + (1 - EMA_ALPHA) * prevTx) else 0.0
        val nextRx = if (instantRxSpeed > 0 || prevRx > 0) (EMA_ALPHA * instantRxSpeed + (1 - EMA_ALPHA) * prevRx) else 0.0

        totalTxSpeedEma.set(if (nextTx < 1.0) 0L else nextTx.toLong())
        totalRxSpeedEma.set(if (nextRx < 1.0) 0L else nextRx.toLong())
    }

    fun updateSingleAppSpeedEma(packageName: String, txDelta: Long, rxDelta: Long, elapsedSeconds: Double) {
        val ema = appSpeedEma.getOrPut(packageName) { AppSpeedEma() }
        val instantTx = txDelta / elapsedSeconds
        val instantRx = rxDelta / elapsedSeconds
        ema.txSpeed = EMA_ALPHA * instantTx + (1 - EMA_ALPHA) * ema.txSpeed
        ema.rxSpeed = EMA_ALPHA * instantRx + (1 - EMA_ALPHA) * ema.rxSpeed
        ema.idleSeconds = 0.0
    }

    /**
     * Feeds one aggregated traffic tick into the per-app EMA.
     *
     * Go tunnel mode reports all apps in a single JSON tick and runs no fixed
     * Kotlin sampling loop, so this is the only place per-app speeds can be
     * produced there; apps missing from [appDeltas] are decayed instead.
     */
    fun updateAppSpeedsForTick(appDeltas: List<Triple<String, Long, Long>>, elapsedSeconds: Double) {
        if (appDeltas.isEmpty()) {
            for (packageName in appSpeedEma.keys) {
                decaySingleAppSpeed(packageName, elapsedSeconds)
            }
            return
        }
        val activePackages = HashSet<String>(appDeltas.size)
        for ((packageName, txDelta, rxDelta) in appDeltas) {
            updateSingleAppSpeedEma(packageName, txDelta, rxDelta, elapsedSeconds)
            activePackages.add(packageName)
        }
        for (packageName in appSpeedEma.keys) {
            if (packageName !in activePackages) {
                decaySingleAppSpeed(packageName, elapsedSeconds)
            }
        }
    }

    /**
     * Lazy decay compensated by the actual elapsed time: converges to the same
     * result as a 1s cycle even under sampling backoff (3s/10s periods).
     */
    fun decaySingleAppSpeed(packageName: String, elapsedSeconds: Double) {
        val ema = appSpeedEma[packageName] ?: return
        ema.idleSeconds += elapsedSeconds
        if (ema.idleSeconds >= 2.0) {
            ema.txSpeed = 0.0
            ema.rxSpeed = 0.0
        } else {
            val factor = 0.5.pow(elapsedSeconds)
            ema.txSpeed *= factor
            ema.rxSpeed *= factor
        }
    }

    fun decayIdleSpeeds() {
        for ((_, ema) in appSpeedEma) {
            ema.idleSeconds += 1.0
            if (ema.idleSeconds >= 2.0) {
                ema.txSpeed = 0.0
                ema.rxSpeed = 0.0
            } else {
                ema.txSpeed *= 0.5
                ema.rxSpeed *= 0.5
            }
        }
        val prevTx = totalTxSpeedEma.get()
        val prevRx = totalRxSpeedEma.get()
        totalTxSpeedEma.set((prevTx * 0.5).toLong().takeIf { it > 10 } ?: 0L)
        totalRxSpeedEma.set((prevRx * 0.5).toLong().takeIf { it > 10 } ?: 0L)
    }

    fun hasNonZeroSpeed(): Boolean {
        if (totalTxSpeedEma.get() > 0 || totalRxSpeedEma.get() > 0) return true
        for (ema in appSpeedEma.values) {
            if (ema.txSpeed > 0 || ema.rxSpeed > 0) return true
        }
        return false
    }

    fun clear() {
        appSpeedEma.clear()
        totalTxSpeedEma.set(0L)
        totalRxSpeedEma.set(0L)
    }

    companion object {
        private const val EMA_ALPHA = 0.3
    }
}
