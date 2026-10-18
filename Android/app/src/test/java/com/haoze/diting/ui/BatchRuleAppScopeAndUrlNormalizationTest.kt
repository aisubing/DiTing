package com.haoze.diting.ui

import com.haoze.diting.data.RuleDataSources
import com.haoze.diting.data.RuleDataset
import com.haoze.diting.data.dao.AllowRuleDao
import com.haoze.diting.data.dao.BlockRuleDao
import com.haoze.diting.data.dao.CosmeticRuleDao
import com.haoze.diting.data.dao.GoUrlRuleDao
import com.haoze.diting.data.dao.MirrorTemplateDao
import com.haoze.diting.data.dao.RewriteRuleDao
import com.haoze.diting.data.dao.SubscriptionAutoUpdateDao
import com.haoze.diting.data.dao.SubscriptionDao
import com.haoze.diting.data.dao.SubscriptionGroupDao
import com.haoze.diting.data.entity.GoUrlRuleKind
import com.haoze.diting.ui.batch.BatchRuleItem
import com.haoze.diting.ui.batch.BatchRuleTarget
import com.haoze.diting.ui.batch.BatchRuleValidator
import com.haoze.diting.ui.batch.committableCosmeticItems
import com.haoze.diting.ui.batch.toAllowEntity
import com.haoze.diting.ui.batch.toBlockEntity
import com.haoze.diting.ui.batch.toCosmeticEntity
import com.haoze.diting.ui.batch.toGoUrlEntity
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Proxy

/**
 * A-028 / A-029 / A-075 on the batch-import path.
 *
 * A-028: `~app=com.foo` was dropped between classification and insertion, so the
 *        stored row silently lost its inverted app scope.
 * A-029: URL rules were inserted verbatim, bypassing `GoUrlRuleManager.parse`, so
 *        batch-added rules differed from manually added ones.
 * A-075: element-hiding rules must be rejected outside NORMAL (no CSS engine).
 *
 * The commit step itself needs a `Context`, so the item-to-entity mapping lives in
 * `BatchRuleEntities.kt` as pure functions and is exercised directly here.
 */
class BatchRuleAppScopeAndUrlNormalizationTest {

    private fun createSources(): RuleDataSources {
        val blockDao = Proxy.newProxyInstance(
            BlockRuleDao::class.java.classLoader,
            arrayOf(BlockRuleDao::class.java)
        ) { _, method, _ ->
            if (method.name == "idByPattern") 0L else null
        } as BlockRuleDao

        val allowDao = Proxy.newProxyInstance(
            AllowRuleDao::class.java.classLoader,
            arrayOf(AllowRuleDao::class.java)
        ) { _, method, _ ->
            if (method.name == "idByPattern") 0L else null
        } as AllowRuleDao

        val rewriteDao = Proxy.newProxyInstance(
            RewriteRuleDao::class.java.classLoader,
            arrayOf(RewriteRuleDao::class.java)
        ) { _, method, _ ->
            when (method.name) {
                "idByKey", "countType", "countOtherTypes" -> 0L
                else -> null
            }
        } as RewriteRuleDao

        val goUrlDao = Proxy.newProxyInstance(
            GoUrlRuleDao::class.java.classLoader,
            arrayOf(GoUrlRuleDao::class.java)
        ) { _, method, _ ->
            if (method.name == "idByPattern") 0L else null
        } as GoUrlRuleDao

        val cosmeticDao = Proxy.newProxyInstance(
            CosmeticRuleDao::class.java.classLoader,
            arrayOf(CosmeticRuleDao::class.java)
        ) { _, method, _ ->
            if (method.name == "idByDomainAndSelector") 0L else null
        } as CosmeticRuleDao

        return object : RuleDataSources {
            override fun blockRuleDao() = blockDao
            override fun allowRuleDao() = allowDao
            override fun rewriteRuleDao() = rewriteDao
            override fun goUrlRuleDao() = goUrlDao
            override fun cosmeticRuleDao() = cosmeticDao
            override fun subscriptionDao(): SubscriptionDao = throw UnsupportedOperationException()
            override fun subscriptionGroupDao(): SubscriptionGroupDao = throw UnsupportedOperationException()
            override fun subscriptionAutoUpdateDao(): SubscriptionAutoUpdateDao = throw UnsupportedOperationException()
            override fun mirrorTemplateDao(): MirrorTemplateDao = throw UnsupportedOperationException()
        }
    }

    private fun validDomain(summary: com.haoze.diting.ui.batch.BatchValidationSummary): BatchRuleItem.ValidDomain {
        val item = summary.validItems.filterIsInstance<BatchRuleItem.ValidDomain>().singleOrNull()
        assertNotNull("expected exactly one valid domain item", item)
        return item!!
    }

    private fun validUrl(summary: com.haoze.diting.ui.batch.BatchValidationSummary): BatchRuleItem.ValidUrl {
        val item = summary.validItems.filterIsInstance<BatchRuleItem.ValidUrl>().singleOrNull()
        assertNotNull("expected exactly one valid URL item", item)
        return item!!
    }

    private fun validRewrite(summary: com.haoze.diting.ui.batch.BatchValidationSummary): BatchRuleItem.ValidRewrite {
        val item = summary.validItems.filterIsInstance<BatchRuleItem.ValidRewrite>().singleOrNull()
        assertNotNull("expected exactly one valid rewrite item", item)
        return item!!
    }

    // --- A-028 -----------------------------------------------------------------

    @Test
    fun invertedAppScopeSurvivesClassificationAndValidation() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val summary = validator.validate("||tracker.example.com^\$~app=com.foo")
        val item = validDomain(summary)
        assertEquals("tracker.example.com", item.pattern)
        assertEquals("com.foo", item.appScope)
        assertTrue("~app= must survive as appInverted", item.appInverted)
    }

    /**
     * The caret has to land before the `$modifier` tail. The classifier used to
     * append it to the raw line, so `||a.com$~app=x` became `||a.com$~app=x^` and
     * the parser read the scope as `x^` — every bulk-imported `$app=` / `~app=`
     * rule was silently unrunnable because no package name ends in a caret.
     */
    @Test
    fun missingCaretIsInsertedBeforeTheModifierSection() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val item = validDomain(validator.validate("||tracker.example.com\$~app=com.foo"))
        assertEquals("tracker.example.com", item.pattern)
        assertEquals("com.foo", item.appScope)
        assertTrue(item.appInverted)
    }

    /**
     * Same caret placement defect on the plain-domain whitelist fallback, which
     * prefixes `@@||` itself rather than using an explicit `@@||` from the user.
     */
    @Test
    fun missingCaretOnAllowFallbackIsInsertedBeforeTheModifierSection() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.WHITELIST)

        val item = validDomain(validator.validate("safe.example.com\$~app=com.foo"))
        assertEquals("safe.example.com", item.pattern)
        assertEquals("com.foo", item.appScope)
        assertTrue(item.appInverted)
    }

    /**
     * The `$modifier` section must be stripped before looking for a mapping
     * arrow. `$~app=com.foo` contains `=`, and the arrow check used to read that
     * as a rewrite mapping, so a bare domain with a modifier was rejected as
     * "域名格式无效" instead of becoming a domain rule. This covers the blacklist
     * half of the plain-domain fallback (branch 9); the whitelist half is the
     * case above.
     */
    @Test
    fun modifierEqualsSignIsNotTreatedAsARewriteArrow() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val item = validDomain(validator.validate("tracker.example.com\$~app=com.foo"))
        assertEquals("tracker.example.com", item.pattern)
        assertEquals("com.foo", item.appScope)
        assertTrue(item.appInverted)
        assertFalse(item.isAllow)
    }

    // --- rewrite mappings must keep working (guard against the fix above) ------

    @Test
    fun arrowMappingStillProducesRewrite() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val item = validRewrite(validator.validate("example.com -> 1.2.3.4"))
        assertEquals("example.com", item.domain)
        assertEquals("1.2.3.4", item.targetValue)
    }

    @Test
    fun fatArrowMappingStillProducesRewrite() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val item = validRewrite(validator.validate("example.com => 1.2.3.4"))
        assertEquals("example.com", item.domain)
        assertEquals("1.2.3.4", item.targetValue)
    }

    @Test
    fun bareEqualsMappingStillProducesRewrite() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val item = validRewrite(validator.validate("example.com = 1.2.3.4"))
        assertEquals("example.com", item.domain)
        assertEquals("1.2.3.4", item.targetValue)
    }

    @Test
    fun invertedAppScopeIsPersistedOnTheBlockRow() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)
        val item = validDomain(validator.validate("||tracker.example.com^\$~app=com.foo"))

        val row = item.toBlockEntity(now = 1L)
        assertEquals("tracker.example.com", row.pattern)
        assertEquals("com.foo", row.appScope)
        assertTrue("stored row must keep appInverted = true", row.appInverted)
    }

    @Test
    fun invertedAppScopeIsPersistedOnTheAllowRow() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.WHITELIST)
        val item = validDomain(validator.validate("@@||safe.example.com^\$~app=com.foo"))

        val row = item.toAllowEntity(now = 1L)
        assertEquals("safe.example.com", row.pattern)
        assertEquals("com.foo", row.appScope)
        assertTrue(row.appInverted)
    }

    @Test
    fun nonInvertedAppScopeStaysFalse() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val item = validDomain(validator.validate("||tracker.example.com^\$app=com.bar"))
        assertEquals("com.bar", item.appScope)
        assertFalse(item.appInverted)
        assertFalse(item.toBlockEntity(now = 1L).appInverted)
    }

    // --- A-029 -----------------------------------------------------------------

    @Test
    fun batchUrlRuleIsNormalizedLikeTheSingleRulePath() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        // Scheme/host lowercased, default port 443 dropped, path preserved.
        val item = validUrl(validator.validate("https://Ads.Example.COM:443/Banner.gif"))
        assertEquals("https://ads.example.com/Banner.gif", item.urlPattern)
    }

    @Test
    fun batchUrlRuleDropsDefaultHttpPortAndAddsRootPath() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val item = validUrl(validator.validate("http://Example.com:80"))
        assertEquals("http://example.com/", item.urlPattern)
    }

    @Test
    fun nonDefaultPortIsKept() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val item = validUrl(validator.validate("https://Example.com:8443/api"))
        assertEquals("https://example.com:8443/api", item.urlPattern)
    }

    @Test
    fun urlRowKindFollowsAllowFlag() = runBlocking {
        val blockValidator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)
        assertEquals(
            GoUrlRuleKind.BLOCK,
            validUrl(blockValidator.validate("https://ads.example.com/a")).toGoUrlEntity(1L).kind
        )

        val allowValidator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.WHITELIST)
        assertEquals(
            GoUrlRuleKind.ALLOW,
            validUrl(allowValidator.validate("@@https://safe.example.com/a")).toGoUrlEntity(1L).kind
        )
    }

    // --- A-075 -----------------------------------------------------------------

    @Test
    fun elementHidingRuleIsRejectedOutsideNormalMode() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.EXPRESS, BatchRuleTarget.BLACKLIST)

        val summary = validator.validate("example.com##.ad-banner")
        assertEquals(0, summary.validCount)
        assertEquals(1, summary.invalidCount)
        assertTrue(summary.invalidItems.single().reason.contains("仅普通模式支持"))
    }

    @Test
    fun elementHidingRuleIsAcceptedInNormalMode() = runBlocking {
        val validator = BatchRuleValidator(createSources(), RuleDataset.NORMAL, BatchRuleTarget.BLACKLIST)

        val summary = validator.validate("example.com##.ad-banner")
        assertEquals(1, summary.validCount)
        assertTrue(summary.validItems.single() is BatchRuleItem.ValidCosmetic)
    }

    @Test
    fun commitGuardDropsCosmeticItemsOutsideNormalMode() {
        val cosmetic = BatchRuleItem.ValidCosmetic(1, "example.com##.ad", "example.com", ".ad")
        val items = listOf<BatchRuleItem>(cosmetic)

        assertEquals(emptyList<BatchRuleItem>(), committableCosmeticItems(items, RuleDataset.EXPRESS))
        assertEquals(emptyList<BatchRuleItem>(), committableCosmeticItems(items, RuleDataset.DNS_MODE))
        assertEquals(listOf(cosmetic), committableCosmeticItems(items, RuleDataset.NORMAL))
    }

    @Test
    fun cosmeticEntityKeepsExceptionFlag() {
        val hide = BatchRuleItem.ValidCosmetic(1, "a.com##.x", "a.com", ".x", isException = false)
        val except = BatchRuleItem.ValidCosmetic(2, "a.com#@#.x", "a.com", ".x", isException = true)

        assertFalse(hide.toCosmeticEntity(1L).isException)
        assertTrue(except.toCosmeticEntity(1L).isException)
    }
}
