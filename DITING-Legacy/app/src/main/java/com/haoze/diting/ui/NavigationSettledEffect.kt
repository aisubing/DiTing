package com.haoze.diting.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.flow.first

/**
 * Runs [block] the first time the hosting lifecycle reaches RESUMED, and never
 * again for the lifetime of the composition.
 *
 * Suitable for one-shot initialisation. For data that another screen can edit
 * use [OnResumed] instead: the store outlives the composition, so a one-shot
 * load keeps rendering a stale snapshot after returning to the screen.
 */
@Composable
internal fun NavigationSettledEffect(
    key: Any? = Unit,
    block: suspend () -> Unit
) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var hasRun by rememberSaveable(key) { mutableStateOf(false) }
    LaunchedEffect(lifecycle, key) {
        if (hasRun) return@LaunchedEffect
        lifecycle.currentStateFlow.first { it == Lifecycle.State.RESUMED }
        hasRun = true
        block()
    }
}

/**
 * Runs [block] every time the hosting lifecycle enters RESUMED, including the
 * first entry and every return from another activity or screen.
 *
 * `RememberSaveable` survives configuration changes but not a trip to another
 * screen, and an activity-scoped view model outlives the composition entirely,
 * so a "load once" effect cannot refresh data edited elsewhere. Keying the load
 * off ON_RESUME is the smallest fix: it fires exactly when the user can see the
 * screen again.
 */
@Composable
internal fun OnResumed(block: () -> Unit) {
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentBlock by rememberUpdatedState(block)
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) currentBlock()
        }
        // `addObserver` replays ON_CREATE/ON_START/ON_RESUME for an observer added
        // to an already-resumed owner, so a subtree composed late (a lazily
        // composed pager page, for instance) still runs the block exactly once.
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
}
