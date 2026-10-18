package com.haoze.diting.ui

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import com.haoze.diting.ui.localization.LocalizationEngine

/**
 * Composable entry point for string localization.
 * Returns the English translation when the active UI language is English, otherwise returns the original text.
 */
@Composable
fun localizedText(text: String): String {
    val configuration = LocalConfiguration.current
    val context = LocalContext.current
    return if (configuration.locales[0].language == "en") {
        LocalizationEngine.translate(text, context)
    } else {
        text
    }
}

/**
 * Context-aware entry point for string localization.
 * Wraps the context using [AppLanguageManager] and returns the English translation when applicable.
 */
fun localizedText(context: Context, text: String): String {
    val localizedContext = AppLanguageManager.wrap(context)
    return if (localizedContext.resources.configuration.locales[0].language == "en") {
        LocalizationEngine.translate(text, localizedContext)
    } else {
        text
    }
}

/**
 * Resolves a string resource in the app's selected UI language rather than in
 * the system language.
 *
 * Raw `context.getString()` follows the system locale, so a string that is not
 * routed through [localizedText] (notification channel titles, service
 * notifications, tile labels) kept showing the system language while the rest of
 * the UI followed the app language setting. The `values-en` resource is used as
 * the translation source here, exactly like a wrapped screen would.
 */
fun localizedResource(context: Context, resId: Int): String =
    AppLanguageManager.wrap(context).getString(resId)

/**
 * Format-argument variant of [localizedResource] for the strings that interpolate
 * a value (download progress, version numbers).
 *
 * The format string and its arguments must come from the *same* language source:
 * reading the format string from the system locale while the arguments were
 * localized separately produced half-translated notifications.
 */
fun localizedResource(context: Context, resId: Int, vararg formatArgs: Any): String =
    AppLanguageManager.wrap(context).getString(resId, *formatArgs)
