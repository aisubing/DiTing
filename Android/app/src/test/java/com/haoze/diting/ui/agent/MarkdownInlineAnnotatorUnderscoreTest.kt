package com.haoze.diting.ui.agent

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-097: the italic alternative in the inline Markdown regex accepted a `_` pair
 * anywhere, including inside an identifier. `dns_vpn_prefs` therefore rendered as
 * `dns` + italic `vpn` + `prefs`, dropping both underscores — the agent sends
 * snake_case preference keys and file names in its replies, so this corrupted
 * real technical content.
 *
 * A `_` now only opens an italic span when it is not preceded by a letter, digit,
 * or `_`, and only closes one when it is not followed by a letter, digit, or `_`.
 */
class MarkdownInlineAnnotatorUnderscoreTest {

    private fun format(source: String) = formatMarkdownAnnotatedString(
        source = source,
        baseColor = Color.Black,
        primaryColor = Color.Blue,
        codeBackgroundColor = Color.LightGray,
        errorColor = Color.Red,
        tertiaryColor = Color.Cyan
    )

    private fun italicSpans(source: String) = format(source).spanStyles.filter { it.item.fontStyle == FontStyle.Italic }

    @Test
    fun snakeCaseIdentifiersAreLeftAlone() {
        val identifiers = listOf(
            "dns_vpn_prefs",
            "notification_settings_prefs",
            "KEY_CUSTOM_RUNNING_TEXT",
            "snake_case identifier",
            "x_y_z",
            "http_proxy_host_port"
        )
        identifiers.forEach { identifier ->
            val result = format(identifier)
            assertEquals("text was altered: $identifier", identifier, result.text)
            assertTrue("identifier was italicized: $identifier", italicSpans(identifier).isEmpty())
        }
    }

    @Test
    fun identifiersKeepTheirUnderscoresWhenOtherMarkdownIsPresent() {
        // Inline code is rendered with padding (" code "), so the expected text
        // keeps those spaces; the point is that `dns_vpn_prefs` kept its
        // underscores while the `**…**` span was still recognized.
        val result = format("see **dns_vpn_prefs** and `http_proxy`")
        assertEquals("see dns_vpn_prefs and  http_proxy ", result.text)
        assertTrue(italicSpans("see **dns_vpn_prefs**").isEmpty())
    }

    @Test
    fun realEmphasisStillRenders() {
        val cases = listOf(
            "_italic_" to "italic",
            "a _b_ c" to "a b c",
            "prefs_name and _real_ italic" to "prefs_name and real italic",
            "中文 _斜体_ 中文" to "中文 斜体 中文"
        )
        cases.forEach { (source, expected) ->
            val result = format(source)
            assertEquals("unexpected rendering of: $source", expected, result.text)
            assertTrue("italic span missing in: $source", italicSpans(source).isNotEmpty())
        }
    }

    @Test
    fun emphasisSurvivesNextToASnakeCaseIdentifier() {
        val result = format("KEY_CUSTOM_RUNNING_TEXT is _optional_")
        assertEquals("KEY_CUSTOM_RUNNING_TEXT is optional", result.text)
        assertEquals(1, italicSpans("KEY_CUSTOM_RUNNING_TEXT is _optional_").size)
    }

    @Test
    fun otherUnderscoreFormsAreUnaffected() {
        // `___bolditalic___` is consumed by the dedicated triple-underscore
        // alternative, and `__bold__` by the bold one; neither became italic.
        val boldItalic = format("___x___")
        assertEquals("x", boldItalic.text)

        val bold = format("__bold__")
        assertEquals("bold", bold.text)
        assertFalse(bold.spanStyles.any { it.item.fontStyle == FontStyle.Italic })
    }

    @Test
    fun leadingIdentifierUnderscoreDoesNotOpenASpan() {
        // A private/internal name such as `_cache` starts a word but has no
        // closing underscore, so nothing may be styled.
        val result = format("_cache is not emphasis")
        assertEquals("_cache is not emphasis", result.text)
        assertTrue(italicSpans("_cache is not emphasis").isEmpty())
    }
}
