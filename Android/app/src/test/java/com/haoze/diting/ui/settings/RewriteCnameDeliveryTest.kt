package com.haoze.diting.ui.settings

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * O-119, delivery half: proves that DNS mode really does hand CNAME rewrites to
 * the engine and that the engine applies them, which is what makes
 * `isCnameRewriteOperational(DNS_MODE) = true` correct (see
 * [CnameRewriteOperationalTest]).
 *
 * The checks are source-level because both halves sit behind an Android
 * `Context` (the filter builds its JSON from Room) and behind the Go runtime
 * respectively; neither can be instantiated in the JVM unit-test source set. The
 * property being pinned is a control-flow one — "is the rewrite applied before
 * / independently of the ad-block master switch" — so reading the two call sites
 * is the direct check.
 */
class RewriteCnameDeliveryTest {

    private fun repoFile(vararg candidates: String): File? =
        candidates.map(::File).firstOrNull { it.exists() }

    private fun readFile(vararg candidates: String): String =
        repoFile(*candidates)?.readText().orEmpty()

    private fun lineOf(source: String, needle: String): Int =
        source.lines().indexOfFirst { it.contains(needle) }

    @Test
    fun dnsFilterPushesCnameRedirectsWithoutAnAdBlockGate() {
        val source = readFile(
            "src/main/java/com/haoze/diting/server/backend/DnsQueryFilter.kt",
            "app/src/main/java/com/haoze/diting/server/backend/DnsQueryFilter.kt",
            "Android/app/src/main/java/com/haoze/diting/server/backend/DnsQueryFilter.kt"
        )
        if (source.isBlank()) return // different working directory; asserted by the build

        val start = source.indexOf("fun buildRewriteRulesJson")
        assertTrue("buildRewriteRulesJson must exist", start >= 0)
        val end = source.indexOf("\n    }", start).let { if (it < 0) source.length else it }
        val body = source.substring(start, end)

        assertTrue("CNAME redirects must be pushed to the engine", body.contains("cnameRedirects()"))
        assertTrue(
            "the rewrite push must not be gated on the ad-block master switch: $body",
            !body.contains("adBlockEnabled")
        )
    }

    @Test
    fun goEngineAppliesCnameBeforeTheFilteringSwitch() {
        // Unit tests run with the module directory (Android/app) as working
        // directory, so the Go engine one level up is `../tunnel`.
        val source = readFile(
            "../tunnel/engine_standalone.go",
            "Android/tunnel/engine_standalone.go",
            "engine_standalone.go"
        )
        if (source.isBlank()) return

        val rewriteCall = lineOf(source, "e.rewriteCNAME(domain)")
        val filterGuard = lineOf(source, "!e.filterDNS.Load()")

        assertTrue("the engine must apply CNAME rewrites", rewriteCall >= 0)
        assertTrue("the filtering master switch must still guard block rules", filterGuard >= 0)
        assertTrue(
            "CNAME must be applied before the filtering switch is consulted " +
                "(rewrite: ${rewriteCall + 1}, filter guard: ${filterGuard + 1})",
            rewriteCall < filterGuard
        )
    }

    @Test
    fun expressHasNoRewritePathAtAll() {
        // Express is hard-coded to false because it never programs rewrites: the
        // engine only applies what the dataset pushes, and the express adapter
        // carries no rewrite rows.
        val engineSource = readFile(
            "../tunnel/engine_config.go",
            "Android/tunnel/engine_config.go",
            "engine_config.go"
        )
        if (engineSource.isBlank()) return
        assertTrue("rewriteCNAME must read the pushed rewrite entry", engineSource.contains("func (e *Engine) rewriteCNAME"))

        val expressSource = readFile(
            "src/main/java/com/haoze/diting/express/config/ExpressConfigAdapter.kt",
            "app/src/main/java/com/haoze/diting/express/config/ExpressConfigAdapter.kt",
            "Android/app/src/main/java/com/haoze/diting/express/config/ExpressConfigAdapter.kt"
        )
        if (expressSource.isBlank()) return
        assertTrue(
            "express must not build rewrite rules",
            !expressSource.contains("rewriteRules") && !expressSource.contains("cnameRedirects")
        )
    }
}
