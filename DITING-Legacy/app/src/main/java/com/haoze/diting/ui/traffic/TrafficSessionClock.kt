package com.haoze.diting.ui.traffic

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.haoze.diting.util.formatDurationClock
import kotlinx.coroutines.delay

/**
 * Clock text for the "connected for HH:MM:SS" line of the traffic card.
 *
 * Split out as a pure function because the visible bug was that the value was
 * only read once during composition: with no traffic flowing the card never
 * recomposes, so the elapsed time froze. [sessionStartTimeMs] is the session
 * begin timestamp and [nowMs] the sampled wall clock; negative deltas (clock
 * changes) clamp to zero instead of rendering a negative duration.
 */
internal fun sessionClockText(sessionStartTimeMs: Long, nowMs: Long): String =
    formatDurationClock((nowMs - sessionStartTimeMs).coerceAtLeast(0L))

/**
 * Wall clock that ticks once a second for as long as the caller stays in
 * composition, so a duration read from it re-renders without depending on
 * traffic updates that may never arrive.
 */
@Composable
internal fun rememberTickingNowMs(intervalMs: Long = 1_000L): Long {
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(intervalMs) {
        while (true) {
            nowMs = System.currentTimeMillis()
            delay(intervalMs)
        }
    }
    return nowMs
}
