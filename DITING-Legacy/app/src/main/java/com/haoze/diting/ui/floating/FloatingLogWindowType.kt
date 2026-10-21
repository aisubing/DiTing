package com.haoze.diting.ui.floating

import android.view.WindowManager

/**
 * Window type the floating log overlay must be added with.
 *
 * [WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY] only exists from API 26;
 * passing it on API 24/25 makes `addView` fail, so the overlay could never show
 * on those devices. Below 26 the overlay has to use the legacy phone window type.
 *
 * Pure on purpose: the decision is a plain SDK-level table so unit tests can pin
 * it without a device. Keep it next to the controller rather than inline so the
 * rule is reused by every place that builds the window params.
 */
fun floatingLogOverlayWindowType(sdkInt: Int): Int =
    if (sdkInt >= 26) {
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
    } else {
        @Suppress("DEPRECATION")
        WindowManager.LayoutParams.TYPE_PHONE
    }
