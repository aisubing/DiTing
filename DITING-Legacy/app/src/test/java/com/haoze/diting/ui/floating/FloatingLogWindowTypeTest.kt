package com.haoze.diting.ui.floating

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-050: the floating log overlay was always added with
 * `TYPE_APPLICATION_OVERLAY`, a window type that only exists from API 26, so on
 * API 24/25 `addView` threw and the overlay could never be shown. The choice is
 * factored into [floatingLogOverlayWindowType] (a pure SDK-level table) and pinned
 * here, including the exact 25/26 boundary.
 *
 * The expected values are written as literals on purpose: comparing the result
 * to `WindowManager.LayoutParams.TYPE_*` would inline the same constant on both
 * sides of the assertion and could not detect a wrong branch.
 */
class FloatingLogWindowTypeTest {

    private val typeApplicationOverlay = 2038
    private val typePhone = 2002

    @Test
    fun api26AndAboveUsesApplicationOverlay() {
        assertEquals(typeApplicationOverlay, floatingLogOverlayWindowType(26))
        assertEquals(typeApplicationOverlay, floatingLogOverlayWindowType(29))
        assertEquals(typeApplicationOverlay, floatingLogOverlayWindowType(36))
    }

    @Test
    fun belowApi26FallsBackToLegacyPhoneType() {
        // minSdk is 24, so these two are reachable devices, not hypothetical.
        assertEquals(typePhone, floatingLogOverlayWindowType(24))
        assertEquals(typePhone, floatingLogOverlayWindowType(25))
    }

    @Test
    fun everyReachableSdkResolvesToARealWindowType() {
        // Guard against a future refactor returning 0, which would mean "not
        // decided" and silently break `addView` again.
        for (sdk in 24..36) {
            val type = floatingLogOverlayWindowType(sdk)
            assertTrue("sdk $sdk resolved to $type", type == typeApplicationOverlay || type == typePhone)
        }
    }
}
